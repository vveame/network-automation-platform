#!/usr/bin/env bash
set -euo pipefail

JENKINS_URL="http://10.200.0.10:8080"
JENKINS_JOB_PATH="job/pfe-network-validation"

echo "[INFO] Triggering Jenkins job: ${JENKINS_URL}/${JENKINS_JOB_PATH}/build"

curl -fsS -X POST \
  --netrc-file /root/.jenkins_netrc \
  "${JENKINS_URL}/${JENKINS_JOB_PATH}/build"

echo "[OK] Jenkins job triggered successfully."