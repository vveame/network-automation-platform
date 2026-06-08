#!/usr/bin/env python3
"""
Merge rule-based analyzer decision with ML Isolation Forest decision.

Inputs:
  cloud/analyzer/outputs/decision.json
  cloud/analyzer/ml/outputs/ml-decision.json

Outputs:
  cloud/analyzer/outputs/final-decision.json
  cloud/analyzer/outputs/final-decision-report.txt

Design:
  - Rule-based analyzer remains the deterministic safety layer.
  - ML Isolation Forest is an advisory anomaly signal.
  - Automated remediation is allowed only when the rule-based analyzer also
    supports the anomaly decision.
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Merge rule-based analyzer decision with ML anomaly decision."
    )
    parser.add_argument(
        "--rule-decision",
        default="cloud/analyzer/outputs/decision.json",
        help="Path to rule-based analyzer decision.json.",
    )
    parser.add_argument(
        "--ml-decision",
        default="cloud/analyzer/ml/outputs/ml-decision.json",
        help="Path to ML analyzer ml-decision.json.",
    )
    parser.add_argument(
        "--output-dir",
        default="cloud/analyzer/outputs",
        help="Directory where merged final decision files are written.",
    )
    return parser.parse_args()


def load_json(path: Path, required: bool = True) -> dict[str, Any]:
    if not path.exists():
        if required:
            raise FileNotFoundError(f"Required JSON file not found: {path}")
        return {}

    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def as_int(value: Any, default: int = 0) -> int:
    try:
        return int(round(float(value)))
    except (TypeError, ValueError):
        return default


def normalize_status(value: Any) -> str:
    if value is None:
        return "unknown"
    return str(value).strip().lower()


def normalize_action(value: Any) -> str:
    if value is None:
        return "no_action"
    action = str(value).strip()
    return action if action else "no_action"


def status_is_anomalous(status: str) -> bool:
    return status in {
        "anomalous",
        "critical",
        "high",
        "failed",
        "failure",
        "unhealthy",
    }


def ml_is_anomalous(status: str, risk_score: int, prediction: int | None) -> bool:
    if prediction == -1:
        return True
    if status in {"anomalous", "critical", "high"}:
        return True
    return risk_score >= 70


def ml_is_suspicious(status: str, risk_score: int) -> bool:
    if status in {"suspicious", "weak_signal"}:
        return True
    return 30 <= risk_score < 70


def severity_from_score(score: int) -> str:
    if score >= 75:
        return "critical"
    if score >= 50:
        return "high"
    if score >= 25:
        return "medium"
    return "low"


def final_status_from_score(score: int) -> str:
    return "anomalous" if score >= 25 else "normal"


def bounded_score(score: int) -> int:
    return max(0, min(100, int(score)))


def extract_rule_decision(rule: dict[str, Any]) -> dict[str, Any]:
    risk_score = as_int(
        rule.get("risk_score", rule.get("global_risk_score", rule.get("final_risk_score", 0)))
    )

    status = normalize_status(rule.get("anomaly_status", rule.get("status", "unknown")))
    severity = normalize_status(rule.get("severity", severity_from_score(risk_score)))
    action = normalize_action(rule.get("recommended_action", "no_action"))

    reasons = rule.get("detection_reasons", rule.get("reasons", []))
    if reasons is None:
        reasons = []
    if isinstance(reasons, str):
        reasons = [reasons]
    if not isinstance(reasons, list):
        reasons = [str(reasons)]

    return {
        "available": bool(rule),
        "risk_score": risk_score,
        "anomaly_status": status,
        "severity": severity,
        "recommended_action": action,
        "detection_reasons": reasons,
        "raw": rule,
    }


def extract_ml_decision(ml: dict[str, Any]) -> dict[str, Any]:
    risk_score = as_int(ml.get("ml_risk_score", 0))
    status = normalize_status(ml.get("ml_status", "unknown"))
    severity = normalize_status(ml.get("severity", severity_from_score(risk_score)))
    action = normalize_action(ml.get("recommended_action", "no_action"))

    prediction_value = ml.get("latest_prediction")
    prediction: int | None
    try:
        prediction = int(prediction_value)
    except (TypeError, ValueError):
        prediction = None

    top_features = ml.get("top_unusual_features", [])
    if not isinstance(top_features, list):
        top_features = []

    return {
        "available": bool(ml.get("ml_available", bool(ml))),
        "risk_score": risk_score,
        "ml_status": status,
        "severity": severity,
        "recommended_action": action,
        "latest_prediction": prediction,
        "latest_decision_score": ml.get("latest_decision_score"),
        "latest_sample_score": ml.get("latest_sample_score"),
        "latest_timestamp": ml.get("latest_timestamp"),
        "outlier_ratio": ml.get("outlier_ratio"),
        "outlier_rows": ml.get("outlier_rows"),
        "scored_rows": ml.get("scored_rows"),
        "top_unusual_features": top_features,
        "raw": ml,
    }


def choose_final_decision(rule: dict[str, Any], ml: dict[str, Any]) -> dict[str, Any]:
    rule_anomalous = status_is_anomalous(rule["anomaly_status"]) or rule["risk_score"] >= 25
    ml_anomalous = ml_is_anomalous(
        status=ml["ml_status"],
        risk_score=ml["risk_score"],
        prediction=ml["latest_prediction"],
    )
    ml_suspicious = ml_is_suspicious(
        status=ml["ml_status"],
        risk_score=ml["risk_score"],
    )

    base_score = max(rule["risk_score"], ml["risk_score"])
    confidence = "low"
    classification = "normal"
    decision_reason = "Both rule-based analyzer and ML engine report normal behavior."

    if rule_anomalous and ml_anomalous:
        final_score = bounded_score(base_score + 10)
        confidence = "high"
        classification = "confirmed_anomaly"
        decision_reason = (
            "Rule-based analyzer and ML engine both report anomalous behavior."
        )
    elif rule_anomalous and not ml_anomalous:
        final_score = bounded_score(max(base_score, rule["risk_score"]))
        confidence = "medium"
        classification = "rule_based_anomaly"
        decision_reason = (
            "Rule-based analyzer reports an explainable infrastructure anomaly, "
            "while ML does not consider the latest metrics statistically anomalous."
        )
    elif not rule_anomalous and ml_anomalous:
        final_score = bounded_score(max(base_score, 50))
        confidence = "medium"
        classification = "ml_only_anomaly"
        decision_reason = (
            "ML reports anomalous behavior, but rule-based analyzer does not confirm "
            "a deterministic failure. Human review is required before remediation."
        )
    elif not rule_anomalous and ml_suspicious:
        final_score = bounded_score(max(base_score, 30))
        confidence = "low"
        classification = "ml_suspicious_signal"
        decision_reason = (
            "ML reports a weak or suspicious anomaly signal, but the rule-based "
            "analyzer is normal."
        )
    else:
        final_score = bounded_score(base_score)
        confidence = "high"
        classification = "normal"
        decision_reason = (
            "Both rule-based analyzer and ML engine report normal behavior."
        )

    final_status = final_status_from_score(final_score)
    final_severity = severity_from_score(final_score)

    rule_action = rule["recommended_action"]
    ml_action = ml["recommended_action"]

    if rule_anomalous and rule_action != "no_action":
        recommended_action = rule_action
        remediation_allowed = True
        remediation_mode = "controlled_rule_based_remediation"
    elif classification in {"ml_only_anomaly", "ml_suspicious_signal"}:
        recommended_action = "review_ml_signal"
        remediation_allowed = False
        remediation_mode = "human_review_required"
    elif rule_anomalous:
        recommended_action = "review_rule_based_anomaly"
        remediation_allowed = False
        remediation_mode = "human_review_required"
    elif ml_action != "no_action" and classification != "normal":
        recommended_action = ml_action
        remediation_allowed = False
        remediation_mode = "human_review_required"
    else:
        recommended_action = "no_action"
        remediation_allowed = False
        remediation_mode = "no_remediation_needed"

    return {
        "classification": classification,
        "final_status": final_status,
        "final_severity": final_severity,
        "final_risk_score": final_score,
        "confidence": confidence,
        "recommended_action": recommended_action,
        "remediation_allowed": remediation_allowed,
        "remediation_mode": remediation_mode,
        "decision_reason": decision_reason,
        "rule_anomalous": rule_anomalous,
        "ml_anomalous": ml_anomalous,
        "ml_suspicious": ml_suspicious,
    }


def build_report(final: dict[str, Any]) -> str:
    rule = final["rule_engine"]
    ml = final["ml_engine"]
    merged = final["merged_decision"]

    lines = [
        "PFE Final Anomaly Decision Report",
        "=================================",
        "",
        f"Generated at UTC: {final['generated_at_utc']}",
        "",
        "Final Decision",
        "--------------",
        f"Classification: {merged['classification']}",
        f"Status: {merged['final_status']}",
        f"Severity: {merged['final_severity']}",
        f"Risk score: {merged['final_risk_score']}/100",
        f"Confidence: {merged['confidence']}",
        f"Recommended action: {merged['recommended_action']}",
        f"Remediation allowed: {merged['remediation_allowed']}",
        f"Remediation mode: {merged['remediation_mode']}",
        "",
        "Decision Reason",
        "---------------",
        merged["decision_reason"],
        "",
        "Rule-Based Analyzer",
        "-------------------",
        f"Available: {rule['available']}",
        f"Status: {rule['anomaly_status']}",
        f"Severity: {rule['severity']}",
        f"Risk score: {rule['risk_score']}/100",
        f"Recommended action: {rule['recommended_action']}",
        "",
        "Rule Detection Reasons:",
    ]

    if rule["detection_reasons"]:
        lines.extend([f"- {reason}" for reason in rule["detection_reasons"]])
    else:
        lines.append("- none")

    lines.extend(
        [
            "",
            "ML Isolation Forest",
            "-------------------",
            f"Available: {ml['available']}",
            f"Status: {ml['ml_status']}",
            f"Severity: {ml['severity']}",
            f"Risk score: {ml['risk_score']}/100",
            f"Latest prediction: {ml['latest_prediction']}",
            f"Latest decision score: {ml['latest_decision_score']}",
            f"Outlier rows: {ml['outlier_rows']}",
            f"Outlier ratio: {ml['outlier_ratio']}",
            "",
            "Top unusual ML features:",
        ]
    )

    top_features = ml.get("top_unusual_features", [])
    if top_features:
        for item in top_features[:8]:
            feature = item.get("feature")
            value = item.get("value")
            z_score = item.get("absolute_z_score")
            lines.append(f"- {feature}: value={value}, z_score={z_score}")
    else:
        lines.append("- none")

    lines.extend(
        [
            "",
            "Safety Rule",
            "-----------",
            "ML alone is advisory. Automated remediation is allowed only when the",
            "rule-based analyzer also supports an explainable anomaly decision.",
            "",
        ]
    )

    return "\n".join(lines)


def main() -> int:
    args = parse_args()

    rule_decision_path = Path(args.rule_decision)
    ml_decision_path = Path(args.ml_decision)
    output_dir = Path(args.output_dir)

    output_dir.mkdir(parents=True, exist_ok=True)

    rule_raw = load_json(rule_decision_path, required=True)
    ml_raw = load_json(ml_decision_path, required=True)

    rule = extract_rule_decision(rule_raw)
    ml = extract_ml_decision(ml_raw)
    merged = choose_final_decision(rule, ml)

    final: dict[str, Any] = {
        "project": "network-automation-platform",
        "engine": "hybrid_rule_ml_decision_merger",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "inputs": {
            "rule_decision": str(rule_decision_path),
            "ml_decision": str(ml_decision_path),
        },
        "merged_decision": merged,
        "rule_engine": {
            key: value for key, value in rule.items() if key != "raw"
        },
        "ml_engine": {
            key: value for key, value in ml.items() if key != "raw"
        },
        "safety_policy": {
            "ml_is_advisory": True,
            "automated_remediation_requires_rule_confirmation": True,
            "reason": (
                "The rule-based analyzer remains the deterministic safety layer. "
                "ML-only anomalies require human review."
            ),
        },
    }

    final_json_path = output_dir / "final-decision.json"
    report_path = output_dir / "final-decision-report.txt"

    final_json_path.write_text(
        json.dumps(final, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    report_path.write_text(
        build_report(final),
        encoding="utf-8",
    )

    print("[OK] Hybrid rule + ML decision merge completed")
    print(f"[INFO] Final decision: {final_json_path}")
    print(f"[INFO] Final report: {report_path}")
    print(f"[INFO] Classification: {merged['classification']}")
    print(f"[INFO] Final status: {merged['final_status']}")
    print(f"[INFO] Final risk score: {merged['final_risk_score']}/100")
    print(f"[INFO] Recommended action: {merged['recommended_action']}")
    print(f"[INFO] Remediation allowed: {merged['remediation_allowed']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())