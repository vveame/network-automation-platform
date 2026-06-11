#!/usr/bin/env bash
set -euo pipefail

# Upload Prometheus metrics snapshot to S3.

# - Metrics are generated in monitoring/outputs/latest.
# - This script uploads them to S3.
# - S3 is the source of truth.
# - /var/lib/pfe-dashboard/metrics/latest is only restored later from S3.

REPO_ROOT="$(git rev-parse --show-toplevel)"
TERRAFORM_ENV_DIR="${TERRAFORM_ENV_DIR:-$REPO_ROOT/cloud/terraform/environments/dev}"

METRICS_SNAPSHOT_DIR="${METRICS_SNAPSHOT_DIR:-$REPO_ROOT/monitoring/outputs/latest}"

AWS_REGION="${AWS_REGION:-eu-north-1}"
AWS_PROFILE="${AWS_PROFILE:-}"

if [ ! -d "$METRICS_SNAPSHOT_DIR" ]; then
  echo "[ERROR] Metrics snapshot directory not found: $METRICS_SNAPSHOT_DIR"
  echo "[INFO] Run cloud/scripts/export-cloud-prometheus-snapshot.sh first."
  exit 1
fi

if [ -z "$(ls -A "$METRICS_SNAPSHOT_DIR" 2>/dev/null)" ]; then
  echo "[ERROR] Metrics snapshot directory is empty: $METRICS_SNAPSHOT_DIR"
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
BUILD_LABEL="${BUILD_TAG:-manual-metrics-$TIMESTAMP}"

HISTORY_PREFIX="metrics-snapshots/$BUILD_LABEL"
LATEST_PREFIX="latest/metrics"

echo "[INFO] AWS region:  $AWS_REGION"
echo "[INFO] Bucket:      $ARTIFACTS_BUCKET"
echo "[INFO] Build:       $BUILD_LABEL"
echo "[INFO] Source:      $METRICS_SNAPSHOT_DIR"
echo "[INFO] History:     $HISTORY_PREFIX"
echo "[INFO] Latest:      $LATEST_PREFIX"

echo "[INFO] Checking AWS identity..."
aws sts get-caller-identity "${AWS_ARGS[@]}" >/dev/null

echo "[INFO] Uploading immutable per-build metrics snapshot..."
aws s3 sync "$METRICS_SNAPSHOT_DIR" "s3://$ARTIFACTS_BUCKET/$HISTORY_PREFIX/" "${AWS_ARGS[@]}"

echo "[INFO] Updating latest metrics snapshot in S3..."
aws s3 sync "$METRICS_SNAPSHOT_DIR" "s3://$ARTIFACTS_BUCKET/$LATEST_PREFIX/" "${AWS_ARGS[@]}" --delete

echo "[OK] Prometheus metrics snapshot uploaded successfully."
echo "[INFO] Per-build S3 path: s3://$ARTIFACTS_BUCKET/$HISTORY_PREFIX/"
echo "[INFO] Latest S3 path:    s3://$ARTIFACTS_BUCKET/$LATEST_PREFIX/"
