from __future__ import annotations

import argparse
import csv
import re
import shutil
from collections import defaultdict
from pathlib import Path

import numpy as np

from prepare_tight_aligned_review import (
    IMAGE_SUFFIXES,
    align_image,
    apply_soft_face_mask,
    create_detector,
    label_from_path,
    read_image_unicode,
    write_image_unicode,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Rebuild tight-masked face dataset: ignore trailing () images, force 10 per person, split 8:2."
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
        default=Path("../data/python_tight_masked_pca_svm_split"),
        help="Output dataset root with all/train/test.",
    )
    parser.add_argument(
        "--task-file",
        type=Path,
        default=Path("../../face_landmarker.task"),
        help="MediaPipe face landmarker task file.",
    )
    parser.add_argument("--width", type=int, default=92)
    parser.add_argument("--height", type=int, default=112)
    parser.add_argument("--per-class", type=int, default=10)
    parser.add_argument("--train-per-class", type=int, default=8)
    parser.add_argument("--test-per-class", type=int, default=2)
    parser.add_argument("--seed", type=int, default=20260620)
    parser.add_argument("--clean", action="store_true")
    return parser.parse_args()


def is_ignored_marked(path: Path) -> bool:
    return re.search(r"\(\)\s*$", path.stem) is not None


def collect_images(input_dir: Path) -> list[Path]:
    return sorted(
        path
        for path in input_dir.rglob("*")
        if path.is_file() and path.suffix.lower() in IMAGE_SUFFIXES
    )


def numeric_suffix(path: Path) -> int:
    match = re.search(r"(\d+)$", path.stem)
    if match is None:
        return 10**9
    return int(match.group(1))


def safe_output_name(source_path: Path, duplicate_index: int | None = None) -> str:
    stem = source_path.stem
    if duplicate_index is not None:
        stem = f"{stem}__dup{duplicate_index:02d}"
    return f"{stem}.jpg"


