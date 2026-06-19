from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np


LEFT_EYE_INDICES = (33, 133, 159, 145)
RIGHT_EYE_INDICES = (362, 263, 386, 374)
MOUTH_INDICES = (61, 291)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Align a single face image with MediaPipe landmarks."
    )
    parser.add_argument("--input", type=Path, required=True, help="Input image path.")
    parser.add_argument("--output", type=Path, required=True, help="Output aligned grayscale image path.")
    parser.add_argument(
        "--task-file",
        type=Path,
        default=Path("../../face_landmarker.task"),
        help="MediaPipe face landmarker task file.",
    )
    parser.add_argument("--width", type=int, default=92, help="Output width.")
    parser.add_argument("--height", type=int, default=112, help="Output height.")
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


def target_points(width: int, height: int) -> np.ndarray:
    return np.array(
        [
            [0.245 * width, 0.340 * height],
            [0.755 * width, 0.340 * height],
            [0.500 * width, 0.790 * height],
        ],
        dtype=np.float32,
    )


def normalize_gray(gray: np.ndarray) -> np.ndarray:
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    return clahe.apply(gray)


def apply_soft_face_mask(gray: np.ndarray) -> np.ndarray:
    height, width = gray.shape[:2]
    y_grid, x_grid = np.mgrid[0:height, 0:width].astype(np.float32)
    cx = (width - 1) * 0.50
    cy = (height - 1) * 0.545
    rx = width * 0.515
    ry = height * 0.610
    dist = ((x_grid - cx) / rx) ** 2 + ((y_grid - cy) / ry) ** 2
    mask = np.clip((1.18 - dist) / 0.18, 0.0, 1.0)
    neutral = np.full_like(gray, 127, dtype=np.float32)
    out = gray.astype(np.float32) * mask + neutral * (1.0 - mask)
    return np.clip(out, 0, 255).astype(np.uint8)


def align_with_landmarks(
    image_bgr: np.ndarray,
    detector,
    output_size: tuple[int, int],
) -> tuple[np.ndarray, str]:
    height, width = image_bgr.shape[:2]
    rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
    result = detector.detect(mp_image)

    if not result.face_landmarks:
        resized = cv2.resize(image_bgr, output_size, interpolation=cv2.INTER_AREA)
        gray = normalize_gray(cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY))
        return apply_soft_face_mask(gray), "fallback_resize"

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
    return apply_soft_face_mask(gray), "tight_masked_aligned"


def main() -> None:
    args = parse_args()
    task_file = args.task_file.resolve()
    image = read_image_unicode(args.input.resolve())
    if image is None:
        raise RuntimeError(f"failed to read input image: {args.input}")

    with create_detector(task_file) as detector:
        aligned, status = align_with_landmarks(image, detector, (args.width, args.height))

    if not write_image_unicode(args.output.resolve(), aligned):
        raise RuntimeError(f"failed to write output image: {args.output}")

    print(status)


if __name__ == "__main__":
    main()
