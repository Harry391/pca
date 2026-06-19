from __future__ import annotations

import argparse
import csv
import re
import shutil
from collections import defaultdict
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Copy a previous split, replacing rows whose source was removed or marked with trailing ()."
    )
    parser.add_argument("--previous-manifest", type=Path, required=True)
    parser.add_argument("--candidate-manifest", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--test-per-class", type=int, default=2)
    parser.add_argument("--train-per-class", type=int, default=8)
    parser.add_argument("--clean", action="store_true")
    return parser.parse_args()


def is_ignored_marked(path: Path) -> bool:
    return re.search(r"\(\)\s*$", path.stem) is not None


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", newline="", encoding="utf-8-sig") as file:
        return list(csv.DictReader(file))


def write_csv(path: Path, rows: list[dict[str, str]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8-sig") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def source_available(row: dict[str, str]) -> bool:
    source = Path(row["source_path"])
    return source.exists() and not is_ignored_marked(source)


def source_key(row: dict[str, str]) -> tuple[str, str]:
    return row["label"], Path(row["source_path"]).name


def copy_row_image(source_image: Path, output_dir: Path, split: str, label: str, name: str) -> Path:
    target = unique_target_path(output_dir / split / label / name)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_image, target)
    return target


def unique_target_path(target: Path) -> Path:
    if not target.exists():
        return target

    stem = target.stem
    suffix = target.suffix
    for index in range(1, 1000):
        candidate = target.with_name(f"{stem}__copy{index:02d}{suffix}")
        if not candidate.exists():
            return candidate
    raise RuntimeError(f"could not create unique target path for {target}")


def choose_replacement(
    label: str,
    candidates_by_label: dict[str, list[dict[str, str]]],
    used_keys: set[tuple[str, str]],
) -> dict[str, str] | None:
    candidates = candidates_by_label.get(label, [])
    scored = []
    for row in candidates:
        key = source_key(row)
        if key in used_keys:
            continue
        status_penalty = 0 if row.get("status") == "aligned" else 10
        dup_penalty = 0 if row.get("is_duplicate") == "0" else 2
        scored.append((status_penalty + dup_penalty, Path(row["source_path"]).name, row))
    scored.sort(key=lambda item: (item[0], item[1]))
    if not scored:
        return None
    return scored[0][2]


def main() -> None:
    args = parse_args()
    previous_manifest = args.previous_manifest.resolve()
    candidate_manifest = args.candidate_manifest.resolve()
    output_dir = args.output_dir.resolve()

    if args.clean and output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    previous_rows = read_csv(previous_manifest)
    candidate_rows = read_csv(candidate_manifest)
    candidates_by_label: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in candidate_rows:
        candidates_by_label[row["label"]].append(row)

    used_keys: set[tuple[str, str]] = set()
    output_rows: list[dict[str, str]] = []
    replaced_rows: list[dict[str, str]] = []

    for row in previous_rows:
        row = dict(row)
        label = row["label"]
        split = row["split"]
        valid = source_available(row)

        if valid:
            source_image = Path(row["split_path"])
            if not source_image.exists():
                source_image = Path(row["all_path"])
            output_name = Path(row["split_path"]).name
            used_keys.add(source_key(row))
            replacement = None
        else:
            replacement = choose_replacement(label, candidates_by_label, used_keys)
            if replacement is None:
                replacement = candidates_by_label[label][0]
            source_image = Path(replacement.get("split_path") or replacement["all_path"])
            if not source_image.exists():
                source_image = Path(replacement["all_path"])
            output_name = Path(source_image).name
            used_keys.add(source_key(replacement))
            replaced_rows.append(
                {
                    "label": label,
                    "split": split,
                    "old_source_path": row["source_path"],
                    "new_source_path": replacement["source_path"],
                    "reason": "previous_source_missing_or_marked",
                }
            )

        split_path = copy_row_image(source_image, output_dir, split, label, output_name)
        all_path = copy_row_image(source_image, output_dir, "all", label, output_name)

        if replacement is not None:
            row["source_path"] = replacement["source_path"]
            row["status"] = replacement.get("status", row.get("status", ""))
            row["is_duplicate"] = replacement.get("is_duplicate", row.get("is_duplicate", "0"))
            row["duplicate_from"] = replacement.get("duplicate_from", row.get("duplicate_from", ""))

        row["split_path"] = str(split_path)
        row["all_path"] = str(all_path)
        output_rows.append(row)

    fieldnames = [
        "label",
        "split",
        "source_path",
        "all_path",
        "split_path",
        "status",
        "is_duplicate",
        "duplicate_from",
    ]
    write_csv(output_dir / "tight_masked_split_manifest.csv", output_rows, fieldnames)
    write_csv(output_dir / "replacement_log.csv", replaced_rows, ["label", "split", "old_source_path", "new_source_path", "reason"])

    labels = sorted({row["label"] for row in output_rows})
    train_count = sum(1 for row in output_rows if row["split"] == "train")
    test_count = sum(1 for row in output_rows if row["split"] == "test")
    test_fallback = sum(1 for row in output_rows if row["split"] == "test" and row.get("status") != "aligned")
    test_dup = sum(1 for row in output_rows if row["split"] == "test" and row.get("is_duplicate") == "1")
    print("=" * 70)
    print(f"previous: {previous_manifest}")
    print(f"candidates: {candidate_manifest}")
    print(f"output: {output_dir}")
    print(f"classes: {len(labels)}")
    print(f"train/test: {train_count}/{test_count}")
    print(f"replacements: {len(replaced_rows)}")
    print(f"test fallback: {test_fallback}")
    print(f"test duplicates: {test_dup}")
    print(f"manifest: {output_dir / 'tight_masked_split_manifest.csv'}")
    print(f"replacement log: {output_dir / 'replacement_log.csv'}")
    print("=" * 70)


if __name__ == "__main__":
    main()
