#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo " GNS3 Host Status Check"
echo "========================================"

echo
echo "[INFO] Host:"
hostname

echo
echo "[INFO] Current user:"
whoami

echo
echo "[INFO] Docker version:"
docker --version

echo
echo "[INFO] GNS3 containers:"
docker ps -a \
  --filter "name=GNS3" \
  --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" || true

echo
echo "[INFO] Running GNS3 containers count:"
docker ps \
  --filter "name=GNS3" \
  --format "{{.Names}}" | wc -l

echo
echo "[INFO] Exited GNS3 containers count:"
docker ps -a \
  --filter "name=GNS3" \
  --filter "status=exited" \
  --format "{{.Names}}" | wc -l

echo
echo "[OK] GNS3 host status check completed."