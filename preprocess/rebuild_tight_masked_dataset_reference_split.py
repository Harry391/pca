from __future__ import annotations

import argparse
import csv
import re
import shutil
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np

from rebuild_tight_masked_dataset import (
    force_exact_per_class,
    process_sources,
    split_rows,
    write_csv,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Rebuild tight-masked dataset while preserving a previous test split when possible."
    )
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--task-file", type=Path, required=True)
    parser.add_argument("--reference-manifest", type=Path, required=True)
    parser.add_argument("--width", type=int, default=92)
    parser.add_argument("--height", type=int, default=112)
    parser.add_argument("--per-class", type=int, default=10)
    parser.add_argument("--train-per-class", type=int, default=8)
    parser.add_argument("--test-per-class", type=int, default=2)
    parser.add_argument("--seed", type=int, default=20260621)
    parser.add_argument("--clean", action="store_true")
    return parser.parse_args()


def source_key(path_text: str) -> str:
    return Path(path_text).name


def read_reference_tests(path: Path) -> dict[str, list[str]]:
    tests: dict[str, list[str]] = defaultdict(list)
    with path.open("r", newline="", encoding="utf-8-sig") as file:
        for row in csv.DictReader(file):
            if row.get("split") == "test":
                tests[row["label"]].append(source_key(row["source_path"]))
    return tests


def exact_with_reference_tests(
    rows: list[dict[str, str]],
    output_dir: Path,
    per_class: int,
    seed: int,
    reference_tests: dict[str, list[str]],
) -> list[dict[str, str]]:
    rng = np.random.default_rng(seed)
    grouped: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        grouped[row["label"]].append(row)

    exact_rows: list[dict[str, str]] = []
    for label in sorted(grouped):
        label_rows = sorted(grouped[label], key=lambda row: (Path(row["source_path"]).name, row["all_path"]))
        reference_names = set(reference_tests.get(label, []))
        must_keep = [row for row in label_rows if source_key(row["source_path"]) in reference_names]
        rest = [row for row in label_rows if source_key(row["source_path"]) not in reference_names]

        if len(label_rows) >= per_class:
            rng.shuffle(rest)
            kept = must_keep + rest[: max(0, per_class - len(must_keep))]
            exact_rows.extend(dict(row) for row in kept[:per_class])
        else:
            exact_rows.extend(dict(row) for row in label_rows)
            duplicate_needed = per_class - len(label_rows)
            for duplicate_index in range(1, duplicate_needed + 1):
                source_row = label_rows[(duplicate_index - 1) % len(label_rows)]
                source_path = Path(source_row["all_path"])
                duplicate_path = output_dir / "all" / label / f"{Path(source_row['source_path']).stem}__dup{duplicate_index:02d}.jpg"
                shutil.copy2(source_path, duplicate_path)

                row = dict(source_row)
                row["all_path"] = str(duplicate_path)
                row["is_duplicate"] = "1"
                row["duplicate_from"] = source_row["all_path"]
                exact_rows.append(row)

    return exact_rows


def split_with_reference_tests(
    rows: list[dict[str, str]],
    output_dir: Path,
    train_per_class: int,
    test_per_class: int,
    seed: int,
    reference_tests: dict[str, list[str]],
) -> list[dict[str, str]]:
    rng = np.random.default_rng(seed)
    grouped: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        grouped[row["label"]].append(row)

    split_rows_out: list[dict[str, str]] = []
    for label in sorted(grouped):
        label_rows = list(grouped[label])
        selected = set()

        requested = Counter(reference_tests.get(label, []))
        for requested_name, requested_count in requested.items():
            candidates = [
                index
                for index, row in enumerate(label_rows)
                if index not in selected and source_key(row["source_path"]) == requested_name
            ]
            candidates = sorted(candidates, key=lambda index: label_rows[index]["is_duplicate"])
            for index in candidates[:requested_count]:
                selected.add(index)
                if len(selected) >= test_per_class:
                    break
            if len(selected) >= test_per_class:
                break

        if len(selected) < test_per_class:
            preferred = [
                index
                for index, row in enumerate(label_rows)
                if index not in selected and row["status"] == "aligned" and row["is_duplicate"] == "0"
            ]
            rng.shuffle(preferred)
            for index in preferred:
                selected.add(index)
                if len(selected) >= test_per_class:
                    break

        if len(selected) < test_per_class:
            fallback = [index for index in range(len(label_rows)) if index not in selected]
            rng.shuffle(fallback)
            for index in fallback:
                selected.add(index)
                if len(selected) >= test_per_class:
                    break

        for index, row in enumerate(label_rows):
            split_name = "test" if index in selected else "train"
            all_path = Path(row["all_path"])
            split_path = output_dir / split_name / label / all_path.name
            split_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(all_path, split_path)

            out_row = dict(row)
            out_row["split"] = split_name
            out_row["split_path"] = str(split_path)
            out_row["reference_test_requested"] = "1" if source_key(row["source_path"]) in reference_tests.get(label, []) else "0"
            split_rows_out.append(out_row)

    return split_rows_out


def main() -> None:
    args = parse_args()
    input_dir = args.input_dir.resolve()
    output_dir = args.output_dir.resolve()
    task_file = args.task_file.resolve()
    reference_manifest = args.reference_manifest.resolve()

    if args.clean and output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    reference_tests = read_reference_tests(reference_manifest)
    processed_rows, ignored_rows = process_sources(input_dir, output_dir, task_file, (args.width, args.height))
    exact_rows = exact_with_reference_tests(processed_rows, output_dir, args.per_class, args.seed, reference_tests)
    split_rows_out = split_with_reference_tests(
        exact_rows,
        output_dir,
        args.train_per_class,
        args.test_per_class,
        args.seed + 1,
        reference_tests,
    )

    manifest_fields = [
        "label",
        "split",
        "source_path",
        "all_path",
        "split_path",
        "status",
        "is_duplicate",
        "duplicate_from",
        "reference_test_requested",
    ]
    write_csv(output_dir / "tight_masked_split_manifest.csv", split_rows_out, manifest_fields)
    write_csv(output_dir / "ignored_images.csv", ignored_rows, ["source_path", "label", "reason"])

    labels = sorted({row["label"] for row in split_rows_out})
    train_count = sum(1 for row in split_rows_out if row["split"] == "train")
    test_count = sum(1 for row in split_rows_out if row["split"] == "test")
    duplicate_count = sum(1 for row in split_rows_out if row["is_duplicate"] == "1")
    test_duplicate_count = sum(1 for row in split_rows_out if row["split"] == "test" and row["is_duplicate"] == "1")
    test_fallback_count = sum(1 for row in split_rows_out if row["split"] == "test" and row["status"] != "aligned")
    preserved_reference_tests = sum(1 for row in split_rows_out if row["split"] == "test" and row["reference_test_requested"] == "1")

    print("=" * 70)
    print(f"input: {input_dir}")
    print(f"output: {output_dir}")
    print(f"reference: {reference_manifest}")
    print(f"classes: {len(labels)}")
    print(f"ignored: {len(ignored_rows)}")
    print(f"train/test: {train_count}/{test_count}")
    print(f"duplicates: {duplicate_count}")
    print(f"test duplicates: {test_duplicate_count}")
    print(f"test fallback: {test_fallback_count}")
    print(f"preserved reference tests: {preserved_reference_tests}/{len(labels) * args.test_per_class}")
    print(f"manifest: {output_dir / 'tight_masked_split_manifest.csv'}")
    print("=" * 70)


if __name__ == "__main__":
    main()
