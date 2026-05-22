#!/bin/sh

set -e

echo "[BOOT] Starting Web Server container..."

if [ -f /opt/pfe/host-ip.sh ]; then
  echo "[BOOT] Applying host IP configuration..."
  sh /opt/pfe/host-ip.sh
else
  echo "[ERROR] /opt/pfe/host-ip.sh not found."
  ls -l /opt/pfe || true
  sleep infinity
fi

echo "[BOOT] Verifying Web network..."
ip -br addr || ip addr
ip route

echo "[BOOT] Starting Nginx..."
exec nginx -g "daemon off;"