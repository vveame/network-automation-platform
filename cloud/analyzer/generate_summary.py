from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def build_validation_summary(
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

    return {
        "project": "network-automation-platform",
        "source": "jenkins_ansible_validation_artifacts",
        "analysis_time_utc": datetime.now(timezone.utc).isoformat(),
        "build_label": build_label,
        "global_status": "failed" if failed_reports else "passed",
        "total_reports": len(reports),
        "passed_reports": len([r for r in reports if r["status"] == "passed"]),
        "warning_reports": warning_reports,
        "failed_reports": failed_reports,
        "reports": reports,
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

    report = f"""PFE Cloud Analyzer Report

Build: {summary["build_label"]}
Analysis time: {summary["analysis_time_utc"]}

Global validation status: {summary["global_status"]}
Anomaly status: {decision["anomaly_status"]}
Risk score: {decision["risk_score"]}/100
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
"""

    (output_dir / "analysis-report.txt").write_text(report, encoding="utf-8")
