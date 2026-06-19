from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np


IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff", ".webp"}
LABEL_ALIASES = {
    "刘驿恺": "刘毅凯",
}

LEFT_EYE_INDICES = (33, 133, 159, 145)
RIGHT_EYE_INDICES = (362, 263, 386, 374)
MOUTH_INDICES = (61, 291)


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(
        description=(
            "Helper only: detect left-eye/right-eye/mouth coordinates and write CSV. "
            "It does not align, crop, grayscale, equalize, or save processed images."
        )
    )
    parser.add_argument("--input-dir", type=Path, default=repo_root / "人脸识别")
    parser.add_argument("--output-csv", type=Path, default=repo_root / "pca" / "data" / "auto_click_points" / "raw_face_points.csv")
    parser.add_argument("--task-file", type=Path, default=repo_root / "face_landmarker.task")
    parser.add_argument("--max-images", type=int, default=0, help="0 means all images.")
    return parser.parse_args()


def read_image_unicode(path: Path) -> np.ndarray | None:
    data = np.fromfile(str(path), dtype=np.uint8)
    if data.size == 0:
        return None
    return cv2.imdecode(data, cv2.IMREAD_COLOR)


def collect_images(input_dir: Path) -> list[Path]:
    return sorted(
        path
        for path in input_dir.rglob("*")
        if path.is_file() and path.suffix.lower() in IMAGE_SUFFIXES
    )


def label_from_path(path: Path) -> str:
    stem = path.stem.strip()
    stem = re.sub(r"\s*\(\d+\)$", "", stem)
    if "_" in stem:
        stem = stem.split("_", 1)[0]
    stem = re.sub(r"\d+$", "", stem)
    return LABEL_ALIASES.get(stem, stem)


def create_detector(task_file: Path):
    vision = mp.tasks.vision
    base_options = mp.tasks.BaseOptions(model_asset_path=str(task_file))
    options = vision.FaceLandmarkerOptions(
        base_options=base_options,
        running_mode=vision.RunningMode.IMAGE,
        num_faces=1,
        min_face_detection_confidence=0.35,
        min_face_presence_confidence=0.35,
        min_tracking_confidence=0.35,
    )
    return vision.FaceLandmarker.create_from_options(options)


def landmark_mean(landmarks, indices: tuple[int, ...], width: int, height: int) -> np.ndarray:
    return np.array(
        [[landmarks[index].x * width, landmarks[index].y * height] for index in indices],
        dtype=np.float32,
    ).mean(axis=0)


def detect_points(image_bgr: np.ndarray, detector) -> tuple[np.ndarray | None, str]:
    height, width = image_bgr.shape[:2]
    rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
    result = detector.detect(mp_image)
    if not result.face_landmarks:
        return None, "not_detected"

    landmarks = result.face_landmarks[0]
    left_eye = landmark_mean(landmarks, LEFT_EYE_INDICES, width, height)
    right_eye = landmark_mean(landmarks, RIGHT_EYE_INDICES, width, height)
    mouth = landmark_mean(landmarks, MOUTH_INDICES, width, height)
    eyes = sorted((left_eye, right_eye), key=lambda point: float(point[0]))
    return np.array([eyes[0], eyes[1], mouth], dtype=np.float32), "auto_points"


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    fieldnames = [
        "source_path",
        "label",
        "status",
        "left_eye_x",
        "left_eye_y",
        "right_eye_x",
        "right_eye_y",
        "mouth_x",
        "mouth_y",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8-sig") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    args = parse_args()
    input_dir = args.input_dir.resolve()
    output_csv = args.output_csv.resolve()
    task_file = args.task_file.resolve()

    if not input_dir.exists():
        raise FileNotFoundError(f"input dir not found: {input_dir}")
    if not task_file.exists():
        raise FileNotFoundError(f"task file not found: {task_file}")

    image_paths = collect_images(input_dir)
    if args.max_images > 0:
        image_paths = image_paths[: args.max_images]

    rows: list[dict[str, str]] = []
    with create_detector(task_file) as detector:
        for index, image_path in enumerate(image_paths, start=1):
            label = label_from_path(image_path)
            image = read_image_unicode(image_path)
            if image is None:
                points = None
                status = "read_failed"
            else:
                points, status = detect_points(image, detector)

            if points is None:
                row = {
                    "source_path": str(image_path),
                    "label": label,
                    "status": status,
                    "left_eye_x": "",
                    "left_eye_y": "",
                    "right_eye_x": "",
                    "right_eye_y": "",
                    "mouth_x": "",
                    "mouth_y": "",
                }
            else:
                row = {
                    "source_path": str(image_path),
                    "label": label,
                    "status": status,
                    "left_eye_x": f"{points[0, 0]:.3f}",
                    "left_eye_y": f"{points[0, 1]:.3f}",
                    "right_eye_x": f"{points[1, 0]:.3f}",
                    "right_eye_y": f"{points[1, 1]:.3f}",
                    "mouth_x": f"{points[2, 0]:.3f}",
                    "mouth_y": f"{points[2, 1]:.3f}",
                }

            rows.append(row)
            print(f"{index:04d}/{len(image_paths):04d} {status} {label} {image_path.name}")

    write_csv(output_csv, rows)
    ok_count = sum(1 for row in rows if row["status"] == "auto_points")
    fail_count = len(rows) - ok_count
    print("=" * 60)
    print(f"input: {input_dir}")
    print(f"csv: {output_csv}")
    print(f"images: {len(rows)}")
    print(f"auto_points: {ok_count}")
    print(f"failed: {fail_count}")
    print("No processed image was written by this script.")
    print("=" * 60)


if __name__ == "__main__":
    main()
