#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


CURRENT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CURRENT_DIR))

from anomaly_rules import build_anomaly_decision
from generate_summary import build_validation_summary, write_outputs
from parse_prometheus_metrics import parse_prometheus_metrics
from parse_validation_reports import parse_validation_reports


def run_command(command: list[str]) -> None:
    print(f"[INFO] Running: {' '.join(command)}")
    result = subprocess.run(command, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(command)}")


def download_s3_prefix(
    bucket: str,
    prefix: str,
    destination: Path,
    aws_profile: str | None,
    aws_region: str,
) -> None:
    s3_uri = f"s3://{bucket}/{prefix.strip('/')}/"

    command = ["aws", "s3", "sync", s3_uri, str(destination), "--region", aws_region]

    if aws_profile:
        command.extend(["--profile", aws_profile])

    run_command(command)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Analyze PFE Jenkins/Ansible validation artifacts and optional Prometheus metrics."
    )

    parser.add_argument(
        "--input-dir",
        default="ansible/outputs",
        help="Local validation artifact directory.",
    )

    parser.add_argument(
        "--metrics-dir",
        default="monitoring/outputs/latest",
        help="Optional Prometheus metrics snapshot directory.",
    )

    parser.add_argument(
        "--output-dir",
        default="cloud/analyzer/outputs",
        help="Analyzer output directory.",
    )

    parser.add_argument(
        "--build-label",
        default=None,
        help="Build label used in summary and decision outputs.",
    )

    parser.add_argument(
        "--s3-bucket",
        default=None,
        help="Optional S3 bucket to download validation artifacts from.",
    )

    parser.add_argument(
        "--s3-prefix",
        default=None,
        help="Optional S3 prefix to download validation artifacts from.",
    )

    parser.add_argument(
        "--aws-profile",
        default=None,
        help="Optional AWS CLI profile.",
    )

    parser.add_argument(
        "--aws-region",
        default="eu-north-1",
        help="AWS region.",
    )

    args = parser.parse_args()

    build_label = args.build_label or (
        f"manual-analysis-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}"
    )

    temp_dir: Path | None = None

    try:
        if args.s3_bucket and args.s3_prefix:
            temp_dir = Path(tempfile.mkdtemp(prefix="pfe-analyzer-"))
            print(f"[INFO] Downloading S3 validation artifacts to {temp_dir}")

            download_s3_prefix(
                bucket=args.s3_bucket,
                prefix=args.s3_prefix,
                destination=temp_dir,
                aws_profile=args.aws_profile,
                aws_region=args.aws_region,
            )

            input_dir = temp_dir

            if args.build_label is None:
                build_label = args.s3_prefix.strip("/").split("/")[-1]
        else:
            input_dir = Path(args.input_dir)

        metrics_dir = Path(args.metrics_dir) if args.metrics_dir else None

        if not input_dir.exists():
            print(f"[ERROR] Input directory does not exist: {input_dir}", file=sys.stderr)
            return 1

        reports = parse_validation_reports(input_dir)
        prometheus_metrics = parse_prometheus_metrics(metrics_dir)

        summary = build_validation_summary(
            reports=reports,
            build_label=build_label,
            prometheus_metrics=prometheus_metrics,
        )

        decision = build_anomaly_decision(
            reports=reports,
            build_label=build_label,
            metrics=prometheus_metrics,
        )

        output_dir = Path(args.output_dir)
        write_outputs(output_dir, summary, decision)

        print("[OK] Analyzer completed successfully.")
        print(f"[INFO] Summary:  {output_dir / 'summary.json'}")
        print(f"[INFO] Decision: {output_dir / 'decision.json'}")
        print(f"[INFO] Report:   {output_dir / 'analysis-report.txt'}")
        print(f"[INFO] Severity: {decision['severity']}")
        print(f"[INFO] Risk:     {decision['risk_score']}/100")
        print(f"[INFO] Validation risk: {decision['validation_risk_score']}/100")
        print(f"[INFO] Metrics risk:    {decision['metrics_risk_score']}/100")

        return 0

    finally:
        if temp_dir and temp_dir.exists():
            shutil.rmtree(temp_dir)


if __name__ == "__main__":
    raise SystemExit(main())
