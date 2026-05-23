#!/bin/sh

# Generic Out-of-Band management interface configuration.
#
# This script configures a dedicated OOB interface.
# The OOB interface must NOT be added to OVS br0 and must NOT participate in the production/data-plane topology.

set -e

if [ ! -f /etc/local/oob-mgmt.env ]; then
  echo "[ERROR] Missing /etc/local/oob-mgmt.env"
  exit 1
fi

. /etc/local/oob-mgmt.env

OOB_IFACE="$(printf '%s' "$OOB_IFACE" | tr -d '\r')"
OOB_IP="$(printf '%s' "$OOB_IP" | tr -d '\r')"
OOB_MAC="$(printf '%s' "$OOB_MAC" | tr -d '\r')"

echo "[INFO] Configuring OOB management interface..."
echo "[INFO] Interface: $OOB_IFACE"
echo "[INFO] IP: $OOB_IP"

if ! ip link show "$OOB_IFACE" >/dev/null 2>&1; then
  echo "[ERROR] Interface $OOB_IFACE does not exist."
  echo "[INFO] Available interfaces:"
  ip -br link
  exit 1
fi

ip link set "$OOB_IFACE" up

if [ -n "$OOB_MAC" ]; then
  ip link set "$OOB_IFACE" address "$OOB_MAC" 2>/dev/null || true
fi

ip addr flush dev "$OOB_IFACE" 2>/dev/null || true
ip addr add "$OOB_IP" dev "$OOB_IFACE"

echo "[INFO] OOB management interface configured:"
ip -br addr show "$OOB_IFACE"