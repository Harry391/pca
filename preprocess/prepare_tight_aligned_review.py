from __future__ import annotations

import argparse
import csv
import re
import shutil
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np


IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
LABEL_ALIASES = {
    "刘驿恺": "刘毅凯",
}

LEFT_EYE_INDICES = (33, 133, 159, 145)
RIGHT_EYE_INDICES = (362, 263, 386, 374)
MOUTH_INDICES = (61, 291)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create tighter Python/MediaPipe aligned face previews for manual review."
    )
    parser.add_argument(
        "--input-dir",
        type=Path,
        default=Path("../../人脸识别"),
        help="Raw face image directory.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("../data/python_tight_aligned_raw_faces_review"),
        help="Review output directory.",
    )
    parser.add_argument(
        "--task-file",
        type=Path,
        default=Path("../../face_landmarker.task"),
        help="MediaPipe face landmarker task file.",
    )
    parser.add_argument("--width", type=int, default=92)
    parser.add_argument("--height", type=int, default=112)
    parser.add_argument("--gallery-limit", type=int, default=80)
    parser.add_argument("--clean", action="store_true")
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
    points = np.array(
        [[landmarks[index].x * width, landmarks[index].y * height] for index in indices],
        dtype=np.float32,
    )
    return points.mean(axis=0)


def target_points(width: int, height: int, mode: str) -> np.ndarray:
    if mode == "tight":
        return np.array(
            [
                [0.245 * width, 0.340 * height],
                [0.755 * width, 0.340 * height],
                [0.500 * width, 0.790 * height],
            ],
            dtype=np.float32,
        )

    return np.array(
        [
            [0.320 * width, 0.380 * height],
            [0.680 * width, 0.380 * height],
            [0.500 * width, 0.720 * height],
        ],
        dtype=np.float32,
    )


def normalize_gray(gray: np.ndarray) -> np.ndarray:
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    return clahe.apply(gray)


def apply_soft_face_mask(gray: np.ndarray) -> np.ndarray:
    h, w = gray.shape[:2]
    y_grid, x_grid = np.mgrid[0:h, 0:w].astype(np.float32)
    cx = (w - 1) * 0.50
    cy = (h - 1) * 0.545
    rx = w * 0.515
    ry = h * 0.610
    dist = ((x_grid - cx) / rx) ** 2 + ((y_grid - cy) / ry) ** 2
    mask = np.clip((1.18 - dist) / 0.18, 0.0, 1.0)
    neutral = np.full_like(gray, 127, dtype=np.float32)
    out = gray.astype(np.float32) * mask + neutral * (1.0 - mask)
    return np.clip(out, 0, 255).astype(np.uint8)


def align_image(
    image_bgr: np.ndarray,
    detector,
    output_size: tuple[int, int],
    mode: str,
) -> tuple[np.ndarray, dict[str, str]]:
    h, w = image_bgr.shape[:2]
    rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
    result = detector.detect(mp_image)

    if not result.face_landmarks:
        resized = cv2.resize(image_bgr, output_size, interpolation=cv2.INTER_AREA)
        gray = normalize_gray(cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY))
        return gray, {
            "status": "fallback_resize",
            "left_eye_x": "",
            "left_eye_y": "",
            "right_eye_x": "",
            "right_eye_y": "",
            "mouth_x": "",
            "mouth_y": "",
        }

    landmarks = result.face_landmarks[0]
    left_eye = landmark_mean(landmarks, LEFT_EYE_INDICES, w, h)
    right_eye = landmark_mean(landmarks, RIGHT_EYE_INDICES, w, h)
    mouth = landmark_mean(landmarks, MOUTH_INDICES, w, h)
    eyes = sorted((left_eye, right_eye), key=lambda point: point[0])
    source = np.array([eyes[0], eyes[1], mouth], dtype=np.float32)
    transform = cv2.getAffineTransform(source, target_points(output_size[0], output_size[1], mode))
    aligned = cv2.warpAffine(
        image_bgr,
        transform,
        output_size,
        flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_REFLECT_101,
    )
    gray = normalize_gray(cv2.cvtColor(aligned, cv2.COLOR_BGR2GRAY))
    return gray, {
        "status": "aligned",
        "left_eye_x": f"{eyes[0][0]:.3f}",
        "left_eye_y": f"{eyes[0][1]:.3f}",
        "right_eye_x": f"{eyes[1][0]:.3f}",
        "right_eye_y": f"{eyes[1][1]:.3f}",
        "mouth_x": f"{mouth[0]:.3f}",
        "mouth_y": f"{mouth[1]:.3f}",
    }


def fit_preview_original(image_bgr: np.ndarray, size: tuple[int, int]) -> np.ndarray:
    w, h = size
    src_h, src_w = image_bgr.shape[:2]
    scale = min(w / src_w, h / src_h)
    new_w = max(1, int(round(src_w * scale)))
    new_h = max(1, int(round(src_h * scale)))
    resized = cv2.resize(image_bgr, (new_w, new_h), interpolation=cv2.INTER_AREA)
    canvas = np.full((h, w, 3), 245, dtype=np.uint8)
    x = (w - new_w) // 2
    y = (h - new_h) // 2
    canvas[y:y + new_h, x:x + new_w] = resized
    return canvas


