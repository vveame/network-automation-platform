#!/usr/bin/env bash
set -euo pipefail

JENKINS_URL="http://10.200.0.10:8080"
JENKINS_JOB_PATH="job/pfe-network-validation"

echo "[INFO] Triggering Jenkins job: ${JENKINS_URL}/${JENKINS_JOB_PATH}/buildWithParameters"

CRUMB="$(curl -fsS --netrc-file /root/.jenkins_netrc \
  "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)" || true)"

if [ -n "$CRUMB" ]; then
  curl -fsS -X POST \
    --netrc-file /root/.jenkins_netrc \
    -H "$CRUMB" \
    --data-urlencode "PIPELINE_MODE=AUTO" \
    --data-urlencode "CONFIRM_APPLY=false" \
    --data-urlencode "AUTO_PUSH_IMAGES=true" \
    --data-urlencode "DOCKERHUB_NAMESPACE=vviam" \
    --data-urlencode "IMAGE_TAG=latest" \
    --data-urlencode "GNS3_HOST=<GNS3_VM_IP>" \
    --data-urlencode "PUBLISH_DASHBOARD=true" \
    --data-urlencode "EXPORT_ARTIFACTS_TO_S3=true" \
    --data-urlencode "S3_ARTIFACTS_BUCKET=network-automation-platform-dev-artifacts-823766425926" \
    --data-urlencode "CLOUD_AWS_REGION=eu-north-1" \
    "${JENKINS_URL}/${JENKINS_JOB_PATH}/buildWithParameters"
else
  curl -fsS -X POST \
    --netrc-file /root/.jenkins_netrc \
    --data-urlencode "PIPELINE_MODE=AUTO" \
    --data-urlencode "CONFIRM_APPLY=false" \
    --data-urlencode "AUTO_PUSH_IMAGES=true" \
    --data-urlencode "DOCKERHUB_NAMESPACE=vviam" \
    --data-urlencode "IMAGE_TAG=latest" \
    --data-urlencode "GNS3_HOST=<GNS3_VM_IP>" \
    --data-urlencode "PUBLISH_DASHBOARD=true" \
    --data-urlencode "EXPORT_ARTIFACTS_TO_S3=true" \
    --data-urlencode "S3_ARTIFACTS_BUCKET=network-automation-platform-dev-artifacts-823766425926" \
    --data-urlencode "CLOUD_AWS_REGION=eu-north-1" \
    "${JENKINS_URL}/${JENKINS_JOB_PATH}/buildWithParameters"
fi

echo "[OK] Jenkins job triggered successfully."