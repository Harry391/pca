from __future__ import annotations

import argparse
import csv
import re
import shutil
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
            "Developer helper: auto-generate left-eye/right-eye/mouth clicks "
            "with MediaPipe and export aligned faces. Not for MATLAB-only submission."
        )
    )
    parser.add_argument("--input-dir", type=Path, default=repo_root / "人脸识别")
    parser.add_argument("--output-dir", type=Path, default=repo_root / "pca" / "data" / "auto_clicked_raw_faces")
    parser.add_argument("--task-file", type=Path, default=repo_root / "face_landmarker.task")
    parser.add_argument("--width", type=int, default=92)
    parser.add_argument("--height", type=int, default=112)
    parser.add_argument("--clean", action="store_true", help="Remove output-dir before writing.")
    parser.add_argument("--max-images", type=int, default=0, help="0 means all images.")
    parser.add_argument("--preview-sheet", action="store_true", help="Write a visual contact sheet for quick checking.")
    return parser.parse_args()


def read_image_unicode(path: Path) -> np.ndarray | None:
    data = np.fromfile(str(path), dtype=np.uint8)
    if data.size == 0:
        return None
    return cv2.imdecode(data, cv2.IMREAD_COLOR)


def write_image_unicode(path: Path, image: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    suffix = path.suffix if path.suffix else ".jpg"
    ok, encoded = cv2.imencode(suffix, image)
    if not ok:
        raise RuntimeError(f"failed to encode image: {path}")
    encoded.tofile(str(path))


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


def target_points(width: int, height: int) -> np.ndarray:
    return np.array(
        [
            [0.32 * width, 0.38 * height],
            [0.68 * width, 0.38 * height],
            [0.50 * width, 0.72 * height],
        ],
        dtype=np.float32,
    )


def normalize_gray(gray: np.ndarray) -> np.ndarray:
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    return clahe.apply(gray)


def detect_click_points(image_bgr: np.ndarray, detector) -> tuple[np.ndarray | None, str]:
    height, width = image_bgr.shape[:2]
    rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
    result = detector.detect(mp_image)
    if not result.face_landmarks:
        return None, "fallback_resize"

    landmarks = result.face_landmarks[0]
    left_eye = landmark_mean(landmarks, LEFT_EYE_INDICES, width, height)
    right_eye = landmark_mean(landmarks, RIGHT_EYE_INDICES, width, height)
    mouth = landmark_mean(landmarks, MOUTH_INDICES, width, height)
    eyes = sorted((left_eye, right_eye), key=lambda point: float(point[0]))
    points = np.array([eyes[0], eyes[1], mouth], dtype=np.float32)
    return points, "auto_clicked"


def align_from_points(image_bgr: np.ndarray, points: np.ndarray, output_size: tuple[int, int]) -> np.ndarray:
    transform = cv2.getAffineTransform(points.astype(np.float32), target_points(*output_size))
    aligned = cv2.warpAffine(
        image_bgr,
        transform,
        output_size,
        flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_REFLECT_101,
    )
    return normalize_gray(cv2.cvtColor(aligned, cv2.COLOR_BGR2GRAY))


def fallback_resize(image_bgr: np.ndarray, output_size: tuple[int, int]) -> np.ndarray:
    resized = cv2.resize(image_bgr, output_size, interpolation=cv2.INTER_AREA)
    return normalize_gray(cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY))


def csv_escape_row(row: dict[str, str]) -> dict[str, str]:
    return row


