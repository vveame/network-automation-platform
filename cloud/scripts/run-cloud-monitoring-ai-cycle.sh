#!/usr/bin/env bash
set -euo pipefail

: "${ARTIFACTS_BUCKET:?ARTIFACTS_BUCKET is required}"
: "${BUILD_TAG:?BUILD_TAG is required}"

AWS_REGION="${AWS_REGION:-eu-north-1}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"

ENABLE_ML_ANALYZER="${ENABLE_ML_ANALYZER:-true}"
TRAIN_ML_MODEL="${TRAIN_ML_MODEL:-false}"
ML_DURATION_MINUTES="${ML_DURATION_MINUTES:-60}"
ML_STEP="${ML_STEP:-60s}"
ML_CONTAMINATION="${ML_CONTAMINATION:-0.05}"
ML_FEATURES_FILE="${ML_FEATURES_FILE:-cloud/analyzer/ml/features.cloud.json}"

CLOUD_AI_STATE_DIR="${CLOUD_AI_STATE_DIR:-$HOME/pfe-cloud-ai}"
MODEL_DIR="${CLOUD_AI_STATE_DIR}/ml/models"
RUN_ROOT="${CLOUD_AI_STATE_DIR}/runs/${BUILD_TAG}"

VALIDATION_DIR="${RUN_ROOT}/validation"
METRICS_DIR="${RUN_ROOT}/metrics"
ANALYZER_DIR="${RUN_ROOT}/analyzer"
ML_RAW_DIR="${RUN_ROOT}/ml/raw"
ML_FEATURE_DIR="${RUN_ROOT}/ml/features"
ML_OUTPUT_DIR="${RUN_ROOT}/ml/outputs"
ML_TRAINING_DIR="${RUN_ROOT}/ml/training"

mkdir -p "$VALIDATION_DIR" "$METRICS_DIR" "$ANALYZER_DIR" \
         "$ML_RAW_DIR" "$ML_FEATURE_DIR" "$ML_OUTPUT_DIR" "$ML_TRAINING_DIR" "$MODEL_DIR"

echo "[INFO] Cloud monitoring/AI cycle started."
echo "[INFO] Build tag: $BUILD_TAG"
echo "[INFO] Prometheus URL: $PROMETHEUS_URL"
echo "[INFO] S3 bucket: $ARTIFACTS_BUCKET"
echo "[INFO] AWS region: $AWS_REGION"

echo "[INFO] Checking cloud Prometheus readiness..."
curl -fsS "${PROMETHEUS_URL}/-/ready"
echo

echo "[INFO] Downloading validation artifacts from S3..."
aws s3 sync \
  "s3://${ARTIFACTS_BUCKET}/validation-artifacts/${BUILD_TAG}/" \
  "$VALIDATION_DIR/" \
  --region "$AWS_REGION" \
  --delete

if [ ! -f "$VALIDATION_DIR/validation-summary.txt" ]; then
  echo "[ERROR] validation-summary.txt not found in downloaded validation artifacts."
  echo "[INFO] Expected: s3://${ARTIFACTS_BUCKET}/validation-artifacts/${BUILD_TAG}/"
  exit 1
fi

echo "[INFO] Exporting cloud Prometheus metrics snapshot..."
chmod +x cloud/scripts/export-cloud-prometheus-snapshot.sh

PROMETHEUS_URL="$PROMETHEUS_URL" \
OUTPUT_DIR="$METRICS_DIR" \
./cloud/scripts/export-cloud-prometheus-snapshot.sh

echo "[INFO] Uploading cloud metrics snapshot to S3..."
aws s3 sync "$METRICS_DIR" \
  "s3://${ARTIFACTS_BUCKET}/metrics-snapshots/${BUILD_TAG}/" \
  --region "$AWS_REGION" \
  --delete

aws s3 sync "$METRICS_DIR" \
  "s3://${ARTIFACTS_BUCKET}/latest/metrics/" \
  --region "$AWS_REGION" \
  --delete

echo "[INFO] Running rule-based analyzer in AWS..."
python3 cloud/analyzer/analyze_validation_artifacts.py \
  --input-dir "$VALIDATION_DIR" \
  --metrics-dir "$METRICS_DIR" \
  --output-dir "$ANALYZER_DIR" \
  --build-label "$BUILD_TAG"

test -f "$ANALYZER_DIR/summary.json"
test -f "$ANALYZER_DIR/decision.json"
test -f "$ANALYZER_DIR/analysis-report.txt"

echo "[INFO] Uploading rule-based analyzer results to S3..."
aws s3 sync "$ANALYZER_DIR" \
  "s3://${ARTIFACTS_BUCKET}/processed-summaries/${BUILD_TAG}/" \
  --region "$AWS_REGION" \
  --delete

aws s3 sync "$ANALYZER_DIR" \
  "s3://${ARTIFACTS_BUCKET}/anomaly-results/${BUILD_TAG}/" \
  --region "$AWS_REGION" \
  --delete

aws s3 sync "$ANALYZER_DIR" \
  "s3://${ARTIFACTS_BUCKET}/latest/analyzer/" \
  --region "$AWS_REGION" \
  --delete

