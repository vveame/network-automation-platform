# Cloud Analyzer

This directory contains the first anomaly-detection baseline for the cloud phase of the intelligent network automation platform.

## Purpose

The final target architecture is based on monitoring metrics and logs collected from the local infrastructure and analyzed by an AI/anomaly-detection module.

However, while the VPN/hybrid link is disabled, the cloud cannot directly scrape private GNS3 nodes.

For this reason, the first analyzer works with Jenkins/Ansible validation artifacts exported to S3.

## Current Flow

```text
Local GNS3 topology
        ↓
Ansible validation
        ↓
Jenkins pipeline
        ↓
ansible/outputs/
        ↓
AWS S3 validation-artifacts/
        ↓
Cloud analyzer
        ↓
summary.json + decision.json + analysis-report.txt
        ↓
AWS S3 processed-summaries/ and anomaly-results/
```

## Structure

```text
cloud/analyzer/
├── analyze_validation_artifacts.py
├── parse_validation_reports.py
├── anomaly_rules.py
├── generate_summary.py
├── requirements.txt
└── README.md
```

## Components

### analyze_validation_artifacts.py

Main CLI entrypoint.

It can analyze local `ansible/outputs/` or download a validation artifact prefix from S3 before analysis.

### parse_validation_reports.py

Parses raw validation report files.

Responsibilities:

* read `.txt` reports
* classify report category
* detect critical patterns
* detect warning patterns
* handle expected security-block test results
* mark each report as passed, warning, failed or empty

### anomaly_rules.py

Contains explainable anomaly scoring logic.

Responsibilities:

* calculate risk score
* assign severity
* recommend action
* generate anomaly decision object

### generate_summary.py

Generates analyzer output files.

Outputs:

* `summary.json`
* `decision.json`
* `analysis-report.txt`

## Current Detection Logic

The first version uses explainable rule-based anomaly scoring.

It checks validation reports for:

* failed Ansible tasks
* unreachable nodes
* security validation failures
* DMZ service failures
* OOB management failures
* FRR/routing validation issues
* OVS/switching validation issues
* end-to-end validation failures
* warning patterns

Expected security-block tests are handled separately. For example, blocked SSH or HTTP tests may produce connection timeouts, but those timeouts are considered normal when they appear in explicit blocked-policy sections.

## Analyzer Outputs in S3

Jenkins uploads analyzer outputs to:

```text
processed-summaries/<jenkins-job-name>-<build-number>/
anomaly-results/<jenkins-job-name>-<build-number>/
latest/analyzer/
```

Example:

```text
processed-summaries/pfe-network-validation-48/
anomaly-results/pfe-network-validation-48/
latest/analyzer/decision.json
```

## Why Rule-Based First

A full ML model requires historical metrics and enough clean time-series data.

This first analyzer creates a structured baseline that can later be extended with:

* Prometheus metrics
* log events
* historical trends
* statistical anomaly detection
* machine learning models

## Run Locally from Current Ansible Outputs

```bash
python3 cloud/analyzer/analyze_validation_artifacts.py \
  --input-dir ansible/outputs \
  --output-dir cloud/analyzer/outputs \
  --build-label local-test
```

## Run from S3 Artifacts

```bash
BUCKET="$(terraform -chdir=cloud/terraform/environments/dev output -raw artifacts_bucket_name)"

python3 cloud/analyzer/analyze_validation_artifacts.py \
  --s3-bucket "$BUCKET" \
  --s3-prefix validation-artifacts/pfe-network-validation-48 \
  --aws-profile vviam-student \
  --aws-region eu-north-1 \
  --output-dir cloud/analyzer/outputs \
  --build-label pfe-network-validation-48
```

## Current Status

This analyzer is a baseline.

It does not replace the final Prometheus-based monitoring architecture.

It prepares the anomaly detection logic while the hybrid connectivity layer is still disabled.
