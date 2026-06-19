from __future__ import annotations

import argparse
import csv
import re
import shutil
from pathlib import Path

import numpy as np


IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".bmp", ".webp", ".tif", ".tiff"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create 8:2 train/test split for tight-masked aligned faces.")
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=Path("../data/python_tight_aligned_raw_faces_review/tight_masked"),
        help="Per-label tight_masked source directory.",
    )
    parser.add_argument(
        "--split-dir",
        type=Path,
        default=Path("../data/python_tight_masked_pca_svm_split"),
        help="Output split root.",
    )
    parser.add_argument("--train-per-class", type=int, default=8)
    parser.add_argument("--test-per-class", type=int, default=2)
    parser.add_argument("--seed", type=int, default=20260620)
    parser.add_argument("--clean", action="store_true")
    return parser.parse_args()


def list_images(folder: Path) -> list[Path]:
    return sorted(
        path
        for path in folder.iterdir()
        if path.is_file() and path.suffix.lower() in IMAGE_SUFFIXES
    )


def numeric_suffix(path: Path) -> int:
    match = re.search(r"(\d+)$", path.stem)
    if match is None:
        return 10**9
    return int(match.group(1))


def csv_escape(value: str) -> str:
    return value.replace('"', '""')


def copy_split(
    source_dir: Path,
    split_dir: Path,
    train_per_class: int,
    test_per_class: int,
    seed: int,
    clean: bool,
) -> list[dict[str, str]]:
    if not source_dir.is_dir():
        raise FileNotFoundError(f"source directory not found: {source_dir}")

    if clean and split_dir.exists():
        shutil.rmtree(split_dir)

    rng = np.random.default_rng(seed)
    train_dir = split_dir / "train"
    test_dir = split_dir / "test"
    train_dir.mkdir(parents=True, exist_ok=True)
    test_dir.mkdir(parents=True, exist_ok=True)

    rows: list[dict[str, str]] = []
    expected_count = train_per_class + test_per_class

    for label_dir in sorted(path for path in source_dir.iterdir() if path.is_dir()):
        files = sorted(list_images(label_dir), key=lambda item: (numeric_suffix(item), item.name))
        if not files:
            continue

        if len(files) == expected_count:
            train_count = train_per_class
        else:
            train_count = max(1, int(round(len(files) * train_per_class / expected_count)))
            train_count = min(train_count, max(0, len(files) - 1))

        order = np.arange(len(files))
        rng.shuffle(order)
        train_indices = set(order[:train_count].tolist())

        for index, source_path in enumerate(files):
            split_name = "train" if index in train_indices else "test"
            target_path = split_dir / split_name / label_dir.name / source_path.name
            target_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_path, target_path)
            rows.append(
                {
                    "label": label_dir.name,
                    "split": split_name,
                    "source_path": str(source_path),
                    "split_path": str(target_path),
                }
            )

    return rows


def write_manifest(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", newline="", encoding="utf-8-sig") as file:
        writer = csv.DictWriter(file, fieldnames=["label", "split", "source_path", "split_path"])
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    args = parse_args()
    source_dir = args.source_dir.resolve()
    split_dir = args.split_dir.resolve()

    rows = copy_split(source_dir, split_dir, args.train_per_class, args.test_per_class, args.seed, args.clean)
    write_manifest(split_dir / "tight_masked_split_manifest.csv", rows)

    labels = sorted({row["label"] for row in rows})
    train_count = sum(1 for row in rows if row["split"] == "train")
    test_count = sum(1 for row in rows if row["split"] == "test")
    print("=" * 70)
    print(f"source: {source_dir}")
    print(f"split: {split_dir}")
    print(f"classes: {len(labels)}")
    print(f"train/test: {train_count}/{test_count}")
    print(f"manifest: {split_dir / 'tight_masked_split_manifest.csv'}")
    print("=" * 70)


if __name__ == "__main__":
    main()
