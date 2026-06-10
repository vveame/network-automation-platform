#!/bin/sh
set -eu

# Prepare and start WireGuard on EdgeRouter-VPNGateway.
# Real keys and real wg0.conf must remain outside Git.

WG_DIR="/etc/wireguard"
WG_CONF="$WG_DIR/wg0.conf"

mkdir -p "$WG_DIR"
chmod 700 "$WG_DIR"

sysctl -w net.ipv4.ip_forward=1 || true

if ! command -v wg >/dev/null 2>&1; then
  echo "[ERROR] wg command not found."
  echo "[ERROR] Rebuild docker/frr-ssh image with wireguard-tools installed."
  exit 1
fi

if ! command -v wg-quick >/dev/null 2>&1; then
  echo "[ERROR] wg-quick command not found."
  echo "[ERROR] Rebuild docker/frr-ssh image with wireguard-tools installed."
  exit 1
fi

if [ ! -f "$WG_CONF" ]; then
  echo "[WARN] $WG_CONF does not exist yet."
  echo "[INFO] Copy frr/wireguard/edge-router-wg0.conf.example to $WG_CONF and replace placeholders."
  exit 0
fi

chmod 600 "$WG_CONF"

echo "[INFO] WireGuard tools found:"
wg --version || true

echo "[INFO] Restarting wg0..."
wg-quick down wg0 2>/dev/null || true
wg-quick up wg0

echo "[INFO] Current WireGuard status:"
wg show || true
