#!/bin/sh

set -e

echo "[BOOT] Starting Web Server container..."

if [ -f /etc/local/host-ip.sh ]; then
  echo "[BOOT] Applying host IP configuration..."
  sh /etc/local/host-ip.sh
else
  echo "[BOOT] No /etc/local/host-ip.sh found."
fi

echo "[BOOT] Starting Nginx..."
exec nginx -g "daemon off;"