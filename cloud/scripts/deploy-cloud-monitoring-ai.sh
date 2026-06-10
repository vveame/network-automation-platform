#!/usr/bin/env bash
set -euo pipefail

# Deploy cloud monitoring + AI/analyzer runtime to the private monitoring EC2.
#
# This script intentionally does NOT sync the full repository.
# It sends only the cloud runtime needed by the private monitoring EC2:
#   cloud/monitoring/
#   cloud/analyzer/
#
# Required path:
#   DevOps -> EdgeRouter -> WireGuard -> AWS tunnel gateway -> private monitoring EC2

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="${TF_DIR:-$REPO_ROOT/cloud/terraform/environments/dev}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/pfe-aws-tunnel}"
SSH_USER="${SSH_USER:-ec2-user}"
REMOTE_REPO_DIR="${REMOTE_REPO_DIR:-/opt/pfe-repo}"
BUNDLE_PATH="${BUNDLE_PATH:-/tmp/pfe-cloud-runtime.tar.gz}"

cd "$TF_DIR"

MON_IP="$(terraform output -raw monitoring_private_ip)"

if [ -z "$MON_IP" ]; then
  echo "[ERROR] monitoring_private_ip Terraform output is empty."
  exit 1
fi

echo "[INFO] Monitoring private IP: $MON_IP"

cd "$REPO_ROOT"

echo "[INFO] Ensuring DevOps route to AWS VPC goes through EdgeRouter..."
if [ -x "$REPO_ROOT/scripts/devops/route-cloud-via-edge-router.sh" ]; then
  sudo "$REPO_ROOT/scripts/devops/route-cloud-via-edge-router.sh"
else
  sudo ip route replace 10.50.0.0/16 via 10.200.0.30 dev ens34
fi

echo "[INFO] Testing SSH to private monitoring EC2..."
ssh -o IdentitiesOnly=yes -o IPQoS=none -i "$SSH_KEY" "$SSH_USER@$MON_IP" \
  "hostname; ip route"

echo "[INFO] Creating compact cloud runtime bundle: $BUNDLE_PATH"

rm -f "$BUNDLE_PATH"

tar \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  --exclude='.venv' \
  --exclude='venv' \
  --exclude='outputs' \
  --exclude='cloud/analyzer/outputs' \
  --exclude='cloud/analyzer/ml/data' \
  --exclude='cloud/analyzer/ml/models' \
  --exclude='cloud/analyzer/ml/outputs' \
  -czf "$BUNDLE_PATH" \
  cloud/monitoring \
  cloud/analyzer

echo "[INFO] Bundle size:"
ls -lh "$BUNDLE_PATH"

echo "[INFO] Bundle content preview:"
tar -tzf "$BUNDLE_PATH" | grep -E 'cloud/monitoring/(prometheus/rules|grafana/provisioning/alerting|grafana/dashboards|targets|prometheus|blackbox)' | head -80 || true

echo "[INFO] Preparing remote directory..."
ssh -o IdentitiesOnly=yes -o IPQoS=none -i "$SSH_KEY" "$SSH_USER@$MON_IP" \
  "sudo mkdir -p '$REMOTE_REPO_DIR' && sudo chown -R '$SSH_USER:$SSH_USER' '$REMOTE_REPO_DIR'"

echo "[INFO] Uploading compact runtime bundle to private monitoring EC2..."
scp -v -o IdentitiesOnly=yes -o IPQoS=none -i "$SSH_KEY" \
  "$BUNDLE_PATH" \
  "$SSH_USER@$MON_IP:/tmp/pfe-cloud-runtime.tar.gz"

echo "[INFO] Extracting runtime bundle on private monitoring EC2..."
ssh -o IdentitiesOnly=yes -o IPQoS=none -i "$SSH_KEY" "$SSH_USER@$MON_IP" \
  "sudo mkdir -p '$REMOTE_REPO_DIR' && \
   sudo rm -rf '$REMOTE_REPO_DIR/cloud/monitoring' '$REMOTE_REPO_DIR/cloud/analyzer' && \
   sudo tar -xzf /tmp/pfe-cloud-runtime.tar.gz -C '$REMOTE_REPO_DIR' && \
   sudo chown -R '$SSH_USER:$SSH_USER' '$REMOTE_REPO_DIR' && \
   find '$REMOTE_REPO_DIR/cloud' -maxdepth 3 -type f | head -40"

# Copy real generated SNMP config if it exists on DevOps.
# The file usually contains SNMPv3 credentials and is readable only by root,
# so it is streamed with sudo instead of copied directly by scp.
if sudo test -f /etc/prometheus/snmp.yml; then
  echo "[INFO] Copying generated SNMP Exporter config to private monitoring EC2..."
  sudo cat /etc/prometheus/snmp.yml | ssh \
    -o IdentitiesOnly=yes \
    -o IPQoS=none \
    -i "$SSH_KEY" \
    "$SSH_USER@$MON_IP" \
    "cat > /tmp/pfe-snmp.yml && chmod 600 /tmp/pfe-snmp.yml && ls -lh /tmp/pfe-snmp.yml"
else
  echo "[WARN] /etc/prometheus/snmp.yml not found on DevOps."
  echo "[WARN] Cloud SNMP exporter will need /etc/snmp_exporter/snmp.yml manually."
fi

echo "[INFO] Running remote cloud monitoring + AI install..."
ssh -tt -o IdentitiesOnly=yes -o IPQoS=none -i "$SSH_KEY" "$SSH_USER@$MON_IP" \
  "sudo REPO_DIR='$REMOTE_REPO_DIR' bash -lc 'set -o pipefail; $REMOTE_REPO_DIR/cloud/monitoring/scripts/install-cloud-monitoring-ai.sh 2>&1 | tee /tmp/pfe-cloud-monitoring-install.log'"

echo "[OK] Cloud monitoring + AI/analyzer deployment completed."
echo "[INFO] Remote install log:"
echo "  /tmp/pfe-cloud-monitoring-install.log"
