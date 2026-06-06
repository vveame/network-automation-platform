from __future__ import annotations

from typing import Any


def calculate_validation_risk(reports: list[dict[str, Any]]) -> tuple[int, list[str]]:
    score = 0
    reasons = []

    failed_categories = {
        report["category"]
        for report in reports
        if report["status"] in ["failed", "empty"]
    }

    critical_count = sum(len(report["critical_matches"]) for report in reports)
    warning_count = sum(len(report["warning_matches"]) for report in reports)

    if "security" in failed_categories:
        score += 30
        reasons.append("security_validation_failed")

    if "end_to_end" in failed_categories:
        score += 25
        reasons.append("end_to_end_validation_failed")

    if "oob_management" in failed_categories:
        score += 25
        reasons.append("oob_management_validation_failed")

    if "routing_frr" in failed_categories:
        score += 20
        reasons.append("routing_frr_validation_failed")

    if "switching_ovs" in failed_categories:
        score += 15
        reasons.append("switching_ovs_validation_failed")

    if "dmz" in failed_categories:
        score += 20
        reasons.append("dmz_validation_failed")

    if critical_count:
        score += min(critical_count * 5, 40)
        reasons.append(f"critical_patterns_detected:{critical_count}")

    if warning_count:
        score += min(warning_count * 2, 20)
        reasons.append(f"warning_patterns_detected:{warning_count}")

    return min(score, 100), reasons


def calculate_metrics_risk(metrics: dict[str, Any] | None) -> tuple[int, list[str]]:
    if not metrics or not metrics.get("available"):
        return 0, ["prometheus_metrics_unavailable"]

    score = 0
    reasons = []

    targets_down = int(metrics.get("targets_down", 0))
    blackbox_failed = int(metrics.get("blackbox_probes_failed", 0))
    memory_used = float(metrics.get("memory_used_percent", 0))
    disk_used = float(metrics.get("disk_used_percent", 0))

    if targets_down > 0:
        score += min(targets_down * 25, 50)
        reasons.append(f"prometheus_targets_down:{targets_down}")

    if blackbox_failed > 0:
        score += min(blackbox_failed * 20, 60)
        reasons.append(f"blackbox_probes_failed:{blackbox_failed}")

    if memory_used >= 95:
        score += 35
        reasons.append(f"memory_critical:{memory_used}%")
    elif memory_used >= 85:
        score += 20
        reasons.append(f"memory_high:{memory_used}%")
    elif memory_used >= 75:
        score += 10
        reasons.append(f"memory_warning:{memory_used}%")

    if disk_used >= 95:
        score += 35
        reasons.append(f"disk_critical:{disk_used}%")
    elif disk_used >= 85:
        score += 20
        reasons.append(f"disk_high:{disk_used}%")
    elif disk_used >= 75:
        score += 10
        reasons.append(f"disk_warning:{disk_used}%")

    return min(score, 100), reasons


def severity_from_score(score: int) -> tuple[str, str, str]:
    if score >= 75:
        return "critical", "anomalous", "trigger_manual_review_and_remediation"

    if score >= 50:
        return "high", "anomalous", "review_failed_reports_and_prepare_remediation"

    if score >= 25:
        return "medium", "anomalous", "review_warnings_metrics_and_monitor_next_build"

    return "low", "normal", "no_action"


def build_anomaly_decision(
    reports: list[dict[str, Any]],
    build_label: str,
    metrics: dict[str, Any] | None = None,
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

    validation_risk, validation_reasons = calculate_validation_risk(reports)
    metrics_risk, metrics_reasons = calculate_metrics_risk(metrics)

    total_score = min(validation_risk + metrics_risk, 100)
    severity, anomaly_status, recommended_action = severity_from_score(total_score)

    return {
        "project": "network-automation-platform",
        "build_label": build_label,
        "anomaly_status": anomaly_status,
        "risk_score": total_score,
        "severity": severity,
        "recommended_action": recommended_action,
        "failed_reports": failed_reports,
        "warning_reports": warning_reports,
        "validation_risk_score": validation_risk,
        "metrics_risk_score": metrics_risk,
        "detection_reasons": validation_reasons + metrics_reasons,
        "prometheus_metrics": metrics or {
            "available": False,
            "reason": "metrics_not_loaded",
        },
    }
