#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

PROM_CONFIG_SRC="$REPO_ROOT/monitoring/prometheus/prometheus.yml"
NODE_TARGETS_SRC="$REPO_ROOT/monitoring/prometheus/targets/node-targets.yml"
BLACKBOX_HTTP_TARGETS_SRC="$REPO_ROOT/monitoring/prometheus/targets/blackbox-http-targets.yml"
BLACKBOX_TCP_TARGETS_SRC="$REPO_ROOT/monitoring/prometheus/targets/blackbox-tcp-targets.yml"
BLACKBOX_DNS_TARGETS_SRC="$REPO_ROOT/monitoring/prometheus/targets/blackbox-dns-targets.yml"
BLACKBOX_CONFIG_SRC="$REPO_ROOT/monitoring/blackbox/blackbox.yml"

PROM_CONFIG_DST="/etc/prometheus/prometheus.yml"
TARGETS_DIR="/etc/prometheus/targets"
BLACKBOX_CONFIG_DST="/etc/prometheus/blackbox.yml"

echo "[INFO] Installing Prometheus, Node Exporter and Blackbox Exporter if missing..."
sudo apt update
sudo apt install -y prometheus prometheus-node-exporter prometheus-blackbox-exporter

echo "[INFO] Preparing Prometheus target directory..."
sudo mkdir -p "$TARGETS_DIR"

echo "[INFO] Copying Prometheus configuration..."
sudo cp "$PROM_CONFIG_SRC" "$PROM_CONFIG_DST"

echo "[INFO] Copying Blackbox Exporter configuration..."
sudo cp "$BLACKBOX_CONFIG_SRC" "$BLACKBOX_CONFIG_DST"

echo "[INFO] Copying Prometheus target files..."
sudo cp "$NODE_TARGETS_SRC" "$TARGETS_DIR/node-targets.yml"
sudo cp "$BLACKBOX_HTTP_TARGETS_SRC" "$TARGETS_DIR/blackbox-http-targets.yml"
sudo cp "$BLACKBOX_TCP_TARGETS_SRC" "$TARGETS_DIR/blackbox-tcp-targets.yml"
sudo cp "$BLACKBOX_DNS_TARGETS_SRC" "$TARGETS_DIR/blackbox-dns-targets.yml"

echo "[INFO] Setting permissions..."
sudo chown -R root:jenkins "$TARGETS_DIR"
sudo chmod -R 2775 "$TARGETS_DIR"
sudo find "$TARGETS_DIR" -type f -exec chmod 664 {} \;

sudo chown prometheus:prometheus "$PROM_CONFIG_DST" 2>/dev/null || true
sudo chmod 644 "$PROM_CONFIG_DST"
sudo chmod 644 "$BLACKBOX_CONFIG_DST"

echo "[INFO] Checking Prometheus configuration..."
if command -v promtool >/dev/null 2>&1; then
  promtool check config "$PROM_CONFIG_DST"
else
  echo "[WARN] promtool not found in PATH. Skipping config syntax check."
fi

echo "[INFO] Enabling and restarting services..."
sudo systemctl enable prometheus prometheus-node-exporter prometheus-blackbox-exporter
sudo systemctl restart prometheus-node-exporter
sudo systemctl restart prometheus-blackbox-exporter
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
curl -fsS http://localhost:9100/metrics | head || true

echo
echo "[INFO] Testing Blackbox Exporter probe endpoint..."
curl -fsS "http://localhost:9115/probe?module=http_2xx&target=http://172.16.50.10" | head || true

echo
echo "[OK] Local Prometheus + Blackbox monitoring baseline applied."
echo "[INFO] Prometheus UI: http://localhost:9090"
echo "[INFO] Blackbox Exporter: http://localhost:9115"
