# Cloud Scripts

This directory contains helper scripts for the cloud integration phase of the intelligent network automation platform.

## Current Strategy

The project currently follows the documented hybrid strategy where the AWS VPN module is prepared but disabled.

Instead of enabling VPN immediately, the local DevOps environment exports validation artifacts to AWS S3 over HTTPS.

This provides a safe first cloud integration path:

```text
Local GNS3 / Ansible / Jenkins validation
        ↓
Ansible outputs
        ↓
S3 artifacts bucket
        ↓
Future monitoring / AI analysis pipeline
```

## Scripts

### upload-validation-artifacts-s3.sh

Uploads local validation artifacts from:

```text
ansible/outputs/
```

to the Terraform-created S3 artifacts bucket.

The bucket name is read from:

```text
terraform output -raw artifacts_bucket_name
```

inside:

```text
cloud/terraform/environments/dev/
```

## Jenkins Cloud Analyzer Integration

After Jenkins uploads raw validation artifacts to S3, it runs the cloud analyzer locally inside the Jenkins workspace.

The analyzer reads:

```text
ansible/outputs/
```

and generates:

```text
summary.json
decision.json
analysis-report.txt
```

Jenkins then uploads those analyzer outputs to S3.

Per-build analyzer outputs are stored under:

```text
processed-summaries/<jenkins-job-name>-<build-number>/
anomaly-results/<jenkins-job-name>-<build-number>/
```

The most recent analyzer output is also copied to:

```text
latest/analyzer/
```

This provides two access patterns:

* historical per-build anomaly decisions
* stable latest anomaly decision for future dashboards or automation

The analyzer is currently rule-based and explainable. It prepares the future AI/ML detection layer before Prometheus metrics and hybrid connectivity are fully enabled.

## Required Local Configuration

The script expects an AWS CLI profile configured on the DevOps VM.

Default profile:

```text
vviam-student
```

Default region:

```text
eu-north-1
```

These can be overridden:

```bash
AWS_PROFILE=vviam-student AWS_REGION=eu-north-1 ./cloud/scripts/upload-validation-artifacts-s3.sh
```

## Security Notes

The script does not contain AWS credentials.

AWS credentials must remain local on the DevOps VM and must never be committed to GitHub.

The S3 bucket is private and configured through Terraform with:

- public access blocking
- bucket owner enforced ownership
- versioning
- server-side encryption

## S3-Backed Dashboard Cache

The dashboard uses AWS S3 as the source of truth for generated validation and analyzer outputs.

Jenkins uploads the latest validation artifacts to:

```text
latest/validation-artifacts/
```

and the latest analyzer outputs to:

```text
latest/analyzer/
```

The script:

```text
sync-dashboard-cache-from-s3.sh
```

synchronizes those latest S3 paths into the local dashboard cache:

```text
/var/lib/pfe-dashboard/outputs
/var/lib/pfe-dashboard/analyzer/latest
```

This allows the Flask dashboard to visualize cloud-backed data without making the S3 bucket public and without requiring the dashboard itself to directly fetch AWS data.

The dashboard cache can be restored even if local generated files are deleted, as long as the latest outputs still exist in S3.