def write_manifest(path: Path, rows: list[dict[str, str]]) -> None:
    fieldnames = [
        "source_path",
        "output_path",
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
        writer.writerows(csv_escape_row(row) for row in rows)


def write_preview_sheet(rows: list[dict[str, str]], output_dir: Path, max_items: int = 48) -> Path:
    image_paths = [Path(row["output_path"]) for row in rows if row["output_path"]][:max_items]
    if not image_paths:
        raise RuntimeError("no aligned images for preview sheet")

    scale = 3
    tile_w, tile_h = 92 * scale, 112 * scale
    cols = 8
    rows_count = int(np.ceil(len(image_paths) / cols))
    sheet = np.full((rows_count * tile_h, cols * tile_w), 255, dtype=np.uint8)

    for index, path in enumerate(image_paths):
        image = read_image_unicode(path)
        if image is None:
            continue
        if image.ndim == 3:
            image = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        thumb = cv2.resize(image, (tile_w, tile_h), interpolation=cv2.INTER_NEAREST)
        y = (index // cols) * tile_h
        x = (index % cols) * tile_w
        sheet[y : y + tile_h, x : x + tile_w] = thumb

    preview_path = output_dir / "auto_clicked_preview_sheet.png"
    write_image_unicode(preview_path, sheet)
    return preview_path


def main() -> None:
    args = parse_args()
    input_dir = args.input_dir.resolve()
    output_dir = args.output_dir.resolve()
    task_file = args.task_file.resolve()
    output_size = (args.width, args.height)

    if not input_dir.exists():
        raise FileNotFoundError(f"input dir not found: {input_dir}")
    if not task_file.exists():
        raise FileNotFoundError(f"task file not found: {task_file}")
    if args.clean and output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    image_paths = collect_images(input_dir)
    if args.max_images > 0:
        image_paths = image_paths[: args.max_images]

    rows: list[dict[str, str]] = []
    with create_detector(task_file) as detector:
        for index, image_path in enumerate(image_paths, start=1):
            label = label_from_path(image_path)
            image = read_image_unicode(image_path)
            if image is None:
                rows.append(
                    {
                        "source_path": str(image_path),
                        "output_path": "",
                        "label": label,
                        "status": "read_failed",
                        "left_eye_x": "",
                        "left_eye_y": "",
                        "right_eye_x": "",
                        "right_eye_y": "",
                        "mouth_x": "",
                        "mouth_y": "",
                    }
                )
                print(f"{index:04d}/{len(image_paths):04d} read_failed {image_path.name}")
                continue

            points, status = detect_click_points(image, detector)
            if points is None:
                aligned = fallback_resize(image, output_size)
                point_values = ["", "", "", "", "", ""]
            else:
                aligned = align_from_points(image, points, output_size)
                point_values = [
                    f"{points[0, 0]:.3f}",
                    f"{points[0, 1]:.3f}",
                    f"{points[1, 0]:.3f}",
                    f"{points[1, 1]:.3f}",
                    f"{points[2, 0]:.3f}",
                    f"{points[2, 1]:.3f}",
                ]

            output_path = output_dir / label / f"{image_path.stem}_auto_clicked.jpg"
            write_image_unicode(output_path, aligned)
            rows.append(
                {
                    "source_path": str(image_path),
                    "output_path": str(output_path),
                    "label": label,
                    "status": status,
                    "left_eye_x": point_values[0],
                    "left_eye_y": point_values[1],
                    "right_eye_x": point_values[2],
                    "right_eye_y": point_values[3],
                    "mouth_x": point_values[4],
                    "mouth_y": point_values[5],
                }
            )
            print(f"{index:04d}/{len(image_paths):04d} {status} {label} {output_path.name}")

    manifest_path = output_dir / "manual_alignment_manifest.csv"
    write_manifest(manifest_path, rows)

    preview_path = ""
    if args.preview_sheet:
        preview_path = str(write_preview_sheet(rows, output_dir))

    aligned_count = sum(1 for row in rows if row["status"] == "auto_clicked")
    fallback_count = sum(1 for row in rows if row["status"] == "fallback_resize")
    print("=" * 60)
    print(f"input: {input_dir}")
    print(f"output: {output_dir}")
    print(f"images: {len(rows)}")
    print(f"auto_clicked: {aligned_count}")
    print(f"fallback_resize: {fallback_count}")
    print(f"manifest: {manifest_path}")
    if preview_path:
        print(f"preview: {preview_path}")
    print("=" * 60)


if __name__ == "__main__":
    main()
