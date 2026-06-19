from __future__ import annotations

import argparse
import csv
import re
import shutil
from collections import defaultdict
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np


IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
LABEL_ALIASES = {
    "刘驿恺": "刘毅凯",
}

# MediaPipe Face Mesh landmark indices. We average stable eye rim points and
# use both mouth corners to reduce one-point detector noise.
LEFT_EYE_INDICES = (33, 133, 159, 145)
RIGHT_EYE_INDICES = (362, 263, 386, 374)
MOUTH_INDICES = (61, 291)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Align flat face images with MediaPipe landmarks and create an 8:2 train/test split."
    )
    parser.add_argument(
        "--input-dir",
        type=Path,
        default=Path("../../final_result"),
        help="Source image directory. Defaults to ../../final_result when run from pca/preprocess.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("../data/aligned_faces"),
        help="Output dataset root. Defaults to ../data/aligned_faces.",
    )
    parser.add_argument(
        "--task-file",
        type=Path,
        default=Path("../../face_landmarker.task"),
        help="MediaPipe face landmarker .task file.",
    )
    parser.add_argument("--width", type=int, default=92, help="Output image width.")
    parser.add_argument("--height", type=int, default=112, help="Output image height.")
    parser.add_argument("--train-per-class", type=int, default=8, help="Training images per class.")
    parser.add_argument("--test-per-class", type=int, default=2, help="Test images per class.")
    parser.add_argument("--seed", type=int, default=20260615, help="Deterministic split seed.")
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Remove the output directory before writing new results.",
    )
    parser.add_argument(
        "--drop-failed",
        action="store_true",
        help="Drop images when landmark detection fails. By default failed images are resized and flagged.",
    )
    return parser.parse_args()


def read_image_unicode(path: Path) -> np.ndarray | None:
    data = np.fromfile(str(path), dtype=np.uint8)
    if data.size == 0:
        return None
    return cv2.imdecode(data, cv2.IMREAD_COLOR)


def write_image_unicode(path: Path, image: np.ndarray) -> bool:
    path.parent.mkdir(parents=True, exist_ok=True)
    ok, encoded = cv2.imencode(path.suffix or ".jpg", image)
    if not ok:
        return False
    encoded.tofile(str(path))
    return True


def collect_images(input_dir: Path) -> list[Path]:
    if not input_dir.exists():
        raise FileNotFoundError(f"Input directory does not exist: {input_dir}")
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


def numeric_suffix(path: Path) -> int:
    match = re.search(r"(\d+)$", path.stem)
    if match is None:
        return 10**9
    return int(match.group(1))


def landmark_mean(landmarks, indices: tuple[int, ...], width: int, height: int) -> np.ndarray:
    points = np.array(
        [[landmarks[index].x * width, landmarks[index].y * height] for index in indices],
        dtype=np.float32,
    )
    return points.mean(axis=0)


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


def align_with_landmarks(
    image_bgr: np.ndarray,
    detector,
    output_size: tuple[int, int],
) -> tuple[np.ndarray, dict[str, str]]:
    height, width = image_bgr.shape[:2]
    rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
    result = detector.detect(mp_image)

    if not result.face_landmarks:
        resized = cv2.resize(image_bgr, output_size, interpolation=cv2.INTER_AREA)
        gray = normalize_gray(cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY))
        return gray, {
            "status": "fallback_resize",
            "needs_manual_review": "1",
            "left_eye_x": "",
            "left_eye_y": "",
            "right_eye_x": "",
            "right_eye_y": "",
            "mouth_x": "",
            "mouth_y": "",
        }

    landmarks = result.face_landmarks[0]
    left_eye = landmark_mean(landmarks, LEFT_EYE_INDICES, width, height)
    right_eye = landmark_mean(landmarks, RIGHT_EYE_INDICES, width, height)
    mouth = landmark_mean(landmarks, MOUTH_INDICES, width, height)

    eyes = sorted((left_eye, right_eye), key=lambda point: point[0])
    source = np.array([eyes[0], eyes[1], mouth], dtype=np.float32)
    transform = cv2.getAffineTransform(source, target_points(output_size[0], output_size[1]))
    aligned = cv2.warpAffine(
        image_bgr,
        transform,
        output_size,
        flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_REFLECT_101,
    )
    gray = normalize_gray(cv2.cvtColor(aligned, cv2.COLOR_BGR2GRAY))

    eye_y_gap = abs(float(eyes[0][1] - eyes[1][1]))
    eye_distance = float(np.linalg.norm(eyes[1] - eyes[0]))
    needs_review = eye_distance < width * 0.15 or eye_y_gap > height * 0.12

    return gray, {
        "status": "aligned",
        "needs_manual_review": "1" if needs_review else "0",
        "left_eye_x": f"{eyes[0][0]:.3f}",
        "left_eye_y": f"{eyes[0][1]:.3f}",
        "right_eye_x": f"{eyes[1][0]:.3f}",
        "right_eye_y": f"{eyes[1][1]:.3f}",
        "mouth_x": f"{mouth[0]:.3f}",
        "mouth_y": f"{mouth[1]:.3f}",
    }


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


