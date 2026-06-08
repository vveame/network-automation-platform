#!/usr/bin/env bash
set -euo pipefail

# Sync latest cloud-backed dashboard data from <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Sync latest cloud-backed dashboard data from S3 to local dashboard cache paths.
# S3 is the source of truth.
# /var/lib/pfe-dashboard is only the local Flask dashboard cache.

REPO_ROOT="$(git rev-parse --show-toplevel)"
TERRAFORM_ENV_DIR="${TERRAFORM_ENV_DIR:-$REPO_ROOT/cloud/terraform/environments/dev}"

DASHBOARD_CACHE_DIR="${DASHBOARD_CACHE_DIR:-/var/lib/pfe-dashboard}"

ANSIBLE_OUTPUTS_DIR="${ANSIBLE_OUTPUTS_DIR:-$DASHBOARD_CACHE_DIR/outputs}"
ANALYZER_LATEST_DIR="${ANALYZER_LATEST_DIR:-$DASHBOARD_CACHE_DIR/analyzer/latest}"
METRICS_LATEST_DIR="${METRICS_LATEST_DIR:-$DASHBOARD_CACHE_DIR/metrics/latest}"
ML_LATEST_DIR="${ML_LATEST_DIR:-$DASHBOARD_CACHE_DIR/ml/latest}"
ML_DATA_DIR="${ML_DATA_DIR:-$DASHBOARD_CACHE_DIR/ml/data}"
REMEDIATION_LATEST_DIR="${REMEDIATION_LATEST_DIR:-$DASHBOARD_CACHE_DIR/remediation/latest}"

AWS_REGION="${AWS_REGION:-eu-north-1}"
AWS_PROFILE="${AWS_PROFILE:-}"

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

mkdir -p "$ANSIBLE_OUTPUTS_DIR"
mkdir -p "$ANALYZER_LATEST_DIR"
mkdir -p "$METRICS_LATEST_DIR"
mkdir -p "$ML_LATEST_DIR"
mkdir -p "$ML_DATA_DIR"
mkdir -p "$REMEDIATION_LATEST_DIR"

echo "[INFO] AWS region: $AWS_REGION"
echo "[INFO] Bucket: $ARTIFACTS_BUCKET"
echo "[INFO] Dashboard cache: $DASHBOARD_CACHE_DIR"

echo "[INFO] Checking AWS identity..."
aws sts get-caller-identity "${AWS_ARGS[@]}" >/dev/null

echo "[INFO] Syncing latest validation artifacts from S3 to dashboard cache..."
aws s3 sync \
  "s3://$ARTIFACTS_BUCKET/latest/validation-artifacts/" \
  "$ANSIBLE_OUTPUTS_DIR/" \
  "${AWS_ARGS[@]}" \
  --delete

echo "[INFO] Syncing latest analyzer outputs from S3 to dashboard cache..."
aws s3 sync \
  "s3://$ARTIFACTS_BUCKET/latest/analyzer/" \
  "$ANALYZER_LATEST_DIR/" \
  "${AWS_ARGS[@]}" \
  --delete

echo "[INFO] Syncing latest Prometheus metrics snapshot from S3 to dashboard cache..."
aws s3 sync \
  "s3://$ARTIFACTS_BUCKET/latest/metrics/" \
  "$METRICS_LATEST_DIR/" \
  "${AWS_ARGS[@]}" \
  --delete

echo "[INFO] Syncing latest ML decision outputs from S3 to dashboard cache..."
aws s3 sync \
  "s3://$ARTIFACTS_BUCKET/latest/ml/" \
  "$ML_LATEST_DIR/" \
  "${AWS_ARGS[@]}" \
  --delete || true

echo "[INFO] Syncing latest ML dataset from S3 to dashboard cache..."
aws s3 sync \
  "s3://$ARTIFACTS_BUCKET/latest/ml-dataset/" \
  "$ML_DATA_DIR/" \
  "${AWS_ARGS[@]}" \
  --delete || true

echo "[INFO] Syncing latest remediation outputs from S3 to dashboard cache..."
aws s3 sync \
  "s3://$ARTIFACTS_BUCKET/latest/remediation/" \
  "$REMEDIATION_LATEST_DIR/" \
  "${AWS_ARGS[@]}" \
  --delete || true

echo "[OK] Dashboard cache synchronized from S3."

echo "[INFO] Validation cache: $ANSIBLE_OUTPUTS_DIR"
echo "[INFO] Analyzer cache: $ANALYZER_LATEST_DIR"
echo "[INFO] Metrics cache: $METRICS_LATEST_DIR"
echo "[INFO] ML cache: $ML_LATEST_DIR"
echo "[INFO] ML data cache: $ML_DATA_DIR"
echo "[INFO] Remediation cache: $REMEDIATION_LATEST_DIR"

if [ -f "$ANALYZER_LATEST_DIR/final-decision.json" ]; then
  echo "[INFO] Latest final decision:"
  python3 -m json.tool "$ANALYZER_LATEST_DIR/final-decision.json" || cat "$ANALYZER_LATEST_DIR/final-decision.json"
elif [ -f "$ANALYZER_LATEST_DIR/decision.json" ]; then
  echo "[INFO] Latest rule-based analyzer decision:"
  python3 -m json.tool "$ANALYZER_LATEST_DIR/decision.json" || cat "$ANALYZER_LATEST_DIR/decision.json"
fi

if [ -f "$ML_LATEST_DIR/ml-decision.json" ]; then
  echo "[INFO] Latest ML decision:"
  python3 -m json.tool "$ML_LATEST_DIR/ml-decision.json" || cat "$ML_LATEST_DIR/ml-decision.json"
fi

if [ -f "$REMEDIATION_LATEST_DIR/plan/remediation-plan.json" ]; then
  echo "[INFO] Latest remediation plan:"
  python3 -m json.tool "$REMEDIATION_LATEST_DIR/plan/remediation-plan.json" || cat "$REMEDIATION_LATEST_DIR/plan/remediation-plan.json"
fi
