#!/usr/bin/env python3
"""
Predict metric-based anomalies using a trained Isolation Forest model.

Input:
  cloud/analyzer/ml/data/features/latest_features.csv
  cloud/analyzer/ml/models/isolation_forest.joblib
  cloud/analyzer/ml/models/training_metadata.json

Output:
  cloud/analyzer/ml/outputs/ml-decision.json
  cloud/analyzer/ml/outputs/ml-scores.csv
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Predict anomalies using trained Isolation Forest model."
    )
    parser.add_argument(
        "--input-csv",
        default="cloud/analyzer/ml/data/features/latest_features.csv",
        help="Input feature CSV to score.",
    )
    parser.add_argument(
        "--model-path",
        default="cloud/analyzer/ml/models/isolation_forest.joblib",
        help="Trained Isolation Forest model path.",
    )
    parser.add_argument(
        "--metadata-path",
        default="cloud/analyzer/ml/models/training_metadata.json",
        help="Training metadata path.",
    )
    parser.add_argument(
        "--output-dir",
        default="cloud/analyzer/ml/outputs",
        help="Output directory.",
    )
    parser.add_argument(
        "--top-features",
        type=int,
        default=8,
        help="Number of most unusual features to include in JSON output.",
    )
    return parser.parse_args()


def load_metadata(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(f"Training metadata not found: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def load_dataset(path: Path, feature_columns: list[str]) -> tuple[pd.DataFrame, list[str]]:
    if not path.exists():
        raise FileNotFoundError(f"Feature CSV not found: {path}")

    df = pd.read_csv(path)

    if "timestamp" not in df.columns:
        raise ValueError("Dataset must contain timestamp column")

    timestamps = df["timestamp"].astype(str).tolist()

    feature_df = df.drop(columns=["timestamp"])

    for column in feature_columns:
        if column not in feature_df.columns:
            feature_df[column] = np.nan

    feature_df = feature_df[feature_columns]
    feature_df = feature_df.apply(pd.to_numeric, errors="coerce")
    feature_df = feature_df.replace([np.inf, -np.inf], np.nan)

    return feature_df, timestamps


def score_to_risk(decision_score: float, metadata: dict[str, Any]) -> int:
    """
    Convert Isolation Forest decision score into a 0-100 human-friendly risk score.

    In scikit-learn Isolation Forest:
      - positive decision_function values are inliers
      - negative values are outliers
      - lower is more abnormal
    """
    positive_ref = float(metadata.get("positive_decision_score_median", 0.05)) or 0.05
    negative_ref = abs(float(metadata.get("negative_decision_score_min", -0.05))) or 0.05

    if decision_score >= 0:
        # Normal side: closer to zero means suspicious, far positive means healthy.
        closeness = 1.0 - min(decision_score / positive_ref, 1.0)
        risk = 50.0 * max(closeness, 0.0)
    else:
        # Outlier side: more negative means more anomalous.
        abnormality = min(abs(decision_score) / negative_ref, 1.0)
        risk = 50.0 + (50.0 * abnormality)

    return int(round(max(0.0, min(risk, 100.0))))


def status_from_risk(risk_score: int, prediction: int) -> tuple[str, str, str]:
    if prediction == -1 or risk_score >= 70:
        return "anomalous", "high", "review_and_prepare_remediation"
    if risk_score >= 50:
        return "suspicious", "medium", "monitor_and_compare_with_rule_engine"
    if risk_score >= 30:
        return "weak_signal", "low", "monitor_next_window"
    return "normal", "low", "no_action"


def top_unusual_features(
    latest_row: pd.Series,
    metadata: dict[str, Any],
    limit: int,
) -> list[dict[str, Any]]:
    stats = metadata.get("feature_statistics", {})
    items: list[dict[str, Any]] = []

    for feature, value in latest_row.items():
        feature_stats = stats.get(feature, {})
        median = float(feature_stats.get("median", 0.0))
        std = float(feature_stats.get("std", 0.0))

        try:
            numeric_value = float(value)
        except (ValueError, TypeError):
            numeric_value = 0.0

        if std <= 0:
            z_score = 0.0 if numeric_value == median else 999.0
        else:
            z_score = abs((numeric_value - median) / std)

        items.append(
            {
                "feature": feature,
                "value": numeric_value,
                "training_median": median,
                "training_std": std,
                "absolute_z_score": float(z_score),
            }
        )

    items.sort(key=lambda x: x["absolute_z_score"], reverse=True)
    return items[:limit]


def main() -> int:
    args = parse_args()

    input_csv = Path(args.input_csv)
    model_path = Path(args.model_path)
    metadata_path = Path(args.metadata_path)
    output_dir = Path(args.output_dir)

    if not model_path.exists():
        raise FileNotFoundError(f"Model not found: {model_path}")

    output_dir.mkdir(parents=True, exist_ok=True)

    model = joblib.load(model_path)
    metadata = load_metadata(metadata_path)

    feature_columns = metadata.get("feature_columns", [])
    if not feature_columns:
        raise ValueError("No feature_columns found in training metadata")

    feature_df, timestamps = load_dataset(input_csv, feature_columns)

    predictions = model.predict(feature_df)
    decision_scores = model.decision_function(feature_df)
    sample_scores = model.score_samples(feature_df)

    risk_scores = [
        score_to_risk(float(score), metadata)
        for score in decision_scores
    ]

    scores_df = pd.DataFrame(
        {
            "timestamp": timestamps,
            "prediction": predictions,
            "decision_score": decision_scores,
            "sample_score": sample_scores,
            "ml_risk_score": risk_scores,
            "is_outlier": predictions == -1,
        }
    )

    scores_path = output_dir / "ml-scores.csv"
    scores_df.to_csv(scores_path, index=False)

    latest_index = len(feature_df) - 1
    latest_timestamp = timestamps[latest_index]
    latest_prediction = int(predictions[latest_index])
    latest_decision_score = float(decision_scores[latest_index])
    latest_sample_score = float(sample_scores[latest_index])
    latest_risk_score = int(risk_scores[latest_index])

    ml_status, severity, recommended_action = status_from_risk(
        risk_score=latest_risk_score,
        prediction=latest_prediction,
    )

    latest_row = feature_df.iloc[latest_index]
    unusual_features = top_unusual_features(
        latest_row=latest_row,
        metadata=metadata,
        limit=args.top_features,
    )

    outlier_count = int((predictions == -1).sum())
    total_rows = int(len(predictions))

    decision: dict[str, Any] = {
        "project": "network-automation-platform",
        "engine": "ml_isolation_forest",
        "model_type": "IsolationForest",
        "analysis_time_utc": datetime.now(timezone.utc).isoformat(),
        "input_csv": str(input_csv),
        "model_path": str(model_path),
        "latest_timestamp": latest_timestamp,
        "ml_available": True,
        "ml_status": ml_status,
        "severity": severity,
        "recommended_action": recommended_action,
        "ml_risk_score": latest_risk_score,
        "latest_prediction": latest_prediction,
        "latest_decision_score": latest_decision_score,
        "latest_sample_score": latest_sample_score,
        "scored_rows": total_rows,
        "outlier_rows": outlier_count,
        "outlier_ratio": round(outlier_count / total_rows, 4) if total_rows else 0,
        "top_unusual_features": unusual_features,
        "notes": [
            "Isolation Forest output is advisory.",
            "Rule-based analyzer remains the deterministic remediation safety layer.",
            "Final remediation should merge ML result with rule-based decision.",
        ],
    }

    decision_path = output_dir / "ml-decision.json"
    decision_path.write_text(
        json.dumps(decision, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    print("[OK] ML anomaly prediction completed")
    print(f"[INFO] Scores: {scores_path}")
    print(f"[INFO] Decision: {decision_path}")
    print(f"[INFO] Latest timestamp: {latest_timestamp}")
    print(f"[INFO] ML status: {ml_status}")
    print(f"[INFO] ML risk score: {latest_risk_score}/100")
    print(f"[INFO] Latest prediction: {latest_prediction}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())