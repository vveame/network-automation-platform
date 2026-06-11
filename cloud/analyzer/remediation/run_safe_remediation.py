#!/usr/bin/env python3
"""
Run predefined safe remediation actions from final-decision.json.

Design:
  - Plan mode is the default.
  - Apply mode requires --confirm-apply.
  - ML-only anomalies are advisory.
  - Infrastructure-changing actions are allowed only when final-decision.json
    says remediation_allowed=true, unless the user explicitly chooses a
    non-modifying diagnostic action.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


SAFE_NON_MODIFYING_ACTIONS = {
    "no_action",
    "collect_host_diagnostics",
    "collect_network_diagnostics",
    "refresh_monitoring_snapshot",
    "run_validation_gate",
}

INFRASTRUCTURE_MODIFYING_ACTIONS = {
    "restart_dmz_web",
    "restart_dmz_dns",
    "restart_dmz_services",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Plan or apply allowlisted remediation actions."
    )
    parser.add_argument(
        "--decision",
        default="cloud/analyzer/outputs/final-decision.json",
        help="Path to merged final-decision.json.",
    )
    parser.add_argument(
        "--catalog",
        default="cloud/analyzer/remediation/safe_actions.json",
        help="Path to safe remediation action catalog.",
    )
    parser.add_argument(
        "--output-dir",
        default="cloud/analyzer/outputs/remediation",
        help="Directory where remediation reports are written.",
    )
    parser.add_argument(
        "--mode",
        choices=["plan", "apply"],
        default="plan",
        help="plan = show/write what would happen. apply = execute.",
    )
    parser.add_argument(
        "--confirm-apply",
        action="store_true",
        help="Required for apply mode.",
    )
    parser.add_argument(
        "--action",
        default="auto",
        help="Action to run. Use auto to choose from final-decision.json.",
    )
    parser.add_argument(
        "--gns3-host",
        default=os.environ.get("GNS3_HOST", ""),
        help="GNS3 host IP/hostname. Required for GNS3 Docker restart actions.",
    )
    parser.add_argument(
        "--gns3-user",
        default=os.environ.get("GNS3_USER", "gns3"),
        help="SSH user for GNS3 host. Default: gns3",
    )
    parser.add_argument(
        "--gns3-key",
        default=os.environ.get("GNS3_KEY", ""),
        help="Optional SSH private key path for GNS3 host.",
    )
    parser.add_argument(
        "--ssh-timeout",
        type=int,
        default=10,
        help="SSH connection timeout in seconds.",
    )
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(f"JSON file not found: {path}")

    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def run_command(
    command: list[str],
    report_lines: list[str],
    cwd: str | None = None,
    check: bool = False,
) -> int:
    report_lines.append("")
    report_lines.append(f"$ {' '.join(command)}")

    completed = subprocess.run(
        command,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )

    report_lines.append(completed.stdout.rstrip())

    if check and completed.returncode != 0:
        raise RuntimeError(
            f"Command failed with exit code {completed.returncode}: {' '.join(command)}"
        )

    return completed.returncode


def extract_decision_context(decision: dict[str, Any]) -> dict[str, Any]:
    merged = decision.get("merged_decision", {})
    rule = decision.get("rule_engine", {})
    ml = decision.get("ml_engine", {})

    detection_reasons = rule.get("detection_reasons", [])
    if isinstance(detection_reasons, str):
        detection_reasons = [detection_reasons]
    if not isinstance(detection_reasons, list):
        detection_reasons = []

    return {
        "classification": merged.get("classification", "unknown"),
        "final_status": merged.get("final_status", "unknown"),
        "final_severity": merged.get("final_severity", "unknown"),
        "final_risk_score": int(merged.get("final_risk_score", 0)),
        "recommended_action": merged.get("recommended_action", "no_action"),
        "remediation_allowed": bool(merged.get("remediation_allowed", False)),
        "remediation_mode": merged.get("remediation_mode", "unknown"),
        "decision_reason": merged.get("decision_reason", ""),
        "rule_anomalous": bool(merged.get("rule_anomalous", False)),
        "ml_anomalous": bool(merged.get("ml_anomalous", False)),
        "ml_suspicious": bool(merged.get("ml_suspicious", False)),
        "rule_detection_reasons": detection_reasons,
        "rule_risk_score": int(rule.get("risk_score", 0)),
        "ml_risk_score": int(ml.get("risk_score", 0)),
    }


def choose_auto_action(ctx: dict[str, Any]) -> str:
    if ctx["final_status"] == "normal" or ctx["final_risk_score"] < 25:
        return "no_action"

    reasons = " ".join(ctx.get("rule_detection_reasons", [])).lower()

    if not ctx.get("remediation_allowed", False):
        if ctx.get("ml_anomalous") or ctx.get("ml_suspicious"):
            return "collect_host_diagnostics"
        return "collect_network_diagnostics"

    if "blackbox_probes_failed" in reasons or "dmz_validation_failed" in reasons:
        return "restart_dmz_services"

    if "snmp_targets_down" in reasons:
        return "collect_network_diagnostics"

    if "snmp_interfaces_unexpected_down" in reasons:
        return "run_validation_gate"

    if "snmp_interface_error_rate_detected" in reasons:
        return "collect_network_diagnostics"

    if "snmp_interface_discard_rate_detected" in reasons:
        return "collect_network_diagnostics"

    if (
        "cpu_" in reasons
        or "memory_" in reasons
        or "disk_" in reasons
        or "load1_high" in reasons
        or "readonly_filesystems" in reasons
    ):
        return "collect_host_diagnostics"

    if "routing_frr_validation_failed" in reasons or "switching_ovs_validation_failed" in reasons:
        return "run_validation_gate"

    return "collect_network_diagnostics"


def build_ssh_command(args: argparse.Namespace, remote_script: str) -> list[str]:
    if not args.gns3_host:
        raise ValueError(
            "GNS3 host is required for this action. Use --gns3-host or set GNS3_HOST."
        )

    command = [
        "ssh",
        "-o",
        "BatchMode=yes",
        "-o",
        "StrictHostKeyChecking=no",
        "-o",
        f"ConnectTimeout={args.ssh_timeout}",
    ]

    if args.gns3_key:
        command.extend(["-i", args.gns3_key])

    command.append(f"{args.gns3_user}@{args.gns3_host}")
    command.append(remote_script)

    return command


def remote_restart_script(pattern: str) -> str:
    return f"""
