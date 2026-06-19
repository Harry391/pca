from __future__ import annotations

import argparse
import json

import cv2


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Probe OpenCV camera indices and backends.")
    parser.add_argument("--max-index", type=int, default=5, help="Maximum camera index to probe.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    try:
        if hasattr(cv2, "setLogLevel"):
            cv2.setLogLevel(0)
    except Exception:
        pass
    backend_items = [
        ("CAP_DSHOW", cv2.CAP_DSHOW),
        ("CAP_MSMF", cv2.CAP_MSMF),
        ("CAP_ANY", cv2.CAP_ANY),
    ]

    results = []
    for index in range(args.max_index + 1):
        for backend_name, backend in backend_items:
            cap = cv2.VideoCapture(index, backend)
            opened = cap.isOpened()
            read_ok = False
            frame_shape = None
            if opened:
                read_ok, frame = cap.read()
                if read_ok and frame is not None:
                    frame_shape = list(frame.shape)
            cap.release()
            results.append(
                {
                    "index": index,
                    "backend": backend_name,
                    "opened": bool(opened),
                    "read_ok": bool(read_ok),
                    "frame_shape": frame_shape,
                }
            )

    print("JSON_BEGIN")
    print(json.dumps(results, ensure_ascii=False, indent=2))
    print("JSON_END")


if __name__ == "__main__":
    main()
