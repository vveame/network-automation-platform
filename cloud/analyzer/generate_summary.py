from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def build_validation_summary(
    reports: list[dict[str, Any]],
    build_label: str,
    prometheus_metrics: dict[str, Any] | None = None,
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

    return {
        "project": "network-automation-platform",
        "source": "jenkins_ansible_validation_and_prometheus_metrics",
        "analysis_time_utc": datetime.now(timezone.utc).isoformat(),
        "build_label": build_label,
        "global_status": "failed" if failed_reports else "passed",
        "total_reports": len(reports),
        "passed_reports": len([r for r in reports if r["status"] == "passed"]),
        "warning_reports": warning_reports,
        "failed_reports": failed_reports,
        "reports": reports,
        "prometheus_metrics": prometheus_metrics or {
            "available": False,
            "reason": "metrics_not_loaded",
        },
    }


def write_outputs(
    output_dir: Path,
    summary: dict[str, Any],
    decision: dict[str, Any],
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    (output_dir / "summary.json").write_text(
        json.dumps(summary, indent=2),
        encoding="utf-8",
    )

    (output_dir / "decision.json").write_text(
        json.dumps(decision, indent=2),
        encoding="utf-8",
    )

    failed_reports = "\n".join(summary["failed_reports"]) if summary["failed_reports"] else "None"
    warning_reports = "\n".join(summary["warning_reports"]) if summary["warning_reports"] else "None"
    reasons = "\n".join(decision.get("detection_reasons", [])) if decision.get("detection_reasons") else "None"

    metrics = summary.get("prometheus_metrics", {})
    metrics_available = metrics.get("available", False)

    if metrics_available:
        metrics_block = f"""Prometheus metrics:
Targets up: {metrics.get("targets_up", 0)}/{metrics.get("targets_total", 0)}
Targets down: {metrics.get("targets_down", 0)}

Blackbox probes success: {metrics.get("blackbox_probes_success", 0)}/{metrics.get("blackbox_probes_total", 0)}
Blackbox probes failed: {metrics.get("blackbox_probes_failed", 0)}

SNMP targets up: {metrics.get("snmp_targets_up", 0)}/{metrics.get("snmp_targets_total", 0)}
SNMP targets down: {metrics.get("snmp_targets_down", 0)}
SNMP interfaces total: {metrics.get("snmp_interfaces_total", 0)}
SNMP interfaces up: {metrics.get("snmp_interfaces_up", 0)}
SNMP interfaces down: {metrics.get("snmp_interfaces_down", 0)}
SNMP unexpected interface down: {metrics.get("snmp_interfaces_unexpected_down_count", 0)}
SNMP interfaces with errors: {metrics.get("snmp_interfaces_with_errors_count", 0)}
SNMP sysUpTime: {metrics.get("snmp_sys_uptime", 0)}

Memory used: {metrics.get("memory_used_percent", 0)}%
Disk used: {metrics.get("disk_used_percent", 0)}%
Snapshot: {metrics.get("snapshot_time_utc", "unknown")}
"""
    else:
        metrics_block = f"""Prometheus metrics:
Unavailable
Reason: {metrics.get("reason", "unknown")}
"""

    report = f"""PFE Cloud Analyzer Report

Build: {summary["build_label"]}
Analysis time: {summary["analysis_time_utc"]}

Global validation status: {summary["global_status"]}
Anomaly status: {decision["anomaly_status"]}
Risk score: {decision["risk_score"]}/100
Validation risk score: {decision.get("validation_risk_score", 0)}/100
Metrics risk score: {decision.get("metrics_risk_score", 0)}/100
Severity: {decision["severity"]}
Recommended action: {decision["recommended_action"]}

Total reports: {summary["total_reports"]}
Passed reports: {summary["passed_reports"]}
Warning reports: {len(summary["warning_reports"])}
Failed reports: {len(summary["failed_reports"])}

Failed report files:
{failed_reports}

Warning report files:
{warning_reports}

Detection reasons:
{reasons}

{metrics_block}
"""

    (output_dir / "analysis-report.txt").write_text(report, encoding="utf-8")
