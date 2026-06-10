#!/usr/bin/env bash
set -euo pipefail

# Validate cloud monitoring and analyzer runtime on private monitoring EC2.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="${TF_DIR:-$REPO_ROOT/cloud/terraform/environments/dev}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/pfe-aws-tunnel}"
SSH_USER="${SSH_USER:-ec2-user}"

cd "$TF_DIR"

MON_IP="$(terraform output -raw monitoring_private_ip)"

if [ -z "$MON_IP" ]; then
  echo "[ERROR] monitoring_private_ip Terraform output is empty."
  exit 1
fi

echo "[INFO] Monitoring private IP: $MON_IP"

cd "$REPO_ROOT"

if [ -x "$REPO_ROOT/scripts/devops/route-cloud-via-edge-router.sh" ]; then
  sudo "$REPO_ROOT/scripts/devops/route-cloud-via-edge-router.sh"
fi

echo "[INFO] Validating remote services..."
ssh -o IdentitiesOnly=yes -o IPQoS=none -i "$SSH_KEY" "$SSH_USER@$MON_IP" <<'REMOTE'
set -euo pipefail

echo "=== Host ==="
hostname
ip -br addr
ip route

echo
echo "=== Systemd services ==="
systemctl is-active prometheus
systemctl is-active grafana-server
systemctl is-active node_exporter
systemctl is-active blackbox_exporter
systemctl is-active snmp_exporter || true

echo
echo "=== Local ports ==="
ss -lntp | grep -E ':9090|:3000|:9100|:9115|:9116' || true

echo
echo "=== Prometheus config ==="
promtool check config /etc/prometheus/prometheus.yml

echo
echo "=== Prometheus readiness ==="
curl -fsS http://localhost:9090/-/ready

echo
echo "=== Prometheus targets ==="
curl -fsS http://localhost:9090/api/v1/targets | python3 -m json.tool | head -80

echo
echo "=== Grafana health ==="
curl -fsS http://localhost:3000/api/health || true

echo
echo "=== Exporters ==="
curl -fsS http://localhost:9100/metrics | head -5
curl -fsS http://localhost:9115/metrics | head -5
curl -fsS http://localhost:9116/metrics | head -5 || true

echo
echo "=== Analyzer Python runtime ==="
/opt/pfe-analyzer-runtime/.venv/bin/python --version
/opt/pfe-analyzer-runtime/.venv/bin/python - <<'PY'
import pandas, numpy, sklearn, joblib
print("analyzer_ml_runtime=ok")
PY

echo "[OK] Cloud monitoring + analyzer runtime validation completed."
REMOTE

echo
echo "[INFO] Optional local access through SSH tunnel:"
echo "ssh -o IdentitiesOnly=yes -o IPQoS=none -i $SSH_KEY -L 9090:localhost:9090 -L 3000:localhost:3000 $SSH_USER@$MON_IP"