if [ "$ENABLE_ML_ANALYZER" = "true" ]; then
  echo "[INFO] Running ML analyzer in AWS..."

  if [ ! -f "$ML_FEATURES_FILE" ]; then
    echo "[ERROR] ML features file not found: $ML_FEATURES_FILE"
    exit 1
  fi

  if [ ! -d ".venv-cloud-ml" ]; then
    python3 -m venv .venv-cloud-ml
  fi

  . .venv-cloud-ml/bin/activate
  python -m pip install --upgrade pip
  python -m pip install -r cloud/analyzer/ml/requirements.txt

  python cloud/analyzer/ml/collect_prometheus_window.py \
    --prometheus-url "$PROMETHEUS_URL" \
    --features-file "$ML_FEATURES_FILE" \
    --duration-minutes "$ML_DURATION_MINUTES" \
    --step "$ML_STEP" \
    --output-dir "$ML_RAW_DIR"

  python cloud/analyzer/ml/build_feature_dataset.py \
    --raw-dir "$ML_RAW_DIR" \
    --output-csv "$ML_FEATURE_DIR/latest_features.csv"

  if [ "$TRAIN_ML_MODEL" = "true" ] || [ ! -f "$MODEL_DIR/isolation_forest.joblib" ]; then
    echo "[INFO] Training Isolation Forest model in AWS..."
    python cloud/analyzer/ml/train_isolation_forest.py \
      --input-csv "$ML_FEATURE_DIR/latest_features.csv" \
      --model-dir "$MODEL_DIR" \
      --output-dir "$ML_TRAINING_DIR" \
      --contamination "$ML_CONTAMINATION"
  else
    echo "[INFO] Reusing existing ML model: $MODEL_DIR/isolation_forest.joblib"
  fi

  python cloud/analyzer/ml/predict_anomaly.py \
    --input-csv "$ML_FEATURE_DIR/latest_features.csv" \
    --model-path "$MODEL_DIR/isolation_forest.joblib" \
    --metadata-path "$MODEL_DIR/training_metadata.json" \
    --output-dir "$ML_OUTPUT_DIR"

  test -f "$ML_OUTPUT_DIR/ml-decision.json"

  echo "[INFO] Uploading ML dataset, model metadata and decision to S3..."
  aws s3 sync "$ML_FEATURE_DIR" \
    "s3://${ARTIFACTS_BUCKET}/ml-datasets/${BUILD_TAG}/" \
    --region "$AWS_REGION" \
    --delete

  aws s3 sync "$ML_FEATURE_DIR" \
    "s3://${ARTIFACTS_BUCKET}/latest/ml-dataset/" \
    --region "$AWS_REGION" \
    --delete

  aws s3 sync "$ML_OUTPUT_DIR" \
    "s3://${ARTIFACTS_BUCKET}/ml-results/${BUILD_TAG}/" \
    --region "$AWS_REGION" \
    --delete

  aws s3 sync "$ML_OUTPUT_DIR" \
    "s3://${ARTIFACTS_BUCKET}/latest/ml/" \
    --region "$AWS_REGION" \
    --delete

  aws s3 sync "$MODEL_DIR" \
    "s3://${ARTIFACTS_BUCKET}/ml-models/latest/" \
    --region "$AWS_REGION" \
    --delete

  echo "[INFO] Merging rule-based and ML decisions in AWS..."
  python cloud/analyzer/ml/merge_ml_decision.py \
    --rule-decision "$ANALYZER_DIR/decision.json" \
    --ml-decision "$ML_OUTPUT_DIR/ml-decision.json" \
    --output-dir "$ANALYZER_DIR"

else
  echo "[INFO] ML analyzer disabled. Creating rule-only final decision."
  python3 - <<PY
import json
from pathlib import Path

analyzer_dir = Path("$ANALYZER_DIR")
rule = json.loads((analyzer_dir / "decision.json").read_text())

final = {
  "build_label": "$BUILD_TAG",
  "final_status": rule.get("status", "UNKNOWN"),
  "recommended_action": rule.get("recommended_action", "monitor"),
  "rule_engine": rule,
  "ml_engine": {
    "available": False,
    "reason": "ENABLE_ML_ANALYZER=false"
  },
  "safety_policy": {
    "ml_is_advisory": True,
    "automated_remediation_requires_rule_confirmation": True
  }
}

(analyzer_dir / "final-decision.json").write_text(json.dumps(final, indent=2, sort_keys=True))
(analyzer_dir / "final-decision-report.txt").write_text(
    "PFE Final Anomaly Decision Report\\n"
    "=================================\\n\\n"
    "ML analyzer disabled. Rule-only final decision generated.\\n"
)
PY
fi

test -f "$ANALYZER_DIR/final-decision.json"
test -f "$ANALYZER_DIR/final-decision-report.txt"

echo "[INFO] Uploading final hybrid decision to S3..."
aws s3 cp "$ANALYZER_DIR/final-decision.json" \
  "s3://${ARTIFACTS_BUCKET}/anomaly-results/${BUILD_TAG}/final-decision.json" \
  --region "$AWS_REGION"

aws s3 cp "$ANALYZER_DIR/final-decision-report.txt" \
  "s3://${ARTIFACTS_BUCKET}/anomaly-results/${BUILD_TAG}/final-decision-report.txt" \
  --region "$AWS_REGION"

aws s3 sync "$ANALYZER_DIR" \
  "s3://${ARTIFACTS_BUCKET}/latest/analyzer/" \
  --region "$AWS_REGION" \
  --delete

echo "[OK] Cloud monitoring/AI cycle completed successfully."
echo "[OK] Final decision: s3://${ARTIFACTS_BUCKET}/latest/analyzer/final-decision.json"
