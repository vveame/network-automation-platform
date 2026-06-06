#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

AUTH_FILE="$REPO_ROOT/monitoring/snmp/snmp-auth.local.yml"
AUTH_EXAMPLE_FILE="$REPO_ROOT/monitoring/snmp/snmp-auth.local.yml.example"
EXPORTER_DEFAULT_FILE="$REPO_ROOT/monitoring/snmp/prometheus-snmp-exporter.default"

OUTPUT_FILE="/etc/prometheus/snmp.yml"
BACKUP_TS="$(date -u +%Y%m%dT%H%M%SZ)"

# Official generated SNMP Exporter config.
# This is pinned to a Prometheus SNMP Exporter release/branch source.
# It already contains the generated if_mib module with interface mappings.
UPSTREAM_SNMP_YML_URL="${UPSTREAM_SNMP_YML_URL:-https://raw.githubusercontent.com/prometheus/snmp_exporter/v0.25.0/snmp.yml}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

UPSTREAM_CONFIG="$TMP_DIR/upstream-snmp.yml"
FINAL_CONFIG="$TMP_DIR/snmp.yml.final"

echo "[INFO] Building local SNMP Exporter config..."
echo "[INFO] Repo root:        $REPO_ROOT"
echo "[INFO] Local auth file:  $AUTH_FILE"
echo "[INFO] Upstream config:  $UPSTREAM_SNMP_YML_URL"
echo "[INFO] Output file:      $OUTPUT_FILE"

if [ ! -f "$AUTH_FILE" ]; then
  echo "[WARN] Local SNMP auth file is missing."

  if [ ! -f "$AUTH_EXAMPLE_FILE" ]; then
    echo "[ERROR] Missing example auth file:"
    echo "        $AUTH_EXAMPLE_FILE"
    exit 1
  fi

  echo "[INFO] Creating local auth file from example..."
  cp "$AUTH_EXAMPLE_FILE" "$AUTH_FILE"
  chmod 600 "$AUTH_FILE"

  echo
  echo "[ACTION REQUIRED]"
  echo "Edit this file and replace CHANGE_ME values with the real SNMPv3 credentials:"
  echo "  nano $AUTH_FILE"
  echo
  echo "Then rerun:"
  echo "  ./monitoring/scripts/build-local-snmp-exporter-config.sh"
  exit 1
fi

if grep -q "CHANGE_ME" "$AUTH_FILE"; then
  echo "[ERROR] Local SNMP auth file still contains CHANGE_ME placeholders."
  echo "[INFO] Edit it first:"
  echo "       nano $AUTH_FILE"
  exit 1
fi

if ! grep -q "^auths:" "$AUTH_FILE"; then
  echo "[ERROR] Local SNMP auth file must contain a top-level auths: block."
  exit 1
fi

echo "[INFO] Installing required tools..."
sudo apt update
sudo apt install -y prometheus-snmp-exporter snmp curl >/dev/null

echo "[INFO] Downloading official generated SNMP Exporter config..."
curl -fsSL "$UPSTREAM_SNMP_YML_URL" -o "$UPSTREAM_CONFIG"

echo "[INFO] Validating upstream config..."

if ! grep -q "^modules:" "$UPSTREAM_CONFIG"; then
  echo "[ERROR] Upstream config does not contain modules:"
  exit 1
fi

if ! grep -q "if_mib:" "$UPSTREAM_CONFIG"; then
  echo "[ERROR] Upstream config does not contain if_mib."
  exit 1
fi

if ! grep -q "ifOperStatus" "$UPSTREAM_CONFIG"; then
  echo "[ERROR] Upstream config does not contain ifOperStatus."
  exit 1
fi

if ! grep -q "ifAdminStatus" "$UPSTREAM_CONFIG"; then
  echo "[ERROR] Upstream config does not contain ifAdminStatus."
  exit 1
fi

echo "[INFO] Merging local SNMPv3 auth with official upstream modules..."

cat "$AUTH_FILE" > "$FINAL_CONFIG"
echo >> "$FINAL_CONFIG"

# Remove the upstream auths block and keep the official modules block.
awk '
  BEGIN { skip_auths = 0 }

  /^auths:[[:space:]]*$/ {
    skip_auths = 1
    next
  }

  /^modules:[[:space:]]*$/ {
    skip_auths = 0
  }

  skip_auths == 0 {
    print
  }
' "$UPSTREAM_CONFIG" >> "$FINAL_CONFIG"

echo "[INFO] Validating final local config..."

if ! grep -q "pfe_snmpv3_authpriv" "$FINAL_CONFIG"; then
  echo "[ERROR] Final config does not contain pfe_snmpv3_authpriv."
  exit 1
fi

if grep -q "CHANGE_ME" "$FINAL_CONFIG"; then
  echo "[ERROR] Final config still contains CHANGE_ME placeholders."
  exit 1
fi

if ! grep -q "ifOperStatus" "$FINAL_CONFIG"; then
  echo "[ERROR] Final config does not contain ifOperStatus."
  exit 1
fi

if ! grep -q "ifAdminStatus" "$FINAL_CONFIG"; then
  echo "[ERROR] Final config does not contain ifAdminStatus."
  exit 1
fi

if [ -f "$OUTPUT_FILE" ]; then
  echo "[INFO] Backing up existing local SNMP Exporter config:"
  echo "       ${OUTPUT_FILE}.bak.${BACKUP_TS}"
  sudo cp -a "$OUTPUT_FILE" "${OUTPUT_FILE}.bak.${BACKUP_TS}"
fi

echo "[INFO] Installing final local SNMP Exporter config..."
sudo mkdir -p /etc/prometheus
sudo cp "$FINAL_CONFIG" "$OUTPUT_FILE"
sudo chown root:prometheus "$OUTPUT_FILE" 2>/dev/null || sudo chown root:root "$OUTPUT_FILE"
sudo chmod 640 "$OUTPUT_FILE"

if [ ! -f "$EXPORTER_DEFAULT_FILE" ]; then
  echo "[ERROR] Missing exporter default file:"
  echo "        $EXPORTER_DEFAULT_FILE"
  exit 1
fi

echo "[INFO] Installing SNMP Exporter systemd args..."
sudo cp "$EXPORTER_DEFAULT_FILE" /etc/default/prometheus-snmp-exporter
sudo chown root:root /etc/default/prometheus-snmp-exporter
sudo chmod 644 /etc/default/prometheus-snmp-exporter

echo "[INFO] Restarting SNMP Exporter..."
sudo systemctl daemon-reload
sudo systemctl reset-failed prometheus-snmp-exporter || true
sudo systemctl restart prometheus-snmp-exporter
sudo systemctl enable prometheus-snmp-exporter >/dev/null

echo "[INFO] Testing SNMP Exporter HTTP endpoint..."
curl -fsS http://localhost:9116/metrics >/dev/null

echo "[INFO] Testing edge-router SNMP scrape through SNMP Exporter..."
curl -fsS "http://localhost:9116/snmp?target=10.200.0.30:1161&module=if_mib&auth=pfe_snmpv3_authpriv" \
  | grep -Ei "ifOperStatus|ifAdminStatus|ifHCInOctets|ifHCOutOctets|sysUpTime|snmp_scrape" \
  | head -n 60 || true

echo
echo "[OK] Local SNMP Exporter config generated successfully."
echo "[INFO] Final local config: $OUTPUT_FILE"
echo "[INFO] This file contains SNMPv3 credentials and must not be committed."