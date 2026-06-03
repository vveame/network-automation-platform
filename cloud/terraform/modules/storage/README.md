cat > ~/pfe-repo/cloud/terraform/modules/storage/README.md <<'EOF'
# Storage Module

This module creates the first S3 storage baseline for the hybrid network automation platform.

## Purpose

The bucket is reserved for future cloud-side artifacts, such as:

- monitoring exports
- logs
- AI analysis outputs
- datasets
- Jenkins/cloud reports

## Resources

The module creates:

- S3 bucket
- S3 bucket public access block
- S3 bucket ownership controls
- S3 bucket versioning
- S3 bucket server-side encryption configuration

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