def split_by_label(
    rows: list[dict[str, str]],
    train_per_class: int,
    test_per_class: int,
    seed: int,
) -> list[dict[str, str]]:
    rng = np.random.default_rng(seed)
    grouped: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        grouped[row["label"]].append(row)

    split_rows: list[dict[str, str]] = []
    for label in sorted(grouped):
        label_rows = sorted(grouped[label], key=lambda item: (numeric_suffix(Path(item["source"])), item["source"]))
        expected = train_per_class + test_per_class
        if len(label_rows) == expected:
            train_count = train_per_class
        else:
            train_count = max(1, int(round(len(label_rows) * train_per_class / expected)))
            train_count = min(train_count, max(0, len(label_rows) - 1))

        order = np.arange(len(label_rows))
        rng.shuffle(order)
        train_indices = set(order[:train_count].tolist())

        for index, row in enumerate(label_rows):
            row = dict(row)
            row["split"] = "train" if index in train_indices else "test"
            split_rows.append(row)

    return split_rows


def copy_split_images(output_dir: Path, rows: list[dict[str, str]]) -> None:
    for row in rows:
        all_path = Path(row["aligned_path"])
        split_path = output_dir / row["split"] / row["label"] / all_path.name
        split_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(all_path, split_path)
        row["split_path"] = str(split_path)


def write_csv(path: Path, rows: list[dict[str, str]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8-sig") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    args = parse_args()
    input_dir = args.input_dir.resolve()
    output_dir = args.output_dir.resolve()
    task_file = args.task_file.resolve()

    if not task_file.exists():
        raise FileNotFoundError(f"MediaPipe task file does not exist: {task_file}")

    if args.clean and output_dir.exists():
        shutil.rmtree(output_dir)

    output_size = (args.width, args.height)
    image_paths = collect_images(input_dir)
    rows: list[dict[str, str]] = []

    with create_detector(task_file) as detector:
        for image_path in image_paths:
            label = label_from_path(image_path)
            image = read_image_unicode(image_path)
            if image is None:
                rows.append(
                    {
                        "source": str(image_path),
                        "label": label,
                        "aligned_path": "",
                        "status": "read_failed",
                        "needs_manual_review": "1",
                    }
                )
                continue

            aligned, info = align_with_landmarks(image, detector, output_size)
            if info["status"] != "aligned" and args.drop_failed:
                aligned_path = ""
            else:
                aligned_name = f"{image_path.stem}.jpg"
                aligned_path = output_dir / "all" / label / aligned_name
                if not write_image_unicode(aligned_path, aligned):
                    raise RuntimeError(f"Failed to write image: {aligned_path}")

            row = {
                "source": str(image_path),
                "label": label,
                "aligned_path": str(aligned_path),
                "width": str(args.width),
                "height": str(args.height),
                **info,
            }
            rows.append(row)
            print(f"{info['status']}: {image_path.name}")

    usable_rows = [row for row in rows if row.get("aligned_path")]
    split_rows = split_by_label(
        usable_rows,
        train_per_class=args.train_per_class,
        test_per_class=args.test_per_class,
        seed=args.seed,
    )
    copy_split_images(output_dir, split_rows)

    report_fields = [
        "source",
        "label",
        "aligned_path",
        "split",
        "split_path",
        "width",
        "height",
        "status",
        "needs_manual_review",
        "left_eye_x",
        "left_eye_y",
        "right_eye_x",
        "right_eye_y",
        "mouth_x",
        "mouth_y",
    ]
    write_csv(output_dir / "alignment_split_manifest.csv", split_rows, report_fields)

    failed_rows = [row for row in rows if not row.get("aligned_path")]
    if failed_rows:
        write_csv(
            output_dir / "failed_images.csv",
            failed_rows,
            ["source", "label", "aligned_path", "status", "needs_manual_review"],
        )

    label_count = len({row["label"] for row in split_rows})
    train_count = sum(1 for row in split_rows if row["split"] == "train")
    test_count = sum(1 for row in split_rows if row["split"] == "test")
    review_count = sum(1 for row in split_rows if row["needs_manual_review"] == "1")

    print("=" * 60)
    print(f"input images: {len(image_paths)}")
    print(f"usable images: {len(split_rows)}")
    print(f"classes: {label_count}")
    print(f"train/test: {train_count}/{test_count}")
    print(f"manual review suggested: {review_count}")
    print(f"output: {output_dir}")
    print("=" * 60)


if __name__ == "__main__":
    main()
