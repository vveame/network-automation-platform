from __future__ import annotations

from typing import Any


ERROR_RATE_THRESHOLD = 0.01
DISCARD_RATE_THRESHOLD = 0.01


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


def _count_interfaces_above_rate(
    interfaces: list[dict[str, Any]],
    rate_key: str,
    threshold: float,
) -> int:
    count = 0

    for interface in interfaces:
        try:
            value = float(interface.get(rate_key, 0))
        except (ValueError, TypeError):
            value = 0

        if value >= threshold:
            count += 1

    return count


def calculate_metrics_risk(metrics: dict[str, Any] | None) -> tuple[int, list[str]]:
    if not metrics or not metrics.get("available"):
        return 0, ["prometheus_metrics_unavailable"]

    score = 0
    reasons = []

    targets_down = int(metrics.get("targets_down", 0))
    blackbox_failed = int(metrics.get("blackbox_probes_failed", 0))
    blackbox_max_duration = float(metrics.get("blackbox_max_duration_seconds", 0))

    memory_used = float(metrics.get("memory_used_percent", 0))
    disk_used = float(metrics.get("disk_used_percent", 0))
    max_cpu = float(metrics.get("max_cpu_usage_percent", 0))
    max_load1 = float(metrics.get("max_load1", 0))
    readonly_count = int(metrics.get("filesystem_readonly_count", 0))

    snmp_targets_down = int(metrics.get("snmp_targets_down", 0))
    snmp_unexpected_down = int(metrics.get("snmp_interfaces_unexpected_down_count", 0))

    # Cumulative counters are kept for visibility, but not directly scored.
    # For anomaly scoring, use current rates instead.
    snmp_error_rate_interfaces = _count_interfaces_above_rate(
        metrics.get("snmp_interfaces_with_error_rate", []),
        "total_error_rate",
        ERROR_RATE_THRESHOLD,
    )

    snmp_discard_rate_interfaces = _count_interfaces_above_rate(
        metrics.get("snmp_interfaces_with_discard_rate", []),
        "total_discard_rate",
        DISCARD_RATE_THRESHOLD,
    )

    if targets_down > 0:
        score += min(targets_down * 25, 50)
        reasons.append(f"prometheus_targets_down:{targets_down}")

    if blackbox_failed > 0:
        score += min(blackbox_failed * 20, 60)
        reasons.append(f"blackbox_probes_failed:{blackbox_failed}")

    if blackbox_max_duration >= 5:
        score += 20
        reasons.append(f"blackbox_probe_latency_critical:{blackbox_max_duration}s")
    elif blackbox_max_duration >= 2:
        score += 10
        reasons.append(f"blackbox_probe_latency_warning:{blackbox_max_duration}s")

    if snmp_targets_down > 0:
        score += min(snmp_targets_down * 25, 50)
        reasons.append(f"snmp_targets_down:{snmp_targets_down}")

    if snmp_unexpected_down > 0:
        score += min(snmp_unexpected_down * 15, 45)
        reasons.append(f"snmp_interfaces_unexpected_down:{snmp_unexpected_down}")

    if snmp_error_rate_interfaces > 0:
        score += min(snmp_error_rate_interfaces * 12, 36)
        reasons.append(f"snmp_interface_error_rate_detected:{snmp_error_rate_interfaces}")

    if snmp_discard_rate_interfaces > 0:
        score += min(snmp_discard_rate_interfaces * 8, 24)
        reasons.append(f"snmp_interface_discard_rate_detected:{snmp_discard_rate_interfaces}")

    if max_cpu >= 95:
        score += 35
        reasons.append(f"cpu_critical:{max_cpu}%")
    elif max_cpu >= 85:
        score += 20
        reasons.append(f"cpu_high:{max_cpu}%")
    elif max_cpu >= 75:
        score += 10
        reasons.append(f"cpu_warning:{max_cpu}%")

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

    if max_load1 >= 8:
        score += 15
        reasons.append(f"load1_high:{max_load1}")

    if readonly_count > 0:
        score += 35
        reasons.append(f"readonly_filesystems:{readonly_count}")

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
