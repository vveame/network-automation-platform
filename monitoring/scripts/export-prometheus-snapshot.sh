#!/usr/bin/env bash
set -euo pipefail

# Export a Prometheus metrics snapshot.
#
# This script generates temporary metrics outputs in the Jenkins/repo workspace.
# S3 becomes the source of truth after upload.
# /var/lib/pfe-dashboard is restored later by sync-dashboard-cache-from-s3.sh.

REPO_ROOT="$(git rev-parse --show-toplevel)"

PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/monitoring/outputs/latest}"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

query_prometheus() {
  local name="$1"
  local query="$2"

  echo "[INFO] Querying $name..."
  curl -fsS --get "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=$query" \
    -o "$OUTPUT_DIR/${name}.json"
}

cat > "$OUTPUT_DIR/manifest.json" <<EOF
{
  "project": "network-automation-platform",
  "source": "local-prometheus-baseline",
  "export_time_utc": "$TIMESTAMP",
  "prometheus_url": "$PROMETHEUS_URL"
}
EOF

cat > "$OUTPUT_DIR/README.txt" <<EOF
Prometheus metrics snapshot exported at $TIMESTAMP.

This folder is a local temporary workspace output.
The durable source of truth is S3 after Jenkins upload.

Included metric groups:
- Prometheus scrape target health
- Node Exporter host metrics
- Blackbox Exporter service probes
- SNMP Exporter network/interface metrics
EOF

echo "[INFO] Exporting Prometheus target health..."
query_prometheus "up" 'up'

echo "[INFO] Exporting Node Exporter host metrics..."
query_prometheus "node_uname_info" 'node_uname_info'
query_prometheus "node_memory_available_bytes" 'node_memory_MemAvailable_bytes{job="node-exporter"}'
query_prometheus "node_memory_total_bytes" 'node_memory_MemTotal_bytes{job="node-exporter"}'
query_prometheus "node_filesystem_available_bytes" 'node_filesystem_avail_bytes{job="node-exporter",mountpoint="/",fstype!~"tmpfs|overlay"}'
query_prometheus "node_filesystem_size_bytes" 'node_filesystem_size_bytes{job="node-exporter",mountpoint="/",fstype!~"tmpfs|overlay"}'

echo "[INFO] Exporting Blackbox service probe metrics..."
query_prometheus "blackbox_probe_success" 'probe_success'
query_prometheus "blackbox_probe_duration_seconds" 'probe_duration_seconds'
query_prometheus "blackbox_http_status_code" 'probe_http_status_code'

echo "[INFO] Exporting SNMP network-device metrics..."
query_prometheus "snmp_up" 'up{job="snmp-network-devices"}'
query_prometheus "snmp_sys_uptime" 'sysUpTime{job="snmp-network-devices"}'
query_prometheus "snmp_if_admin_status" 'ifAdminStatus{job="snmp-network-devices"}'
query_prometheus "snmp_if_oper_status" 'ifOperStatus{job="snmp-network-devices"}'
query_prometheus "snmp_if_hc_in_octets" 'ifHCInOctets{job="snmp-network-devices"}'
query_prometheus "snmp_if_hc_out_octets" 'ifHCOutOctets{job="snmp-network-devices"}'
query_prometheus "snmp_if_in_errors" 'ifInErrors{job="snmp-network-devices"}'
query_prometheus "snmp_if_out_errors" 'ifOutErrors{job="snmp-network-devices"}'

echo "[OK] Prometheus metrics snapshot exported."
echo "[INFO] Output directory: $OUTPUT_DIR"

ls -lah "$OUTPUT_DIR"