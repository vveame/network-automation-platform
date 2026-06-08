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
  "snapshot_time_utc": "$TIMESTAMP",
  "export_time_utc": "$TIMESTAMP",
  "prometheus_url": "$PROMETHEUS_URL",
  "snapshot_type": "local-prometheus-monitoring-baseline",
  "metrics_scope": [
    "prometheus_target_health",
    "node_exporter_host_resources",
    "blackbox_service_probes",
    "snmp_network_device_interfaces"
  ]
}
EOF

cat > "$OUTPUT_DIR/README.txt" <<EOF
PFE Prometheus Metrics Snapshot

Generated at: $TIMESTAMP
Prometheus URL: $PROMETHEUS_URL

This directory contains exported Prometheus API query results.
It is temporary in the Jenkins/repo workspace.
S3 is the durable source of truth after upload.

Metric groups:
- Prometheus target health
- Node Exporter host resource metrics
- Blackbox HTTP/TCP/DNS probe metrics
- SNMPv3 network-device interface metrics
EOF

echo "[INFO] Exporting Prometheus target health..."
query_prometheus "up" 'up'

echo "[INFO] Exporting Node Exporter host metrics..."
query_prometheus "node_uname_info" 'node_uname_info{job="node-exporter"}'
query_prometheus "node_boot_time_seconds" 'node_boot_time_seconds{job="node-exporter"}'
query_prometheus "node_load1" 'node_load1{job="node-exporter"}'
query_prometheus "node_load5" 'node_load5{job="node-exporter"}'
query_prometheus "node_load15" 'node_load15{job="node-exporter"}'

query_prometheus "node_cpu_usage_percent" '100 - (avg by (instance, node_name, role) (rate(node_cpu_seconds_total{job="node-exporter",mode="idle"}[5m])) * 100)'

query_prometheus "node_memory_available_bytes" 'node_memory_MemAvailable_bytes{job="node-exporter"}'
query_prometheus "node_memory_total_bytes" 'node_memory_MemTotal_bytes{job="node-exporter"}'
query_prometheus "node_memory_used_percent" '100 * (1 - (node_memory_MemAvailable_bytes{job="node-exporter"} / node_memory_MemTotal_bytes{job="node-exporter"}))'

query_prometheus "node_filesystem_available_bytes" 'node_filesystem_avail_bytes{job="node-exporter",mountpoint="/",fstype!~"tmpfs|overlay|squashfs|devtmpfs"}'
query_prometheus "node_filesystem_size_bytes" 'node_filesystem_size_bytes{job="node-exporter",mountpoint="/",fstype!~"tmpfs|overlay|squashfs|devtmpfs"}'
query_prometheus "node_filesystem_used_percent" '100 * (1 - (node_filesystem_avail_bytes{job="node-exporter",mountpoint="/",fstype!~"tmpfs|overlay|squashfs|devtmpfs"} / node_filesystem_size_bytes{job="node-exporter",mountpoint="/",fstype!~"tmpfs|overlay|squashfs|devtmpfs"}))'
query_prometheus "node_filesystem_readonly" 'node_filesystem_readonly{job="node-exporter",mountpoint="/"}'

echo "[INFO] Exporting Blackbox service probe metrics..."
query_prometheus "blackbox_probe_success" 'probe_success{job=~"blackbox-http|blackbox-tcp|blackbox-dns"}'
query_prometheus "blackbox_probe_duration_seconds" 'probe_duration_seconds{job=~"blackbox-http|blackbox-tcp|blackbox-dns"}'
query_prometheus "blackbox_http_status_code" 'probe_http_status_code{job="blackbox-http"}'
query_prometheus "blackbox_dns_lookup_time_seconds" 'probe_dns_lookup_time_seconds{job=~"blackbox-http|blackbox-dns"}'

echo "[INFO] Exporting SNMP network-device target metrics..."
query_prometheus "snmp_up" 'up{job="snmp-network-devices"}'
query_prometheus "snmp_sys_uptime" 'sysUpTime{job="snmp-network-devices"}'

echo "[INFO] Exporting SNMP interface state metrics..."
query_prometheus "snmp_if_admin_status" 'ifAdminStatus{job="snmp-network-devices"}'
query_prometheus "snmp_if_oper_status" 'ifOperStatus{job="snmp-network-devices"}'
query_prometheus "snmp_if_last_change" 'ifLastChange{job="snmp-network-devices"}'

echo "[INFO] Exporting SNMP interface traffic counters..."
query_prometheus "snmp_if_hc_in_octets" 'ifHCInOctets{job="snmp-network-devices"}'
query_prometheus "snmp_if_hc_out_octets" 'ifHCOutOctets{job="snmp-network-devices"}'

echo "[INFO] Exporting SNMP interface traffic rates..."
query_prometheus "snmp_if_hc_in_octets_rate_5m" 'rate(ifHCInOctets{job="snmp-network-devices"}[5m])'
query_prometheus "snmp_if_hc_out_octets_rate_5m" 'rate(ifHCOutOctets{job="snmp-network-devices"}[5m])'

echo "[INFO] Exporting SNMP interface error counters..."
query_prometheus "snmp_if_in_errors" 'ifInErrors{job="snmp-network-devices"}'
query_prometheus "snmp_if_out_errors" 'ifOutErrors{job="snmp-network-devices"}'

echo "[INFO] Exporting SNMP interface error rates..."
query_prometheus "snmp_if_in_errors_rate_5m" 'rate(ifInErrors{job="snmp-network-devices"}[5m])'
query_prometheus "snmp_if_out_errors_rate_5m" 'rate(ifOutErrors{job="snmp-network-devices"}[5m])'

echo "[INFO] Exporting SNMP interface discard counters..."
query_prometheus "snmp_if_in_discards" 'ifInDiscards{job="snmp-network-devices"}'
query_prometheus "snmp_if_out_discards" 'ifOutDiscards{job="snmp-network-devices"}'

echo "[INFO] Exporting SNMP interface discard rates..."
query_prometheus "snmp_if_in_discards_rate_5m" 'rate(ifInDiscards{job="snmp-network-devices"}[5m])'
query_prometheus "snmp_if_out_discards_rate_5m" 'rate(ifOutDiscards{job="snmp-network-devices"}[5m])'

echo "[INFO] Exporting SNMP interface speed/capacity metrics..."
query_prometheus "snmp_if_speed" 'ifSpeed{job="snmp-network-devices"}'
query_prometheus "snmp_if_high_speed" 'ifHighSpeed{job="snmp-network-devices"}'
query_prometheus "snmp_if_mtu" 'ifMtu{job="snmp-network-devices"}'

echo "[OK] Prometheus metrics snapshot exported to: $OUTPUT_DIR"
find "$OUTPUT_DIR" -maxdepth 1 -type f -printf "%f\n" | sort