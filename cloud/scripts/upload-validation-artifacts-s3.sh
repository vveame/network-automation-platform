#!/usr/bin/env bash
set -euo pipefail

# Upload local Ansible/Jenkins validation artifacts to the AWS S3 artifacts bucket.
#
# Hybrid Option :
# - VPN remains disabled.
# - Local validation outputs are exported to cloud storage over HTTPS.
# - Future monitoring/AI services can consume these artifacts from S3.

REPO_ROOT="$(git rev-parse --show-toplevel)"
TERRAFORM_ENV_DIR="${TERRAFORM_ENV_DIR:-$REPO_ROOT/cloud/terraform/environments/dev}"
ANSIBLE_OUTPUTS_DIR="${ANSIBLE_OUTPUTS_DIR:-$REPO_ROOT/ansible/outputs}"

AWS_REGION="${AWS_REGION:-eu-north-1}"
AWS_PROFILE="${AWS_PROFILE:-}"

if [ ! -d "$ANSIBLE_OUTPUTS_DIR" ]; then
  echo "[ERROR] Ansible outputs directory not found: $ANSIBLE_OUTPUTS_DIR"
  echo "[INFO] Run the local validation pipeline first so ansible/outputs exists."
  exit 1
fi

if [ -z "$(ls -A "$ANSIBLE_OUTPUTS_DIR" 2>/dev/null)" ]; then
  echo "[ERROR] Ansible outputs directory is empty: $ANSIBLE_OUTPUTS_DIR"
  echo "[INFO] Run Ansible/Jenkins validation before uploading artifacts."
  exit 1
fi

AWS_ARGS=(--region "$AWS_REGION")

if [ -n "$AWS_PROFILE" ]; then
  AWS_ARGS+=(--profile "$AWS_PROFILE")
fi

if [ -n "${ARTIFACTS_BUCKET:-}" ]; then
  echo "[INFO] Using S3 bucket from ARTIFACTS_BUCKET environment variable."
else
  echo "[INFO] ARTIFACTS_BUCKET not set. Reading S3 bucket name from Terraform outputs..."
  ARTIFACTS_BUCKET="$(terraform -chdir="$TERRAFORM_ENV_DIR" output -raw artifacts_bucket_name)"
fi

if [ -z "$ARTIFACTS_BUCKET" ]; then
  echo "[ERROR] Could not determine artifacts bucket name."
  exit 1
fi

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BUILD_LABEL="${BUILD_TAG:-manual-$TIMESTAMP}"
S3_PREFIX="validation-artifacts/$BUILD_LABEL"

echo "[INFO] AWS region:  $AWS_REGION"
if [ -n "$AWS_PROFILE" ]; then
  echo "[INFO] AWS profile: $AWS_PROFILE"
else
  echo "[INFO] AWS profile: not set, using environment credentials or default AWS chain"
fi
echo "[INFO] Bucket:      $ARTIFACTS_BUCKET"
echo "[INFO] Prefix:      $S3_PREFIX"

echo "[INFO] Checking AWS identity..."
aws sts get-caller-identity "${AWS_ARGS[@]}" >/dev/null

MANIFEST_FILE="$(mktemp)"
cat > "$MANIFEST_FILE" <<MANIFEST
{
  "project": "network-automation-platform",
  "source": "jenkins-local-devops-validation",
  "upload_time_utc": "$TIMESTAMP",
  "build_label": "$BUILD_LABEL",
  "s3_bucket": "$ARTIFACTS_BUCKET",
  "s3_prefix": "$S3_PREFIX"
}
MANIFEST

echo "[INFO] Uploading validation outputs..."
aws s3 sync "$ANSIBLE_OUTPUTS_DIR" "s3://$ARTIFACTS_BUCKET/$S3_PREFIX/" "${AWS_ARGS[@]}"

echo "[INFO] Uploading manifest..."
aws s3 cp "$MANIFEST_FILE" "s3://$ARTIFACTS_BUCKET/$S3_PREFIX/manifest.json" "${AWS_ARGS[@]}"

rm -f "$MANIFEST_FILE"

echo "[OK] Validation artifacts uploaded successfully."
echo "[INFO] S3 path: s3://$ARTIFACTS_BUCKET/$S3_PREFIX/"
