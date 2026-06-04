#!/usr/bin/env bash

# Upload local Ansible/Jenkins validation artifacts to the AWS S3 artifacts bucket.

# - VPN remains disabled.
# - Local validation outputs are exported to cloud storage over HTTPS.
# - Future monitoring/AI services can consume these artifacts from S3.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
TERRAFORM_ENV_DIR="${TERRAFORM_ENV_DIR:-$REPO_ROOT/cloud/terraform/environments/dev}"
ANSIBLE_OUTPUTS_DIR="${ANSIBLE_OUTPUTS_DIR:-$REPO_ROOT/ansible/outputs}"

AWS_REGION="${AWS_REGION:-eu-north-1}"
AWS_PROFILE="${AWS_PROFILE:-}"

if [ ! -d "$ANSIBLE_OUTPUTS_DIR" ]; then
  echo "[ERROR] Ansible outputs directory not found: $ANSIBLE_OUTPUTS_DIR"
  exit 1
fi

if [ -z "$(ls -A "$ANSIBLE_OUTPUTS_DIR" 2>/dev/null)" ]; then
  echo "[ERROR] Ansible outputs directory is empty: $ANSIBLE_OUTPUTS_DIR"
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

HISTORY_PREFIX="validation-artifacts/$BUILD_LABEL"
LATEST_PREFIX="latest/validation-artifacts"

echo "[INFO] AWS region:  $AWS_REGION"
echo "[INFO] Bucket:      $ARTIFACTS_BUCKET"
echo "[INFO] Build:       $BUILD_LABEL"
echo "[INFO] History:     $HISTORY_PREFIX"
echo "[INFO] Latest:      $LATEST_PREFIX"

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
  "history_prefix": "$HISTORY_PREFIX",
  "latest_prefix": "$LATEST_PREFIX"
}
MANIFEST

echo "[INFO] Uploading immutable per-build validation outputs..."
aws s3 sync "$ANSIBLE_OUTPUTS_DIR" "s3://$ARTIFACTS_BUCKET/$HISTORY_PREFIX/" "${AWS_ARGS[@]}"

echo "[INFO] Uploading per-build manifest..."
aws s3 cp "$MANIFEST_FILE" "s3://$ARTIFACTS_BUCKET/$HISTORY_PREFIX/manifest.json" "${AWS_ARGS[@]}"

echo "[INFO] Updating latest validation artifact cache in S3..."
aws s3 sync "$ANSIBLE_OUTPUTS_DIR" "s3://$ARTIFACTS_BUCKET/$LATEST_PREFIX/" "${AWS_ARGS[@]}" --delete

echo "[INFO] Uploading latest manifest..."
aws s3 cp "$MANIFEST_FILE" "s3://$ARTIFACTS_BUCKET/$LATEST_PREFIX/manifest.json" "${AWS_ARGS[@]}"

rm -f "$MANIFEST_FILE"

echo "[OK] Validation artifacts uploaded successfully."
echo "[INFO] Per-build S3 path: s3://$ARTIFACTS_BUCKET/$HISTORY_PREFIX/"
echo "[INFO] Latest S3 path:    s3://$ARTIFACTS_BUCKET/$LATEST_PREFIX/"
