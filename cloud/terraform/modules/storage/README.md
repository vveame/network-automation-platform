# Storage Module

This module creates the first S3 storage baseline for the hybrid network automation platform.

## Purpose

The bucket is reserved for future cloud-side artifacts, such as:

* monitoring exports
* logs
* AI analysis outputs
* datasets
* Jenkins/cloud reports
* Jenkins/Ansible validation artifacts

## Resources

The module creates:

* S3 bucket
* S3 bucket public access block
* S3 bucket ownership controls
* S3 bucket versioning
* S3 bucket server-side encryption configuration
* S3 bucket lifecycle configuration

## Security Design

The bucket is private by default.

Public access is blocked using S3 Block Public Access settings.

Object ownership is configured using `BucketOwnerEnforced`.

Versioning is enabled to preserve object history.

Server-side encryption is enabled using AES256.

## Bucket Naming

If no custom bucket name is provided, the module generates a deterministic bucket name using:

```text
<project-name>-<environment>-artifacts-<aws-account-id>
```

S3 bucket names must be unique, so including the AWS account ID reduces the risk of naming conflicts.

## Validation Artifact Retention

Jenkins uploads validation outputs under:

```text
validation-artifacts/
```

Each run gets its own prefix, for example:

```text
validation-artifacts/pfe-network-validation-43/
validation-artifacts/manual-20260603T181000Z/
```

This keeps builds traceable and avoids overwriting historical validation outputs.

To avoid unlimited storage growth, the module applies an S3 lifecycle rule to the `validation-artifacts/` prefix.

Default retention:

```hcl
validation_artifact_retention_days = 30
noncurrent_version_retention_days  = 7
```

The lifecycle rule:

* expires validation artifact objects after 30 days
* expires noncurrent object versions after 7 days
* aborts incomplete multipart uploads after 1 day

## Notes

This module does not store Terraform remote state.

It is reserved for platform artifacts, monitoring exports, logs, validation reports and future AI analysis outputs.
