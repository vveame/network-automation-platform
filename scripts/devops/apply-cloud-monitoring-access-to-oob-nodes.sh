#!/usr/bin/env bash
set -euo pipefail

# Apply cloud monitoring access rules to all OOB-managed FRR/OVS nodes.
#
# This applies the rule live to already running containers.
# Persistence is handled by:
#   gns3/scripts/bootstrap-persistent-gns3.sh
#   docker/frr-ssh/entrypoint.sh
#   docker/ovs-ssh/entrypoint.sh

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLOUD_MONITORING_IP="${CLOUD_MONITORING_IP:-10.50.30.154}"
CLOUD_MONITORING_EXTRA_IPS="${CLOUD_MONITORING_EXTRA_IPS:-}"
AWS_VPC_CIDR="${AWS_VPC_CIDR:-10.50.0.0/16}"
EDGE_OOB_GW="${EDGE_OOB_GW:-10.200.0.30}"
SSH_USER="${SSH_USER:-root}"

ACCESS_SCRIPT="$REPO_ROOT/security/cloud-monitoring-access.sh"
TARGET_FILE="$REPO_ROOT/cloud/monitoring/targets/cloud-snmp-targets.yml"

if [ ! -f "$ACCESS_SCRIPT" ]; then
  echo "[ERROR] Missing $ACCESS_SCRIPT"
  exit 1
fi

if [ -f "$TARGET_FILE" ]; then
  mapfile -t TARGETS < <(
    grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:1161' "$TARGET_FILE" \
      | sed 's/:1161$//' \
      | sort -u
  )
else
  TARGETS=(
    10.200.0.11
    10.200.0.12
    10.200.0.21
    10.200.0.22
    10.200.0.30
    10.200.0.31
    10.200.0.32
    10.200.0.33
    10.200.0.44
    10.200.0.45
    10.200.0.46
  )
fi

echo "[INFO] Cloud monitoring IP: $CLOUD_MONITORING_IP"
echo "[INFO] Cloud monitoring extra IPs: ${CLOUD_MONITORING_EXTRA_IPS:-none}"
echo "[INFO] AWS VPC CIDR: $AWS_VPC_CIDR"
echo "[INFO] EdgeRouter OOB gateway: $EDGE_OOB_GW"
echo "[INFO] Targets:"
printf '  - %s\n' "${TARGETS[@]}"

OK=0
FAIL=0

for ip in "${TARGETS[@]}"; do
  echo
  echo "========== $ip =========="

  if ! scp -q "$ACCESS_SCRIPT" "$SSH_USER@$ip:/etc/local/security/cloud-monitoring-access.sh"; then
    echo "[ERROR] Failed to copy access script to $ip"
    FAIL=$((FAIL + 1))
    continue
  fi

  if ssh -o ConnectTimeout=10 "$SSH_USER@$ip" "
    set -e
    chmod +x /etc/local/security/cloud-monitoring-access.sh
    CLOUD_MONITORING_IP='$CLOUD_MONITORING_IP' \
    CLOUD_MONITORING_EXTRA_IPS='$CLOUD_MONITORING_EXTRA_IPS' \
    AWS_VPC_CIDR='$AWS_VPC_CIDR' \
    EDGE_OOB_GW='$EDGE_OOB_GW' \
    /etc/local/security/cloud-monitoring-access.sh
  "; then
    echo "[OK] Applied on $ip"
    OK=$((OK + 1))
  else
    echo "[ERROR] Failed on $ip"
    FAIL=$((FAIL + 1))
  fi
done

echo
echo "========== SUMMARY =========="
echo "OK: $OK"
echo "FAILED: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

echo "[OK] Cloud monitoring access applied to all OOB SNMP nodes."
