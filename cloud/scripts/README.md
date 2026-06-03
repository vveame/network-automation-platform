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