def to_bgr(gray_or_bgr: np.ndarray) -> np.ndarray:
    if gray_or_bgr.ndim == 2:
        return cv2.cvtColor(gray_or_bgr, cv2.COLOR_GRAY2BGR)
    return gray_or_bgr


def add_label(tile: np.ndarray, text: str) -> np.ndarray:
    out = tile.copy()
    cv2.rectangle(out, (0, 0), (out.shape[1], 14), (255, 255, 255), -1)
    cv2.putText(out, text, (2, 11), cv2.FONT_HERSHEY_SIMPLEX, 0.32, (0, 0, 0), 1, cv2.LINE_AA)
    return out


def make_gallery(rows: list[dict[str, str]], output_dir: Path, limit: int) -> None:
    sample_rows = rows[: min(limit, len(rows))]
    if not sample_rows:
        return

    tile_w, tile_h = 92, 112
    gap = 8
    row_h = tile_h + 26
    cols = 4
    canvas = np.full((row_h * len(sample_rows), cols * tile_w + (cols - 1) * gap, 3), 238, dtype=np.uint8)

    for r, row in enumerate(sample_rows):
        original = read_image_unicode(Path(row["source"]))
        if original is None:
            original_tile = np.full((tile_h, tile_w, 3), 220, dtype=np.uint8)
        else:
            original_tile = fit_preview_original(original, (tile_w, tile_h))

        standard = read_image_unicode(Path(row["standard_path"]))
        tight = read_image_unicode(Path(row["tight_path"]))
        masked = read_image_unicode(Path(row["tight_masked_path"]))
        if standard is not None and standard.ndim == 3:
            standard = cv2.cvtColor(standard, cv2.COLOR_BGR2GRAY)
        if tight is not None and tight.ndim == 3:
            tight = cv2.cvtColor(tight, cv2.COLOR_BGR2GRAY)
        if masked is not None and masked.ndim == 3:
            masked = cv2.cvtColor(masked, cv2.COLOR_BGR2GRAY)
        if standard is None:
            standard = np.full((tile_h, tile_w), 220, dtype=np.uint8)
        if tight is None:
            tight = np.full((tile_h, tile_w), 220, dtype=np.uint8)
        if masked is None:
            masked = np.full((tile_h, tile_w), 220, dtype=np.uint8)
        tiles = [
            add_label(original_tile, "original"),
            add_label(to_bgr(standard), "standard"),
            add_label(to_bgr(tight), "tight"),
            add_label(to_bgr(masked), "masked"),
        ]
        for c, tile in enumerate(tiles):
            x = c * (tile_w + gap)
            y = r * row_h
            canvas[y:y + tile_h, x:x + tile_w] = tile
        cv2.putText(
            canvas,
            row["label"][:18],
            (2, r * row_h + tile_h + 18),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.42,
            (20, 20, 20),
            1,
            cv2.LINE_AA,
        )

    write_image_unicode(output_dir / "review_gallery_first80.jpg", canvas)


def write_manifest(path: Path, rows: list[dict[str, str]]) -> None:
    fieldnames = [
        "source",
        "label",
        "status",
        "standard_path",
        "tight_path",
        "tight_masked_path",
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
    output_dir = args.output_dir.resolve()
    task_file = args.task_file.resolve()
    output_size = (args.width, args.height)

    if args.clean and output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    image_paths = collect_images(input_dir)
    rows: list[dict[str, str]] = []
    with create_detector(task_file) as detector:
        for index, image_path in enumerate(image_paths, 1):
            label = label_from_path(image_path)
            image = read_image_unicode(image_path)
            if image is None:
                print(f"{index:04d}/{len(image_paths):04d} read_failed {image_path.name}")
                continue

            standard, info = align_image(image, detector, output_size, "standard")
            tight, _ = align_image(image, detector, output_size, "tight")
            tight_masked = apply_soft_face_mask(tight)

            filename = f"{image_path.stem}.jpg"
            standard_path = output_dir / "standard" / label / filename
            tight_path = output_dir / "tight" / label / filename
            tight_masked_path = output_dir / "tight_masked" / label / filename
            write_image_unicode(standard_path, standard)
            write_image_unicode(tight_path, tight)
            write_image_unicode(tight_masked_path, tight_masked)

            row = {
                "source": str(image_path),
                "label": label,
                "status": info["status"],
                "standard_path": str(standard_path),
                "tight_path": str(tight_path),
                "tight_masked_path": str(tight_masked_path),
                **info,
            }
            rows.append(row)
            print(f"{index:04d}/{len(image_paths):04d} {info['status']} {label} {image_path.name}")

    write_manifest(output_dir / "tight_alignment_review_manifest.csv", rows)
    make_gallery(rows, output_dir, args.gallery_limit)

    print("=" * 70)
    print(f"input: {input_dir}")
    print(f"output: {output_dir}")
    print(f"images: {len(rows)}/{len(image_paths)}")
    print(f"standard: {output_dir / 'standard'}")
    print(f"tight: {output_dir / 'tight'}")
    print(f"tight_masked: {output_dir / 'tight_masked'}")
    print(f"gallery: {output_dir / 'review_gallery_first80.jpg'}")
    print("=" * 70)


if __name__ == "__main__":
    main()
