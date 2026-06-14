#!/usr/bin/env bash
set -euo pipefail

PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
OUTPUT_DIR="${OUTPUT_DIR:-./cloud-monitoring-snapshot}"

mkdir -p "$OUTPUT_DIR"

query_prometheus() {
  local name="$1"
  local query="$2"

  echo "[INFO] Querying $name..."
  curl -fsS --get "${PROMETHEUS_URL}/api/v1/query" \
    --data-urlencode "query=${query}" \
    -o "${OUTPUT_DIR}/${name}.json"
}

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"

cat > "${OUTPUT_DIR}/manifest.json" <<MANIFEST
{
  "project": "network-automation-platform",
  "source": "cloud-prometheus",
  "export_time_utc": "${TIMESTAMP}",
  "prometheus_url": "${PROMETHEUS_URL}"
}
MANIFEST

echo "[INFO] Exporting cloud Prometheus snapshot..."
echo "[INFO] Prometheus URL: $PROMETHEUS_URL"
echo "[INFO] Output directory: $OUTPUT_DIR"

curl -fsS "${PROMETHEUS_URL}/-/ready"

query_prometheus "up" 'up'

query_prometheus "cloud_node_up" 'up{job=~"cloud-node-exporter|local-node-exporter-through-tunnel"}'
query_prometheus "cloud_prometheus_up" 'up{job="cloud-prometheus-self"}'
query_prometheus "cloud_blackbox_up" 'up{job=~"cloud-blackbox-http-through-tunnel|cloud-blackbox-tcp-through-tunnel|cloud-blackbox-dns-through-tunnel"}'
query_prometheus "cloud_snmp_up" 'up{job="cloud-snmp-network-devices-through-tunnel"}'
query_prometheus "snmp_up" 'up{job="cloud-snmp-network-devices-through-tunnel"}'

query_prometheus "blackbox_probe_success" 'probe_success{job=~"cloud-blackbox-http-through-tunnel|cloud-blackbox-tcp-through-tunnel|cloud-blackbox-dns-through-tunnel"}'
query_prometheus "blackbox_probe_duration_seconds" 'probe_duration_seconds{job=~"cloud-blackbox-http-through-tunnel|cloud-blackbox-tcp-through-tunnel|cloud-blackbox-dns-through-tunnel"}'
query_prometheus "blackbox_http_status_code" 'probe_http_status_code{job="cloud-blackbox-http-through-tunnel"}'

query_prometheus "node_cpu_usage_percent" '100 - (avg by (instance, node, role) (rate(node_cpu_seconds_total{job=~"cloud-node-exporter|local-node-exporter-through-tunnel",mode="idle"}[5m])) * 100)'
query_prometheus "node_memory_used_percent" '100 * (1 - (node_memory_MemAvailable_bytes{job=~"cloud-node-exporter|local-node-exporter-through-tunnel"} / node_memory_MemTotal_bytes{job=~"cloud-node-exporter|local-node-exporter-through-tunnel"}))'
query_prometheus "node_filesystem_used_percent" '100 * (1 - (node_filesystem_avail_bytes{job=~"cloud-node-exporter|local-node-exporter-through-tunnel",fstype!~"tmpfs|overlay|squashfs|devtmpfs"} / node_filesystem_size_bytes{job=~"cloud-node-exporter|local-node-exporter-through-tunnel",fstype!~"tmpfs|overlay|squashfs|devtmpfs"}))'

query_prometheus "node_uname_info" \
  'node_uname_info{job=~"cloud-node-exporter|local-node-exporter-through-tunnel"}'

query_prometheus "node_load1" \
  'node_load1{job=~"cloud-node-exporter|local-node-exporter-through-tunnel"}'

query_prometheus "node_load5" \
  'node_load5{job=~"cloud-node-exporter|local-node-exporter-through-tunnel"}'

query_prometheus "node_load15" \
  'node_load15{job=~"cloud-node-exporter|local-node-exporter-through-tunnel"}'

query_prometheus "node_memory_available_bytes" \
  'node_memory_MemAvailable_bytes{job=~"cloud-node-exporter|local-node-exporter-through-tunnel"}'

query_prometheus "node_memory_total_bytes" \
  'node_memory_MemTotal_bytes{job=~"cloud-node-exporter|local-node-exporter-through-tunnel"}'

query_prometheus "node_filesystem_available_bytes" \
  'node_filesystem_avail_bytes{job=~"cloud-node-exporter|local-node-exporter-through-tunnel",mountpoint="/",fstype!~"tmpfs|overlay|squashfs|devtmpfs"}'

query_prometheus "node_filesystem_size_bytes" \
  'node_filesystem_size_bytes{job=~"cloud-node-exporter|local-node-exporter-through-tunnel",mountpoint="/",fstype!~"tmpfs|overlay|squashfs|devtmpfs"}'

query_prometheus "node_filesystem_readonly" \
  'node_filesystem_readonly{job=~"cloud-node-exporter|local-node-exporter-through-tunnel",mountpoint="/"}'

query_prometheus "snmp_if_oper_status" 'ifOperStatus{job="cloud-snmp-network-devices-through-tunnel"}'
query_prometheus "snmp_if_admin_status" 'ifAdminStatus{job="cloud-snmp-network-devices-through-tunnel"}'
query_prometheus "snmp_if_in_errors_rate_5m" 'rate(ifInErrors{job="cloud-snmp-network-devices-through-tunnel"}[5m])'
query_prometheus "snmp_if_out_errors_rate_5m" 'rate(ifOutErrors{job="cloud-snmp-network-devices-through-tunnel"}[5m])'
query_prometheus "snmp_if_in_discards_rate_5m" 'rate(ifInDiscards{job="cloud-snmp-network-devices-through-tunnel"}[5m])'
query_prometheus "snmp_if_out_discards_rate_5m" 'rate(ifOutDiscards{job="cloud-snmp-network-devices-through-tunnel"}[5m])'
query_prometheus "snmp_sys_uptime" 'sysUpTime{job="cloud-snmp-network-devices-through-tunnel"}'

cat > "${OUTPUT_DIR}/README.txt" <<README
Cloud Prometheus snapshot generated at ${TIMESTAMP}.

This directory contains JSON responses from the Prometheus HTTP API.
Source Prometheus: ${PROMETHEUS_URL}
Runtime location: AWS monitoring EC2
README

echo "[OK] Cloud Prometheus snapshot exported to: $OUTPUT_DIR"
ls -lah "$OUTPUT_DIR"
