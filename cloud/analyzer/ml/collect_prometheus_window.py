#!/usr/bin/env python3
"""
Collect historical Prometheus metrics for ML anomaly detection.

This script queries Prometheus /api/v1/query_range for each feature defined in
features.json and stores the raw responses as JSON files.

It does not train a model. It only prepares the raw time-window data.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


def utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Collect Prometheus query_range data for ML features."
    )
    parser.add_argument(
        "--prometheus-url",
        default="http://localhost:9090",
        help="Prometheus base URL. Default: http://localhost:9090",
    )
    parser.add_argument(
        "--features-file",
        default="cloud/analyzer/ml/features.json",
        help="Path to feature definition JSON.",
    )
    parser.add_argument(
        "--output-dir",
        default="cloud/analyzer/ml/data/raw/latest",
        help="Directory where raw query_range JSON files will be written.",
    )
    parser.add_argument(
        "--duration-minutes",
        type=int,
        default=60,
        help="How many minutes of history to collect. Default: 60.",
    )
    parser.add_argument(
        "--step",
        default="60s",
        help="Prometheus query_range step. Default: 60s.",
    )
    parser.add_argument(
        "--timeout-seconds",
        type=int,
        default=20,
        help="HTTP timeout per Prometheus query. Default: 20.",
    )
    return parser.parse_args()


def load_features(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    features = data.get("features", [])
    if not isinstance(features, list) or not features:
        raise ValueError(f"No features found in {path}")

    for item in features:
        if "name" not in item or "query" not in item:
            raise ValueError(f"Invalid feature entry: {item}")

    return features


def query_range(
    prometheus_url: str,
    query: str,
    start: dt.datetime,
    end: dt.datetime,
    step: str,
    timeout_seconds: int,
) -> dict[str, Any]:
    base = prometheus_url.rstrip("/") + "/api/v1/query_range"

    params = {
        "query": query,
        "start": start.isoformat(),
        "end": end.isoformat(),
        "step": step,
    }

    url = base + "?" + urllib.parse.urlencode(params)

    request = urllib.request.Request(
        url,
        headers={"Accept": "application/json"},
        method="GET",
    )

    with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
        body = response.read().decode("utf-8")
        payload = json.loads(body)

    if payload.get("status") != "success":
        raise RuntimeError(f"Prometheus query failed: {payload}")

    return payload


def safe_filename(name: str) -> str:
    return name.replace("/", "_").replace(" ", "_")


def main() -> int:
    args = parse_args()

    features_file = Path(args.features_file)
    output_dir = Path(args.output_dir)

    start = utc_now() - dt.timedelta(minutes=args.duration_minutes)
    end = utc_now()

    features = load_features(features_file)

    output_dir.mkdir(parents=True, exist_ok=True)

    manifest: dict[str, Any] = {
        "created_at": utc_now().isoformat(),
        "prometheus_url": args.prometheus_url,
        "features_file": str(features_file),
        "duration_minutes": args.duration_minutes,
        "step": args.step,
        "start": start.isoformat(),
        "end": end.isoformat(),
        "feature_count": len(features),
        "features": [],
    }

    print(f"[INFO] Collecting {len(features)} Prometheus feature windows")
    print(f"[INFO] Prometheus: {args.prometheus_url}")
    print(f"[INFO] Start: {start.isoformat()}")
    print(f"[INFO] End:   {end.isoformat()}")
    print(f"[INFO] Step:  {args.step}")

    failures = 0

    for feature in features:
        name = feature["name"]
        query = feature["query"]
        file_name = f"{safe_filename(name)}.json"
        output_path = output_dir / file_name

        print(f"[INFO] Querying feature: {name}")

        try:
            payload = query_range(
                prometheus_url=args.prometheus_url,
                query=query,
                start=start,
                end=end,
                step=args.step,
                timeout_seconds=args.timeout_seconds,
            )

            with output_path.open("w", encoding="utf-8") as f:
                json.dump(payload, f, indent=2, sort_keys=True)

            result_count = len(payload.get("data", {}).get("result", []))

            manifest["features"].append(
                {
                    "name": name,
                    "query": query,
                    "file": file_name,
                    "status": "success",
                    "series_count": result_count,
                }
            )

        except Exception as exc:
            failures += 1
            print(f"[ERROR] Feature query failed: {name}: {exc}", file=sys.stderr)

            manifest["features"].append(
                {
                    "name": name,
                    "query": query,
                    "file": file_name,
                    "status": "failed",
                    "error": str(exc),
                }
            )

        time.sleep(0.2)

    manifest_path = output_dir / "manifest.json"
    with manifest_path.open("w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, sort_keys=True)

    print(f"[INFO] Raw Prometheus window written to: {output_dir}")
    print(f"[INFO] Manifest: {manifest_path}")

    if failures:
        print(f"[WARN] Completed with {failures} failed feature queries")
        return 1

    print("[OK] Prometheus ML data collection completed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())