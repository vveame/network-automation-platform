#!/bin/sh

set -e

echo "[BOOT] Starting DNS Server container..."

if [ -f /opt/pfe/host-ip.sh ]; then
  echo "[BOOT] Applying host IP configuration..."
  sh /opt/pfe/host-ip.sh
else
  echo "[ERROR] /opt/pfe/host-ip.sh not found."
  ls -l /opt/pfe || true
  sleep infinity
fi

echo "[BOOT] Verifying DNS network..."
ip -br addr
ip route

echo "[BOOT] Starting DNS service..."
exec named -g -c /etc/bind/named.conf