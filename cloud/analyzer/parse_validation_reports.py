from __future__ import annotations

from pathlib import Path
import re
from typing import Any


CRITICAL_PATTERNS = [
    "FAILED!",
    "fatal:",
    "UNREACHABLE!",
    "ERROR!",
    "Traceback",
    "Permission denied",
    "No route to host",
    "Connection refused",
    "timed out",
    "timeout",
    "unreachable",
]

WARNING_PATTERNS = [
    "WARNING",
    "WARN",
    "changed=",
    "skipped=",
    "retry",
    "missing",
    "denied",
]


EXPECTED_SECURITY_BLOCK_SECTIONS = [
    "OOB -> Web SSH TCP/22",
    "OOB -> DNS HTTP TCP/80",
    "WEB SSH BLOCKED",
    "DNS HTTP BLOCKED",
    "DNS SSH BLOCKED",
]


def detect_category(filename: str) -> str:
    name = filename.lower()

    if "security" in name:
        return "security"
    if "end-to-end" in name or "validation-summary" in name:
        return "end_to_end"
    if "oob" in name or "management" in name:
        return "oob_management"
    if "dmz" in name:
        return "dmz"
    if "frr" in name or "router" in name:
        return "routing_frr"
    if "ovs" in name:
        return "switching_ovs"
    if "inventory" in name:
        return "inventory"
    if "artifact" in name:
        return "reporting"

    return "general"


def is_expected_security_block(content: str) -> bool:
    """
    Security validation intentionally contains blocked traffic tests.

    In those sections, rc=1 with 'timed out' is expected and means the firewall /
    ACL policy is working. This must not be classified as an anomaly.
    """
    for section in EXPECTED_SECURITY_BLOCK_SECTIONS:
        if section not in content:
            return False

    expected_block_indicators = [
        "WEB SSH BLOCKED",
        "DNS HTTP BLOCKED",
        "DNS SSH BLOCKED",
        "rc=1",
        "timed out",
    ]

    return all(indicator in content for indicator in expected_block_indicators)


def filter_expected_security_matches(
    filename: str,
    content: str,
    critical_matches: list[str],
    warning_matches: list[str],
) -> tuple[list[str], list[str]]:
    category = detect_category(filename)

    if category != "security":
        return critical_matches, warning_matches

    if not is_expected_security_block(content):
        return critical_matches, warning_matches

    # In security-validation.txt, timeout is expected for explicit BLOCKED tests.
    filtered_critical = [
        match for match in critical_matches
        if match.lower() not in ["timed out", "timeout"]
    ]

    # 'denied' can be normal security wording, so avoid treating it as warning here.
    filtered_warning = [
        match for match in warning_matches
        if match.lower() != "denied"
    ]

    return filtered_critical, filtered_warning



def parse_jenkins_html_summary(filename: str, content: str) -> str | None:
    """Interpret the structured Jenkins summary without substring false positives."""
    if filename != "jenkins-html-summary.txt":
        return None

    overall_match = re.search(
        r"(?im)^\s*Overall status:\s*([A-Za-z_]+)\s*$",
        content,
    )
    failed_match = re.search(
        r"(?im)^\s*Failed:\s*(\d+)\s*$",
        content,
    )
    missing_match = re.search(
        r"(?im)^\s*Missing/empty:\s*(\d+)\s*$",
        content,
    )

    # Fail safely if the expected structured fields are absent.
    if not (overall_match and failed_match and missing_match):
        return "failed"

    overall_status = overall_match.group(1).upper()
    failed_count = int(failed_match.group(1))
    missing_count = int(missing_match.group(1))

    if (
        overall_status == "PASSED"
        and failed_count == 0
        and missing_count == 0
    ):
        return "passed"

    return "failed"

def analyze_report(path: Path) -> dict[str, Any]:
    content = path.read_text(errors="replace")
    lines = content.splitlines()

    summary_status = parse_jenkins_html_summary(path.name, content)
    if summary_status is not None:
        return {
            "file": path.name,
            "category": detect_category(path.name),
            "status": summary_status,
            "line_count": len(lines),
            "size_bytes": path.stat().st_size,
            "critical_matches": (
                ["jenkins_summary_failed"]
                if summary_status == "failed"
                else []
            ),
            "warning_matches": [],
        }

    lower_content = content.lower()

    critical_matches = [
        pattern for pattern in CRITICAL_PATTERNS
        if pattern.lower() in lower_content
    ]

    warning_matches = [
        pattern for pattern in WARNING_PATTERNS
        if pattern.lower() in lower_content
    ]

    critical_matches, warning_matches = filter_expected_security_matches(
        path.name,
        content,
        critical_matches,
        warning_matches,
    )

    if critical_matches:
        status = "failed"
    elif warning_matches:
        status = "warning"
    elif content.strip():
        status = "passed"
    else:
        status = "empty"

    return {
        "file": path.name,
        "category": detect_category(path.name),
        "status": status,
        "line_count": len(lines),
        "size_bytes": path.stat().st_size,
        "critical_matches": critical_matches,
        "warning_matches": warning_matches,
    }


def parse_validation_reports(input_dir: Path) -> list[dict[str, Any]]:
    excluded_report_files = {
        "validation-gate-exit-code.txt",
    }

    reports = sorted(
        report
        for report in input_dir.glob("*.txt")
        if report.name not in excluded_report_files
    )

    if not reports:
        raise FileNotFoundError(f"No .txt validation reports found in: {input_dir}")

    return [analyze_report(report) for report in reports]
