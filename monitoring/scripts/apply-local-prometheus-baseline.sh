#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
BACKUP_TS="$(date -u +%Y%m%dT%H%M%SZ)"

PROM_CONFIG_SRC="$REPO_ROOT/monitoring/prometheus/prometheus.yml"
BLACKBOX_CONFIG_SRC="$REPO_ROOT/monitoring/blackbox/blackbox.yml"

NODE_TARGETS_SRC="$REPO_ROOT/monitoring/prometheus/targets/node-targets.yml"
BLACKBOX_HTTP_TARGETS_SRC="$REPO_ROOT/monitoring/prometheus/targets/blackbox-http-targets.yml"
BLACKBOX_TCP_TARGETS_SRC="$REPO_ROOT/monitoring/prometheus/targets/blackbox-tcp-targets.yml"
BLACKBOX_DNS_TARGETS_SRC="$REPO_ROOT/monitoring/prometheus/targets/blackbox-dns-targets.yml"
SNMP_TARGETS_SRC="$REPO_ROOT/monitoring/prometheus/targets/snmp-targets.yml"

SNMP_CONFIG_EXAMPLE="$REPO_ROOT/monitoring/snmp/snmp.yml.example"
SNMP_CONFIG_BUILDER="$REPO_ROOT/monitoring/scripts/build-local-snmp-exporter-config.sh"
SNMP_EXPORTER_DEFAULT_SRC="$REPO_ROOT/monitoring/snmp/prometheus-snmp-exporter.default"

PROM_CONFIG_DST="/etc/prometheus/prometheus.yml"
BLACKBOX_CONFIG_DST="/etc/prometheus/blackbox.yml"
SNMP_CONFIG_DST="/etc/prometheus/snmp.yml"
SNMP_EXPORTER_ENV_DST="/etc/default/prometheus-snmp-exporter"
TARGETS_DIR="/etc/prometheus/targets"

copy_versioned_file() {
  SRC="$1"
  DST="$2"

  if [ ! -f "$SRC" ]; then
    echo "[ERROR] Missing source file: $SRC"
    exit 1
  fi

  if [ -f "$DST" ] && ! sudo cmp -s "$SRC" "$DST"; then
    echo "[INFO] Existing file differs. Backup created:"
    echo "       ${DST}.bak.${BACKUP_TS}"
    sudo cp -a "$DST" "${DST}.bak.${BACKUP_TS}"
  fi

  sudo cp "$SRC" "$DST"
}

echo "[INFO] Applying local Prometheus monitoring baseline..."
echo "[INFO] Repo root: $REPO_ROOT"

echo "[INFO] Installing Prometheus, exporters and SNMP tools if missing..."
sudo apt update
sudo apt install -y \
  prometheus \
  prometheus-node-exporter \
  prometheus-blackbox-exporter \
  prometheus-snmp-exporter \
  snmp

echo "[INFO] Preparing Prometheus directories..."
sudo mkdir -p /etc/prometheus
sudo mkdir -p "$TARGETS_DIR"

echo "[INFO] Validating required versioned files..."
for file in \
  "$PROM_CONFIG_SRC" \
  "$BLACKBOX_CONFIG_SRC" \
  "$SNMP_CONFIG_EXAMPLE" \
  "$SNMP_CONFIG_BUILDER" \
  "$SNMP_EXPORTER_DEFAULT_SRC" \
  "$NODE_TARGETS_SRC" \
  "$BLACKBOX_HTTP_TARGETS_SRC" \
  "$BLACKBOX_TCP_TARGETS_SRC" \
  "$BLACKBOX_DNS_TARGETS_SRC" \
  "$SNMP_TARGETS_SRC"
do
  if [ ! -f "$file" ]; then
    echo "[ERROR] Missing required file: $file"
    exit 1
  fi
done

echo "[INFO] Checking local SNMP Exporter config..."
echo "[INFO] This script will NOT overwrite $SNMP_CONFIG_DST."

if [ ! -f "$SNMP_CONFIG_DST" ]; then
  echo "[ERROR] Missing local SNMP Exporter config:"
  echo "        $SNMP_CONFIG_DST"
  echo
  echo "[INFO] Generate it first with:"
  echo "        ./monitoring/scripts/build-local-snmp-exporter-config.sh"
  echo
  echo "[INFO] Why?"
  echo "        /etc/prometheus/snmp.yml contains local SNMPv3 credentials"
  echo "        and the full generated IF-MIB metric mappings."
  exit 1
fi

if sudo grep -q "CHANGE_ME" "$SNMP_CONFIG_DST"; then
  echo "[ERROR] /etc/prometheus/snmp.yml contains placeholder values."
  echo "[INFO] Fix monitoring/snmp/snmp-auth.local.yml, then rerun:"
  echo "       ./monitoring/scripts/build-local-snmp-exporter-config.sh"
  exit 1
fi

if sudo grep -q '\${SNMP_' "$SNMP_CONFIG_DST"; then
  echo "[ERROR] /etc/prometheus/snmp.yml contains unsupported environment placeholders."
  echo "[INFO] Your installed SNMP Exporter does not support --config.expand-environment-variables."
  echo "[INFO] Generate the local full config with:"
  echo "       ./monitoring/scripts/build-local-snmp-exporter-config.sh"
  exit 1
fi