def write_csv(path: Path, rows: list[dict[str, str]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8-sig") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def process_sources(
    input_dir: Path,
    output_dir: Path,
    task_file: Path,
    output_size: tuple[int, int],
) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    all_dir = output_dir / "all"
    image_paths = collect_images(input_dir)
    ignored_rows: list[dict[str, str]] = []
    processed_rows: list[dict[str, str]] = []

    with create_detector(task_file) as detector:
        for index, image_path in enumerate(image_paths, 1):
            label = label_from_path(image_path)
            if is_ignored_marked(image_path):
                ignored_rows.append(
                    {
                        "source_path": str(image_path),
                        "label": label,
                        "reason": "filename_ends_with_empty_parentheses",
                    }
                )
                print(f"{index:04d}/{len(image_paths):04d} ignored {label} {image_path.name}")
                continue

            image = read_image_unicode(image_path)
            if image is None:
                ignored_rows.append(
                    {
                        "source_path": str(image_path),
                        "label": label,
                        "reason": "read_failed",
                    }
                )
                print(f"{index:04d}/{len(image_paths):04d} read_failed {label} {image_path.name}")
                continue

            tight, info = align_image(image, detector, output_size, "tight")
            tight_masked = apply_soft_face_mask(tight)
            output_path = all_dir / label / safe_output_name(image_path)
            if not write_image_unicode(output_path, tight_masked):
                raise RuntimeError(f"failed to write processed image: {output_path}")

            processed_rows.append(
                {
                    "source_path": str(image_path),
                    "label": label,
                    "all_path": str(output_path),
                    "status": info["status"],
                    "is_duplicate": "0",
                    "duplicate_from": "",
                }
            )
            print(f"{index:04d}/{len(image_paths):04d} {info['status']} {label} {image_path.name}")

    return processed_rows, ignored_rows


def force_exact_per_class(
    rows: list[dict[str, str]],
    output_dir: Path,
    per_class: int,
    seed: int,
) -> list[dict[str, str]]:
    rng = np.random.default_rng(seed)
    grouped: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        grouped[row["label"]].append(row)

    exact_rows: list[dict[str, str]] = []
    for label in sorted(grouped):
        label_rows = sorted(grouped[label], key=lambda row: (numeric_suffix(Path(row["source_path"])), row["source_path"]))
        if len(label_rows) >= per_class:
            order = np.arange(len(label_rows))
            rng.shuffle(order)
            keep_indices = sorted(order[:per_class].tolist())
            exact_rows.extend(dict(label_rows[index]) for index in keep_indices)
            continue

        exact_rows.extend(dict(row) for row in label_rows)
        if not label_rows:
            continue

        duplicate_needed = per_class - len(label_rows)
        for duplicate_index in range(1, duplicate_needed + 1):
            source_row = label_rows[(duplicate_index - 1) % len(label_rows)]
            source_path = Path(source_row["all_path"])
            duplicate_path = output_dir / "all" / label / safe_output_name(Path(source_row["source_path"]), duplicate_index)
            shutil.copy2(source_path, duplicate_path)

            row = dict(source_row)
            row["all_path"] = str(duplicate_path)
            row["is_duplicate"] = "1"
            row["duplicate_from"] = source_row["all_path"]
            exact_rows.append(row)

    return exact_rows


def split_rows(
    rows: list[dict[str, str]],
    output_dir: Path,
    train_per_class: int,
    test_per_class: int,
    seed: int,
) -> list[dict[str, str]]:
    rng = np.random.default_rng(seed)
    grouped: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        grouped[row["label"]].append(row)

    split_rows_out: list[dict[str, str]] = []
    for label in sorted(grouped):
        label_rows = list(grouped[label])
        preferred_test_indices = [
            index
            for index, row in enumerate(label_rows)
            if row["status"] == "aligned" and row["is_duplicate"] == "0"
        ]
        fallback_test_indices = [
            index
            for index in range(len(label_rows))
            if index not in preferred_test_indices
        ]
        rng.shuffle(preferred_test_indices)
        rng.shuffle(fallback_test_indices)
        test_indices = set((preferred_test_indices + fallback_test_indices)[:test_per_class])

        for index, row in enumerate(label_rows):
            split_name = "test" if index in test_indices else "train"

            all_path = Path(row["all_path"])
            split_path = output_dir / split_name / label / all_path.name
            split_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(all_path, split_path)

            out_row = dict(row)
            out_row["split"] = split_name
            out_row["split_path"] = str(split_path)
            split_rows_out.append(out_row)

    return split_rows_out


def main() -> None:
    args = parse_args()
    input_dir = args.input_dir.resolve()
    output_dir = args.output_dir.resolve()
    task_file = args.task_file.resolve()
    output_size = (args.width, args.height)

    if args.per_class != args.train_per_class + args.test_per_class:
        raise ValueError("per-class count must equal train-per-class + test-per-class")

    if args.clean and output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    processed_rows, ignored_rows = process_sources(input_dir, output_dir, task_file, output_size)
    exact_rows = force_exact_per_class(processed_rows, output_dir, args.per_class, args.seed)
    split_rows_out = split_rows(exact_rows, output_dir, args.train_per_class, args.test_per_class, args.seed + 1)

    manifest_fields = [
        "label",
        "split",
        "source_path",
        "all_path",
        "split_path",
        "status",
        "is_duplicate",
        "duplicate_from",
    ]
    write_csv(output_dir / "tight_masked_split_manifest.csv", split_rows_out, manifest_fields)
    write_csv(output_dir / "ignored_images.csv", ignored_rows, ["source_path", "label", "reason"])

    labels = sorted({row["label"] for row in split_rows_out})
    train_count = sum(1 for row in split_rows_out if row["split"] == "train")
    test_count = sum(1 for row in split_rows_out if row["split"] == "test")
    duplicate_count = sum(1 for row in split_rows_out if row["is_duplicate"] == "1")
    fallback_count = sum(1 for row in split_rows_out if row["status"] != "aligned")

    print("=" * 70)
    print(f"input: {input_dir}")
    print(f"output: {output_dir}")
    print(f"classes: {len(labels)}")
    print(f"ignored: {len(ignored_rows)}")
    print(f"processed used: {len(split_rows_out)}")
    print(f"train/test: {train_count}/{test_count}")
    print(f"duplicates: {duplicate_count}")
    print(f"fallback/non-aligned used: {fallback_count}")
    print(f"all: {output_dir / 'all'}")
    print(f"train: {output_dir / 'train'}")
    print(f"test: {output_dir / 'test'}")
    print(f"manifest: {output_dir / 'tight_masked_split_manifest.csv'}")
    print(f"ignored list: {output_dir / 'ignored_images.csv'}")
    print("=" * 70)


if __name__ == "__main__":
    main()
