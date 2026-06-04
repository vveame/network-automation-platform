from __future__ import annotations

from typing import Any


def calculate_risk_score(reports: list[dict[str, Any]]) -> tuple[int, str, str]:
    score = 0

    failed_categories = {
        report["category"]
        for report in reports
        if report["status"] in ["failed", "empty"]
    }

    critical_count = sum(len(report["critical_matches"]) for report in reports)
    warning_count = sum(len(report["warning_matches"]) for report in reports)

    if "security" in failed_categories:
        score += 30
    if "end_to_end" in failed_categories:
        score += 25
    if "oob_management" in failed_categories:
        score += 25
    if "routing_frr" in failed_categories:
        score += 20
    if "switching_ovs" in failed_categories:
        score += 15
    if "dmz" in failed_categories:
        score += 20

    score += min(critical_count * 5, 40)
    score += min(warning_count * 2, 20)
    score = min(score, 100)

    if score >= 75:
        severity = "critical"
        action = "trigger_manual_review_and_remediation"
    elif score >= 50:
        severity = "high"
        action = "review_failed_reports_and_prepare_remediation"
    elif score >= 25:
        severity = "medium"
        action = "review_warnings_and_monitor_next_build"
    else:
        severity = "low"
        action = "no_action"

    return score, severity, action


def build_anomaly_decision(
    reports: list[dict[str, Any]],
    build_label: str,
) -> dict[str, Any]:
    failed_reports = [
        report["file"]
        for report in reports
        if report["status"] in ["failed", "empty"]
    ]

    warning_reports = [
        report["file"]
        for report in reports
        if report["status"] == "warning"
    ]

    risk_score, severity, recommended_action = calculate_risk_score(reports)

    return {
        "project": "network-automation-platform",
        "build_label": build_label,
        "anomaly_status": "anomalous" if risk_score >= 25 else "normal",
        "risk_score": risk_score,
        "severity": severity,
        "recommended_action": recommended_action,
        "failed_reports": failed_reports,
        "warning_reports": warning_reports,
    }
