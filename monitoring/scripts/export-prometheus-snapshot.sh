#!/usr/bin/env bash
set -euo pipefail

# Export a Prometheus metrics snapshot.

# - This script generates temporary metrics outputs in the Jenkins/repo workspace.
# - S3 becomes the source of truth after upload.
# - /var/lib/pfe-dashboard is restored later by sync-dashboard-cache-from-s3.sh.

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

cat > "$OUTPUT_DIR/manifest.json" <<MANIFEST
{
  "project": "network-automation-platform",
  "source": "local-prometheus-baseline",
  "export_time_utc": "$TIMESTAMP",
  "prometheus_url": "$PROMETHEUS_URL",
  "generation_path": "$OUTPUT_DIR",
  "cache_model": "workspace_generated_s3_backed_dashboard_cache"
}
MANIFEST

query_prometheus "up" 'up'
query_prometheus "node_uname_info" 'node_uname_info'
query_prometheus "node_memory_available_bytes" 'node_memory_MemAvailable_bytes'
query_prometheus "node_memory_total_bytes" 'node_memory_MemTotal_bytes'
query_prometheus "node_filesystem_available_bytes" 'node_filesystem_avail_bytes{mountpoint="/"}'
query_prometheus "node_filesystem_size_bytes" 'node_filesystem_size_bytes{mountpoint="/"}'

cat > "$OUTPUT_DIR/README.txt" <<README
Prometheus snapshot generated at $TIMESTAMP.

This directory contains temporary JSON responses from the Prometheus HTTP API.

Correct workflow:
1. Generate metrics here in monitoring/outputs/latest.
2. Upload metrics to S3.
3. Sync latest metrics from S3 into /var/lib/pfe-dashboard/metrics/latest.
4. Flask dashboard reads the shared cache only.

S3 is the source of truth.
README

echo "[OK] Prometheus snapshot exported to: $OUTPUT_DIR"
ls -lah "$OUTPUT_DIR"
