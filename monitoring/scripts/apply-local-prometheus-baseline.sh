#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

PROM_CONFIG_SRC="$REPO_ROOT/monitoring/prometheus/prometheus.yml"
NODE_TARGETS_SRC="$REPO_ROOT/monitoring/prometheus/targets/node-targets.yml"

PROM_CONFIG_DST="/etc/prometheus/prometheus.yml"
TARGETS_DIR="/etc/prometheus/targets"
NODE_TARGETS_DST="$TARGETS_DIR/node-targets.yml"

echo "[INFO] Installing Prometheus and Node Exporter if missing..."
sudo apt update
sudo apt install -y prometheus prometheus-node-exporter

echo "[INFO] Preparing Prometheus target directory..."
sudo mkdir -p "$TARGETS_DIR"

echo "[INFO] Copying Prometheus configuration..."
sudo cp "$PROM_CONFIG_SRC" "$PROM_CONFIG_DST"
sudo cp "$NODE_TARGETS_SRC" "$NODE_TARGETS_DST"

echo "[INFO] Setting permissions..."
sudo chown -R prometheus:prometheus /etc/prometheus
sudo chmod 644 "$PROM_CONFIG_DST" "$NODE_TARGETS_DST"

echo "[INFO] Checking Prometheus configuration..."
if command -v promtool >/dev/null 2>&1; then
  promtool check config "$PROM_CONFIG_DST"
else
  echo "[WARN] promtool not found in PATH. Skipping config syntax check."
fi

echo "[INFO] Enabling and restarting services..."
sudo systemctl enable prometheus prometheus-node-exporter
sudo systemctl restart prometheus-node-exporter
sudo systemctl restart prometheus

echo "[INFO] Checking service status..."
sudo systemctl --no-pager --full status prometheus-node-exporter | head -n 20 || true
sudo systemctl --no-pager --full status prometheus | head -n 20 || true

echo "[INFO] Waiting for Prometheus readiness..."

PROM_READY=false

for i in {1..30}; do
  if curl -fsS http://localhost:9090/-/ready >/dev/null 2>&1; then
    PROM_READY=true
    break
  fi

  echo "[INFO] Prometheus not ready yet, retrying... ($i/30)"
  sleep 2
done

if [ "$PROM_READY" != "true" ]; then
  echo "[ERROR] Prometheus did not become ready in time."
  echo "[INFO] Prometheus health endpoint:"
  curl -i http://localhost:9090/-/healthy || true

  echo "[INFO] Recent Prometheus logs:"
  sudo journalctl -u prometheus --no-pager -n 50

  exit 1
fi

echo "[OK] Prometheus is ready."

echo
echo "[INFO] Testing Node Exporter metrics endpoint..."
curl -fsS http://localhost:9100/metrics -o /tmp/node-exporter-metrics.txt
head /tmp/node-exporter-metrics.txt

echo
echo "[OK] Local Prometheus monitoring baseline applied."
echo "[INFO] Prometheus UI: http://localhost:9090"
