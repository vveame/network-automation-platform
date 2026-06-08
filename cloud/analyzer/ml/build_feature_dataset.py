#!/usr/bin/env python3
"""
Build an ML feature dataset from Prometheus query_range JSON files.

Input:
  cloud/analyzer/ml/data/raw/latest/*.json

Output:
  cloud/analyzer/ml/data/features/latest_features.csv

Each row represents one timestamp. Each column represents one feature.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build CSV feature dataset from Prometheus query_range outputs."
    )
    parser.add_argument(
        "--raw-dir",
        default="cloud/analyzer/ml/data/raw/latest",
        help="Directory containing raw Prometheus query_range JSON files.",
    )
    parser.add_argument(
        "--features-file",
        default="cloud/analyzer/ml/features.json",
        help="Path to feature definition JSON.",
    )
    parser.add_argument(
        "--output-csv",
        default="cloud/analyzer/ml/data/features/latest_features.csv",
        help="Output CSV file.",
    )
    parser.add_argument(
        "--fill-missing",
        type=float,
        default=0.0,
        help="Value used when a feature is missing at a timestamp. Default: 0.0",
    )
    return parser.parse_args()


def load_features(path: Path) -> list[str]:
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    features = data.get("features", [])
    return [item["name"] for item in features]


def timestamp_to_iso(timestamp_value: str | float | int) -> str:
    ts = float(timestamp_value)
    return dt.datetime.fromtimestamp(ts, tz=dt.timezone.utc).isoformat()


def load_feature_values(path: Path) -> dict[str, float]:
    """
    Return timestamp_iso -> value for one feature.

    Most feature PromQL queries are aggregate expressions and should return
    one matrix series. If multiple series are returned, we sum values per
    timestamp to keep a single numeric feature.
    """
    with path.open("r", encoding="utf-8") as f:
        payload = json.load(f)

    result = payload.get("data", {}).get("result", [])
    values_by_timestamp: dict[str, float] = {}

    for series in result:
        for item in series.get("values", []):
            if not isinstance(item, list) or len(item) != 2:
                continue

            timestamp_iso = timestamp_to_iso(item[0])

            try:
                value = float(item[1])
            except (TypeError, ValueError):
                value = 0.0

            values_by_timestamp[timestamp_iso] = (
                values_by_timestamp.get(timestamp_iso, 0.0) + value
            )

    return values_by_timestamp


def main() -> int:
    args = parse_args()

    raw_dir = Path(args.raw_dir)
    features_file = Path(args.features_file)
    output_csv = Path(args.output_csv)

    feature_names = load_features(features_file)

    if not raw_dir.exists():
        raise FileNotFoundError(f"Raw directory not found: {raw_dir}")

    all_timestamps: set[str] = set()
    feature_data: dict[str, dict[str, float]] = {}

    for feature_name in feature_names:
        feature_path = raw_dir / f"{feature_name}.json"

        if not feature_path.exists():
            print(f"[WARN] Missing feature file: {feature_path}")
            feature_data[feature_name] = {}
            continue

        values = load_feature_values(feature_path)
        feature_data[feature_name] = values
        all_timestamps.update(values.keys())

        print(f"[INFO] Loaded {feature_name}: {len(values)} points")

    sorted_timestamps = sorted(all_timestamps)

    output_csv.parent.mkdir(parents=True, exist_ok=True)

    with output_csv.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["timestamp", *feature_names])

        for timestamp in sorted_timestamps:
            row = [timestamp]
            for feature_name in feature_names:
                row.append(feature_data[feature_name].get(timestamp, args.fill_missing))
            writer.writerow(row)

    print(f"[OK] Feature dataset written to: {output_csv}")
    print(f"[INFO] Rows: {len(sorted_timestamps)}")
    print(f"[INFO] Features: {len(feature_names)}")

    if not sorted_timestamps:
        print("[WARN] Dataset is empty. Check Prometheus queries and time window.")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())