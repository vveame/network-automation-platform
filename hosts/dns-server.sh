#!/bin/sh

set -e

echo "[INFO] Configuring DNS Server IP..."

for i in 1 2 3 4 5 6 7 8 9 10; do
  if ip link show eth0 >/dev/null 2>&1; then
    echo "[OK] eth0 found."
    break
  fi
  echo "[WAIT] eth0 not ready yet..."
  sleep 1
done

if ! ip link show eth0 >/dev/null 2>&1; then
  echo "[ERROR] eth0 does not exist after waiting."
  ip -br link || true
  exit 1
fi

ip link set eth0 up
ip addr flush dev eth0 2>/dev/null || true
ip addr add 172.16.50.20/24 dev eth0
ip route replace default via 172.16.50.1

ip -br addr || ip addr
ip route