set -e
echo "[INFO] Looking for container pattern: {pattern}"
CONTAINER="$(docker ps -a --format '{{{{.Names}}}}' | grep -Ei '{pattern}' | head -n 1 || true)"
if [ -z "$CONTAINER" ]; then
  echo "[ERROR] No matching container found for pattern: {pattern}"
  echo "[INFO] Available containers:"
  docker ps -a --format 'table {{{{.Names}}}}\\t{{{{.Status}}}}\\t{{{{.Image}}}}'
  exit 2
fi
echo "[INFO] Restarting container: $CONTAINER"
docker restart "$CONTAINER"
echo "[OK] Restart completed for: $CONTAINER"
docker ps -a --filter "name=$CONTAINER" --format 'table {{{{.Names}}}}\\t{{{{.Status}}}}\\t{{{{.Image}}}}'
""".strip()


def execute_action(
    action: str,
    args: argparse.Namespace,
    ctx: dict[str, Any],
    report_lines: list[str],
) -> dict[str, Any]:
    result: dict[str, Any] = {
        "action": action,
        "mode": args.mode,
        "executed": False,
        "success": False,
        "exit_codes": [],
    }

    if action == "no_action":
        report_lines.append("[INFO] No remediation action required.")
        result["success"] = True
        return result

    if args.mode == "plan":
        report_lines.append(f"[PLAN] Selected action: {action}")
        report_lines.append("[PLAN] No commands executed because mode=plan.")
        result["success"] = True
        return result

    if args.mode == "apply" and not args.confirm_apply:
        raise PermissionError("Apply mode requires --confirm-apply.")

    if action in INFRASTRUCTURE_MODIFYING_ACTIONS and not ctx["remediation_allowed"]:
        raise PermissionError(
            f"Action {action} modifies infrastructure but final-decision.json "
            "does not allow remediation."
        )

    result["executed"] = True

    if action == "collect_host_diagnostics":
        commands = [
            ["hostnamectl"],
            ["uptime"],
            ["free", "-m"],
            ["df", "-h"],
            ["ip", "-br", "addr"],
            ["systemctl", "--no-pager", "--full", "status", "prometheus"],
            ["systemctl", "--no-pager", "--full", "status", "grafana-server"],
        ]

        for command in commands:
            code = run_command(command, report_lines)
            result["exit_codes"].append(code)

        result["success"] = all(code == 0 for code in result["exit_codes"])
        return result

    if action == "collect_network_diagnostics":
        commands = [
            ["ip", "-br", "addr"],
            ["ip", "route"],
            ["ping", "-c", "2", "-W", "2", "10.200.0.11"],
            ["ping", "-c", "2", "-W", "2", "10.200.0.30"],
            ["curl", "-fsS", "http://localhost:9090/-/ready"],
            ["bash", "-lc", "curl -s 'http://localhost:9090/api/v1/query?query=up' | head -c 2000"],
        ]

        for command in commands:
            code = run_command(command, report_lines)
            result["exit_codes"].append(code)

        result["success"] = all(code == 0 for code in result["exit_codes"])
        return result

    if action == "refresh_monitoring_snapshot":
        code = run_command(
            ["bash", "./cloud/scripts/export-cloud-prometheus-snapshot.sh"],
            report_lines,
        )
        result["exit_codes"].append(code)
        result["success"] = code == 0
        return result

    if action == "run_validation_gate":
        commands = [
            ["ansible-inventory", "--graph"],
            ["ansible-playbook", "--syntax-check", "playbooks/site.yml"],
            ["ansible-playbook", "playbooks/site.yml"],
        ]

        for command in commands:
            code = run_command(command, report_lines, cwd="ansible")
            result["exit_codes"].append(code)

        result["success"] = all(code == 0 for code in result["exit_codes"])
        return result

    if action == "restart_dmz_web":
        command = build_ssh_command(args, remote_restart_script("Web-Server-Nginx|web.*nginx|nginx"))
        code = run_command(command, report_lines)
        result["exit_codes"].append(code)
        result["success"] = code == 0
        return result

    if action == "restart_dmz_dns":
        command = build_ssh_command(args, remote_restart_script("DNS-1|dns"))
        code = run_command(command, report_lines)
        result["exit_codes"].append(code)
        result["success"] = code == 0
        return result

    if action == "restart_dmz_services":
        commands = [
            build_ssh_command(args, remote_restart_script("Web-Server-Nginx|web.*nginx|nginx")),
            build_ssh_command(args, remote_restart_script("DNS-1|dns")),
        ]

        for command in commands:
            code = run_command(command, report_lines)
            result["exit_codes"].append(code)

        result["success"] = all(code == 0 for code in result["exit_codes"])
        return result

    raise ValueError(f"Unsupported remediation action: {action}")


def main() -> int:
    args = parse_args()

    decision_path = Path(args.decision)
    catalog_path = Path(args.catalog)
    output_dir = Path(args.output_dir)

    output_dir.mkdir(parents=True, exist_ok=True)

    decision = load_json(decision_path)
    catalog = load_json(catalog_path)
    ctx = extract_decision_context(decision)

    available_actions = catalog.get("actions", {})
    requested_action = args.action

    if requested_action == "auto":
        selected_action = choose_auto_action(ctx)
    else:
        selected_action = requested_action

    if selected_action not in available_actions:
        raise ValueError(
            f"Unknown action: {selected_action}. "
            f"Available actions: {', '.join(sorted(available_actions.keys()))}"
        )

    if selected_action in INFRASTRUCTURE_MODIFYING_ACTIONS and args.mode == "apply":
        if not args.confirm_apply:
            raise PermissionError("Infrastructure-changing remediation requires --confirm-apply.")

    report_lines: list[str] = [
        "PFE Safe Remediation Report",
        "===========================",
        "",
        f"Generated at UTC: {datetime.now(timezone.utc).isoformat()}",
        f"Mode: {args.mode}",
        f"Requested action: {requested_action}",
        f"Selected action: {selected_action}",
        "",
        "Decision Context",
        "----------------",
        f"Classification: {ctx['classification']}",
        f"Final status: {ctx['final_status']}",
        f"Final severity: {ctx['final_severity']}",
        f"Final risk score: {ctx['final_risk_score']}/100",
        f"Remediation allowed: {ctx['remediation_allowed']}",
        f"Remediation mode: {ctx['remediation_mode']}",
        f"Decision reason: {ctx['decision_reason']}",
        "",
        "Rule Detection Reasons",
        "----------------------",
    ]

    if ctx["rule_detection_reasons"]:
        report_lines.extend([f"- {reason}" for reason in ctx["rule_detection_reasons"]])
    else:
        report_lines.append("- none")

    report_lines.extend(
        [
            "",
            "Action Description",
            "------------------",
            available_actions[selected_action].get("description", ""),
            "",
            "Execution",
            "---------",
        ]
    )

    action_result = execute_action(selected_action, args, ctx, report_lines)

    output = {
        "project": "network-automation-platform",
        "engine": "safe_remediation_runner",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "mode": args.mode,
        "requested_action": requested_action,
        "selected_action": selected_action,
        "action_description": available_actions[selected_action].get("description", ""),
        "action_type": available_actions[selected_action].get("type", "unknown"),
        "modifies_infrastructure": available_actions[selected_action].get(
            "modifies_infrastructure", False
        ),
        "decision_context": ctx,
        "result": action_result,
        "safety_policy": catalog.get("safety_policy", {}),
    }

    plan_path = output_dir / "remediation-plan.json"
    report_path = output_dir / "remediation-report.txt"

    plan_path.write_text(
        json.dumps(output, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    report_path.write_text(
        "\n".join(report_lines) + "\n",
        encoding="utf-8",
    )

    print("[OK] Safe remediation workflow completed")
    print(f"[INFO] Mode: {args.mode}")
    print(f"[INFO] Selected action: {selected_action}")
    print(f"[INFO] Executed: {action_result['executed']}")
    print(f"[INFO] Success: {action_result['success']}")
    print(f"[INFO] Plan JSON: {plan_path}")
    print(f"[INFO] Report: {report_path}")

    return 0 if action_result["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())