if ! sudo grep -q "pfe_snmpv3_authpriv" "$SNMP_CONFIG_DST"; then
  echo "[ERROR] /etc/prometheus/snmp.yml does not contain pfe_snmpv3_authpriv."
  echo "[INFO] Generate it with:"
  echo "       ./monitoring/scripts/build-local-snmp-exporter-config.sh"
  exit 1
fi

if ! sudo grep -q "ifOperStatus" "$SNMP_CONFIG_DST"; then
  echo "[ERROR] /etc/prometheus/snmp.yml does not contain full generated IF-MIB metric mappings."
  echo "[INFO] A minimal walk-only config gives scrape metadata only, not interface metrics."
  echo "[INFO] Generate the full local config with:"
  echo "       ./monitoring/scripts/build-local-snmp-exporter-config.sh"
  exit 1
fi

echo "[OK] Local SNMP Exporter config exists and looks valid."

echo "[INFO] Copying versioned Prometheus configuration..."
copy_versioned_file "$PROM_CONFIG_SRC" "$PROM_CONFIG_DST"

echo "[INFO] Copying versioned Blackbox Exporter configuration..."
copy_versioned_file "$BLACKBOX_CONFIG_SRC" "$BLACKBOX_CONFIG_DST"

echo "[INFO] Preserving local SNMP Exporter config:"
echo "       $SNMP_CONFIG_DST"
echo "[INFO] It contains local SNMPv3 credentials and will NOT be overwritten."

echo "[INFO] Copying versioned SNMP Exporter systemd args..."
copy_versioned_file "$SNMP_EXPORTER_DEFAULT_SRC" "$SNMP_EXPORTER_ENV_DST"

echo "[INFO] Copying Prometheus target files..."
copy_versioned_file "$NODE_TARGETS_SRC" "$TARGETS_DIR/node-targets.yml"
copy_versioned_file "$BLACKBOX_HTTP_TARGETS_SRC" "$TARGETS_DIR/blackbox-http-targets.yml"
copy_versioned_file "$BLACKBOX_TCP_TARGETS_SRC" "$TARGETS_DIR/blackbox-tcp-targets.yml"
copy_versioned_file "$BLACKBOX_DNS_TARGETS_SRC" "$TARGETS_DIR/blackbox-dns-targets.yml"
copy_versioned_file "$SNMP_TARGETS_SRC" "$TARGETS_DIR/snmp-targets.yml"

echo "[INFO] Setting permissions..."
sudo chown -R root:jenkins "$TARGETS_DIR"
sudo chmod -R 2775 "$TARGETS_DIR"
sudo find "$TARGETS_DIR" -type f -exec chmod 664 {} \;

sudo chown prometheus:prometheus "$PROM_CONFIG_DST" 2>/dev/null || true
sudo chmod 644 "$PROM_CONFIG_DST"

sudo chmod 644 "$BLACKBOX_CONFIG_DST"

sudo chown root:prometheus "$SNMP_CONFIG_DST" 2>/dev/null || sudo chown root:root "$SNMP_CONFIG_DST"
sudo chmod 640 "$SNMP_CONFIG_DST"

sudo chown root:root "$SNMP_EXPORTER_ENV_DST"
sudo chmod 644 "$SNMP_EXPORTER_ENV_DST"

echo "[INFO] Checking Prometheus configuration..."
if command -v promtool >/dev/null 2>&1; then
  promtool check config "$PROM_CONFIG_DST"
else
  echo "[WARN] promtool not found in PATH. Skipping config syntax check."
fi

echo "[INFO] Enabling and restarting monitoring services..."
sudo systemctl daemon-reload
sudo systemctl reset-failed prometheus-snmp-exporter || true

sudo systemctl enable prometheus prometheus-node-exporter prometheus-blackbox-exporter prometheus-snmp-exporter
sudo systemctl restart prometheus-node-exporter
sudo systemctl restart prometheus-blackbox-exporter
sudo systemctl restart prometheus-snmp-exporter
sudo systemctl restart prometheus

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
  sudo journalctl -u prometheus --no-pager -n 80
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
echo "[INFO] Testing SNMP Exporter metrics endpoint..."
curl -fsS http://localhost:9116/metrics | head || true

echo
echo "[INFO] Testing SNMP Exporter scrape for edge-router..."
curl -fsS "http://localhost:9116/snmp?target=10.200.0.30:1161&module=if_mib&auth=pfe_snmpv3_authpriv" \
  | grep -Ei "ifOperStatus|ifAdminStatus|ifHCInOctets|ifHCOutOctets|sysUpTime|snmp_scrape" \
  | head -n 40 || true

echo
echo "[INFO] Checking Prometheus target health..."
curl -fsS --get "http://localhost:9090/api/v1/query" \
  --data-urlencode "query=up" | python3 -m json.tool || true

echo
echo "[INFO] Checking SNMP Prometheus job..."
curl -fsS --get "http://localhost:9090/api/v1/query" \
  --data-urlencode 'query=up{job="snmp-network-devices"}' | python3 -m json.tool || true

echo
echo "[INFO] Checking SNMP interface metrics..."
curl -fsS --get "http://localhost:9090/api/v1/query" \
  --data-urlencode 'query=ifOperStatus{job="snmp-network-devices"}' | python3 -m json.tool || true

echo
echo "[OK] Local Prometheus + Node + Blackbox + SNMP monitoring baseline applied."
echo "[INFO] Prometheus UI:       http://localhost:9090"
echo "[INFO] Blackbox Exporter:   http://localhost:9115"
echo "[INFO] SNMP Exporter:       http://localhost:9116"