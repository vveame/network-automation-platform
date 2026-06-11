#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${CONFIG_FILE:-/etc/pfe/jenkins-hybrid.env}"

if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
else
  echo "[ERROR] Missing local config file: $CONFIG_FILE"
  exit 1
fi

JENKINS_URL="${JENKINS_URL:-http://127.0.0.1:8080}"
JENKINS_JOB_PATH="${JENKINS_JOB_PATH:-job/pfe-network-validation}"

PIPELINE_MODE="${PIPELINE_MODE:-AUTO}"
CONFIRM_APPLY="${CONFIRM_APPLY:-false}"

AUTO_PUSH_IMAGES="${AUTO_PUSH_IMAGES:-true}"
DOCKERHUB_NAMESPACE="${DOCKERHUB_NAMESPACE:-vviam}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
GNS3_HOST="${GNS3_HOST:-CHANGE_ME}"
PUBLISH_DASHBOARD="${PUBLISH_DASHBOARD:-true}"

EXPORT_ARTIFACTS_TO_S3="${EXPORT_ARTIFACTS_TO_S3:-true}"
S3_ARTIFACTS_BUCKET="${S3_ARTIFACTS_BUCKET:-CHANGE_ME}"
CLOUD_AWS_REGION="${CLOUD_AWS_REGION:-eu-north-1}"

AWS_MONITORING_HOST="${AWS_MONITORING_HOST:-CHANGE_ME}"
AWS_MONITORING_USER="${AWS_MONITORING_USER:-ec2-user}"
CLOUD_PROMETHEUS_URL="${CLOUD_PROMETHEUS_URL:-http://localhost:9090}"

ENABLE_ML_ANALYZER="${ENABLE_ML_ANALYZER:-true}"
TRAIN_ML_MODEL="${TRAIN_ML_MODEL:-false}"
ML_FEATURES_FILE="${ML_FEATURES_FILE:-cloud/analyzer/ml/features.cloud.json}"

ENABLE_SAFE_REMEDIATION="${ENABLE_SAFE_REMEDIATION:-true}"
REMEDIATION_MODE="${REMEDIATION_MODE:-plan}"
EDGE_UNDERLAY_MODE="${EDGE_UNDERLAY_MODE:-direct}"

fail_if_missing() {
  name="$1"
  value="$2"

  if [ -z "$value" ] || [ "$value" = "CHANGE_ME" ] || echo "$value" | grep -q '<.*>'; then
    echo "[ERROR] $name is not configured in $CONFIG_FILE"
    exit 1
  fi
}

fail_if_missing "GNS3_HOST" "$GNS3_HOST"
fail_if_missing "S3_ARTIFACTS_BUCKET" "$S3_ARTIFACTS_BUCKET"
fail_if_missing "AWS_MONITORING_HOST" "$AWS_MONITORING_HOST"

echo "[INFO] Triggering Jenkins job: ${JENKINS_URL}/${JENKINS_JOB_PATH}/buildWithParameters"
echo "[INFO] PIPELINE_MODE=$PIPELINE_MODE"
echo "[INFO] GNS3_HOST configured: yes"
echo "[INFO] AWS_MONITORING_HOST configured: yes"
echo "[INFO] S3_ARTIFACTS_BUCKET configured: yes"

CRUMB="$(curl -fsS --netrc-file /root/.jenkins_netrc \
  "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)" || true)"

curl_args=(
  -fsS
  -X POST
  --netrc-file /root/.jenkins_netrc
)

if [ -n "$CRUMB" ]; then
  curl_args+=(-H "$CRUMB")
fi

curl "${curl_args[@]}" \
  --data-urlencode "PIPELINE_MODE=$PIPELINE_MODE" \
  --data-urlencode "CONFIRM_APPLY=$CONFIRM_APPLY" \
  --data-urlencode "AUTO_PUSH_IMAGES=$AUTO_PUSH_IMAGES" \
  --data-urlencode "DOCKERHUB_NAMESPACE=$DOCKERHUB_NAMESPACE" \
  --data-urlencode "IMAGE_TAG=$IMAGE_TAG" \
  --data-urlencode "GNS3_HOST=$GNS3_HOST" \
  --data-urlencode "PUBLISH_DASHBOARD=$PUBLISH_DASHBOARD" \
  --data-urlencode "EXPORT_ARTIFACTS_TO_S3=$EXPORT_ARTIFACTS_TO_S3" \
  --data-urlencode "S3_ARTIFACTS_BUCKET=$S3_ARTIFACTS_BUCKET" \
  --data-urlencode "CLOUD_AWS_REGION=$CLOUD_AWS_REGION" \
  --data-urlencode "AWS_MONITORING_HOST=$AWS_MONITORING_HOST" \
  --data-urlencode "AWS_MONITORING_USER=$AWS_MONITORING_USER" \
  --data-urlencode "CLOUD_PROMETHEUS_URL=$CLOUD_PROMETHEUS_URL" \
  --data-urlencode "ENABLE_ML_ANALYZER=$ENABLE_ML_ANALYZER" \
  --data-urlencode "TRAIN_ML_MODEL=$TRAIN_ML_MODEL" \
  --data-urlencode "ML_FEATURES_FILE=$ML_FEATURES_FILE" \
  --data-urlencode "ENABLE_SAFE_REMEDIATION=$ENABLE_SAFE_REMEDIATION" \
  --data-urlencode "REMEDIATION_MODE=$REMEDIATION_MODE" \
  --data-urlencode "EDGE_UNDERLAY_MODE=$EDGE_UNDERLAY_MODE" \
  "${JENKINS_URL}/${JENKINS_JOB_PATH}/buildWithParameters"

echo "[OK] Jenkins job triggered successfully."
