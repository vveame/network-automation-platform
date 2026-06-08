#!/usr/bin/env python3
"""
Train an Isolation Forest model for PFE metric-based anomaly detection.

Input:
  cloud/analyzer/ml/data/features/latest_features.csv

Output:
  cloud/analyzer/ml/models/isolation_forest.joblib
  cloud/analyzer/ml/models/feature_columns.json
  cloud/analyzer/ml/models/training_metadata.json
  cloud/analyzer/ml/outputs/training_scores.csv

The model is trained on historical Prometheus feature rows.
The first training dataset should represent a healthy/normal baseline.
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.impute import SimpleImputer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Train Isolation Forest model from Prometheus ML feature dataset."
    )
    parser.add_argument(
        "--input-csv",
        default="cloud/analyzer/ml/data/features/latest_features.csv",
        help="Input feature CSV.",
    )
    parser.add_argument(
        "--model-dir",
        default="cloud/analyzer/ml/models",
        help="Directory where trained model and metadata are saved.",
    )
    parser.add_argument(
        "--output-dir",
        default="cloud/analyzer/ml/outputs",
        help="Directory where training reports are saved.",
    )
    parser.add_argument(
        "--contamination",
        type=float,
        default=0.05,
        help="Expected anomaly ratio in training data. Default: 0.05.",
    )
    parser.add_argument(
        "--n-estimators",
        type=int,
        default=200,
        help="Number of Isolation Forest trees. Default: 200.",
    )
    parser.add_argument(
        "--random-state",
        type=int,
        default=42,
        help="Random seed. Default: 42.",
    )
    return parser.parse_args()


def load_dataset(path: Path) -> tuple[pd.DataFrame, list[str], list[str]]:
    if not path.exists():
        raise FileNotFoundError(f"Feature CSV not found: {path}")

    df = pd.read_csv(path)

    if "timestamp" not in df.columns:
        raise ValueError("Dataset must contain a timestamp column")

    timestamps = df["timestamp"].astype(str).tolist()

    feature_df = df.drop(columns=["timestamp"])

    # Convert all features to numeric. Invalid values become NaN and will be imputed.
    feature_df = feature_df.apply(pd.to_numeric, errors="coerce")

    feature_columns = list(feature_df.columns)

    if not feature_columns:
        raise ValueError("No feature columns found in dataset")

    # Replace inf values before training.
    feature_df = feature_df.replace([np.inf, -np.inf], np.nan)

    return feature_df, feature_columns, timestamps


def build_feature_statistics(feature_df: pd.DataFrame) -> dict[str, dict[str, float]]:
    stats: dict[str, dict[str, float]] = {}

    for column in feature_df.columns:
        series = pd.to_numeric(feature_df[column], errors="coerce")
        clean = series.replace([np.inf, -np.inf], np.nan).dropna()

        if clean.empty:
            stats[column] = {
                "mean": 0.0,
                "median": 0.0,
                "std": 0.0,
                "min": 0.0,
                "max": 0.0,
            }
            continue

        stats[column] = {
            "mean": float(clean.mean()),
            "median": float(clean.median()),
            "std": float(clean.std(ddof=0)),
            "min": float(clean.min()),
            "max": float(clean.max()),
        }

    return stats


def main() -> int:
    args = parse_args()

    input_csv = Path(args.input_csv)
    model_dir = Path(args.model_dir)
    output_dir = Path(args.output_dir)

    model_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)

    feature_df, feature_columns, timestamps = load_dataset(input_csv)

    row_count = len(feature_df)
    feature_count = len(feature_columns)

    if row_count < 30:
        print(
            f"[WARN] Dataset has only {row_count} rows. "
            "This is enough for a smoke test, but collect more data for a real baseline."
        )

    print(f"[INFO] Training rows: {row_count}")
    print(f"[INFO] Feature count: {feature_count}")
    print(f"[INFO] Contamination: {args.contamination}")

    pipeline = Pipeline(
        steps=[
            ("imputer", SimpleImputer(strategy="median")),
            ("scaler", StandardScaler()),
            (
                "model",
                IsolationForest(
                    n_estimators=args.n_estimators,
                    contamination=args.contamination,
                    random_state=args.random_state,
                    n_jobs=-1,
                ),
            ),
        ]
    )

    pipeline.fit(feature_df)

    predictions = pipeline.predict(feature_df)
    decision_scores = pipeline.decision_function(feature_df)
    sample_scores = pipeline.score_samples(feature_df)

    training_scores = pd.DataFrame(
        {
            "timestamp": timestamps,
            "prediction": predictions,
            "decision_score": decision_scores,
            "sample_score": sample_scores,
            "is_outlier": predictions == -1,
        }
    )

    training_scores_path = output_dir / "training_scores.csv"
    training_scores.to_csv(training_scores_path, index=False)

    outlier_count = int((predictions == -1).sum())
    inlier_count = int((predictions == 1).sum())

    feature_stats = build_feature_statistics(feature_df)

    positive_scores = [float(x) for x in decision_scores if x >= 0]
    negative_scores = [float(x) for x in decision_scores if x < 0]

    metadata: dict[str, Any] = {
        "project": "network-automation-platform",
        "model_type": "IsolationForest",
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "input_csv": str(input_csv),
        "row_count": row_count,
        "feature_count": feature_count,
        "feature_columns": feature_columns,
        "contamination": args.contamination,
        "n_estimators": args.n_estimators,
        "random_state": args.random_state,
        "training_outlier_count": outlier_count,
        "training_inlier_count": inlier_count,
        "decision_score_min": float(np.min(decision_scores)),
        "decision_score_max": float(np.max(decision_scores)),
        "decision_score_mean": float(np.mean(decision_scores)),
        "decision_score_median": float(np.median(decision_scores)),
        "positive_decision_score_median": float(np.median(positive_scores)) if positive_scores else 0.0,
        "negative_decision_score_min": float(np.min(negative_scores)) if negative_scores else float(np.min(decision_scores)),
        "feature_statistics": feature_stats,
        "notes": [
            "Isolation Forest is trained on Prometheus historical feature rows.",
            "Training data should represent mostly normal/healthy infrastructure behavior.",
            "Rule-based analyzer remains the deterministic safety layer.",
        ],
    }

    model_path = model_dir / "isolation_forest.joblib"
    columns_path = model_dir / "feature_columns.json"
    metadata_path = model_dir / "training_metadata.json"

    joblib.dump(pipeline, model_path)

    columns_path.write_text(
        json.dumps(feature_columns, indent=2),
        encoding="utf-8",
    )

    metadata_path.write_text(
        json.dumps(metadata, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    print("[OK] Isolation Forest training completed")
    print(f"[INFO] Model: {model_path}")
    print(f"[INFO] Feature columns: {columns_path}")
    print(f"[INFO] Metadata: {metadata_path}")
    print(f"[INFO] Training scores: {training_scores_path}")
    print(f"[INFO] Training inliers: {inlier_count}")
    print(f"[INFO] Training outliers: {outlier_count}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())