from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np


LEFT_EYE_INDICES = (33, 133, 159, 145)
RIGHT_EYE_INDICES = (362, 263, 386, 374)
MOUTH_INDICES = (61, 291)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a persistent webcam alignment bridge for MATLAB."
    )
    parser.add_argument("--session-dir", type=Path, required=True, help="Bridge output directory.")
    parser.add_argument(
        "--task-file",
        type=Path,
        required=True,
        help="MediaPipe face landmarker task file.",
    )
    parser.add_argument("--camera-index", type=int, default=0, help="OpenCV camera index.")
    parser.add_argument("--width", type=int, default=92, help="Aligned face width.")
    parser.add_argument("--height", type=int, default=112, help="Aligned face height.")
    parser.add_argument("--max-fps", type=float, default=12.0, help="Capture upper FPS bound.")
    return parser.parse_args()


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def read_image_unicode(path: Path) -> np.ndarray | None:
    data = np.fromfile(str(path), dtype=np.uint8)
    if data.size == 0:
        return None
    return cv2.imdecode(data, cv2.IMREAD_COLOR)


def write_image_unicode(path: Path, image: np.ndarray) -> None:
    suffix = path.suffix or ".png"
    ok, encoded = cv2.imencode(suffix, image)
    if not ok:
        raise RuntimeError(f"failed to encode image for {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded.tofile(str(path))


def write_text_atomic(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def write_json_atomic(path: Path, payload: dict) -> None:
    write_text_atomic(path, json.dumps(payload, ensure_ascii=False, indent=2))


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


def clamp_box(box: tuple[int, int, int, int], width: int, height: int) -> list[int]:
    x, y, w, h = box
    x = max(0, min(int(round(x)), width - 1))
    y = max(0, min(int(round(y)), height - 1))
    w = max(1, min(int(round(w)), width - x))
    h = max(1, min(int(round(h)), height - y))
    return [x + 1, y + 1, w, h]


def compute_face_box(landmarks, width: int, height: int) -> list[int]:
    points = np.array(
        [[point.x * width, point.y * height] for point in landmarks],
        dtype=np.float32,
    )
    min_xy = points.min(axis=0)
    max_xy = points.max(axis=0)
    center = (min_xy + max_xy) * 0.5
    size = max(max_xy[0] - min_xy[0], max_xy[1] - min_xy[1])

    inner_size = size * 1.08
    x = center[0] - inner_size * 0.5
    y = center[1] - inner_size * 0.42
    w = inner_size
    h = inner_size * 1.12
    return clamp_box((x, y, w, h), width, height)


def center_crop_resize(image_bgr: np.ndarray, output_size: tuple[int, int]) -> np.ndarray:
    height, width = image_bgr.shape[:2]
    side = min(height, width)
    x = (width - side) // 2
    y = (height - side) // 2
    crop = image_bgr[y:y + side, x:x + side]
    resized = cv2.resize(crop, output_size, interpolation=cv2.INTER_AREA)
    gray = normalize_gray(cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY))
    return apply_soft_face_mask(gray)


def align_frame(
    image_bgr: np.ndarray,
    detector,
    output_size: tuple[int, int],
) -> tuple[np.ndarray, list[int], str]:
    height, width = image_bgr.shape[:2]
    rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
    result = detector.detect(mp_image)

    if not result.face_landmarks:
        fallback = center_crop_resize(image_bgr, output_size)
        return fallback, [], "no_face_fallback"

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
    gray = apply_soft_face_mask(gray)
    face_box = compute_face_box(landmarks, width, height)
    return gray, face_box, "tight_masked_aligned"


def open_camera(camera_index: int) -> cv2.VideoCapture:
    attempts = [
        ("CAP_DSHOW", cv2.CAP_DSHOW),
        ("CAP_MSMF", cv2.CAP_MSMF),
        ("CAP_ANY", cv2.CAP_ANY),
    ]

    errors: list[str] = []
    for backend_name, backend in attempts:
        cap = cv2.VideoCapture(camera_index, backend)
        if not cap.isOpened():
            cap.release()
            errors.append(f"{backend_name}: open failed")
            continue

        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        ok, frame = cap.read()
        if ok and frame is not None:
            return cap

        cap.release()
        errors.append(f"{backend_name}: open ok but read failed")

    raise RuntimeError(
        f"failed to open camera index {camera_index}; attempts: {'; '.join(errors)}"
    )


def main() -> None:
    args = parse_args()
    session_dir = args.session_dir.resolve()
    task_file = args.task_file.resolve()
    raw_frame_path = session_dir / "latest_raw.jpg"
    aligned_face_path = session_dir / "latest_aligned.png"
    meta_path = session_dir / "latest_meta.json"
    stop_flag_path = session_dir / "stop.flag"
    heartbeat_path = session_dir / "heartbeat.txt"

    ensure_dir(session_dir)
    if stop_flag_path.exists():
        stop_flag_path.unlink()

    interval = 1.0 / max(args.max_fps, 1.0)
    write_json_atomic(
        meta_path,
        {
            "sequence": 0,
            "status": "starting",
            "message": "python bridge starting",
            "rawFramePath": str(raw_frame_path),
            "alignedFacePath": str(aligned_face_path),
        },
    )

    cap = None
    sequence = 0
    final_status_written = False

    try:
        cap = open_camera(args.camera_index)
        with create_detector(task_file) as detector:
            while not stop_flag_path.exists():
                tic = time.perf_counter()
                ok, frame = cap.read()
                if not ok or frame is None:
                    write_json_atomic(
                        meta_path,
                        {
                            "sequence": sequence,
                            "status": "camera_read_failed",
                            "message": "failed to read camera frame",
                            "rawFramePath": str(raw_frame_path),
                            "alignedFacePath": str(aligned_face_path),
                        },
                    )
                    time.sleep(0.05)
                    continue

                aligned, face_box, status = align_frame(frame, detector, (args.width, args.height))
                write_image_unicode(raw_frame_path, frame)
                write_image_unicode(aligned_face_path, aligned)

                sequence += 1
                elapsed_ms = (time.perf_counter() - tic) * 1000.0
                payload = {
                    "sequence": sequence,
                    "timestamp": time.time(),
                    "status": status,
                    "message": status,
                    "faceBox": face_box,
                    "frameWidth": int(frame.shape[1]),
                    "frameHeight": int(frame.shape[0]),
                    "alignedWidth": int(aligned.shape[1]),
                    "alignedHeight": int(aligned.shape[0]),
                    "processMs": elapsed_ms,
                    "rawFramePath": str(raw_frame_path),
                    "alignedFacePath": str(aligned_face_path),
                }
                write_json_atomic(meta_path, payload)
                write_text_atomic(heartbeat_path, f"{sequence}\n")

                sleep_time = interval - (time.perf_counter() - tic)
                if sleep_time > 0:
                    time.sleep(sleep_time)
    except Exception as exc:
        write_json_atomic(
            meta_path,
            {
                "sequence": sequence,
                "status": "startup_error",
                "message": str(exc),
                "rawFramePath": str(raw_frame_path),
                "alignedFacePath": str(aligned_face_path),
            },
        )
        final_status_written = True
        raise
    finally:
        if cap is not None:
            cap.release()
        if not stop_flag_path.exists() and not final_status_written:
            write_json_atomic(
                meta_path,
                {
                    "sequence": sequence,
                    "status": "stopped",
                    "message": "python bridge stopped",
                    "rawFramePath": str(raw_frame_path),
                    "alignedFacePath": str(aligned_face_path),
                },
            )


if __name__ == "__main__":
    main()
