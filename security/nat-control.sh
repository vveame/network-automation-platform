#!/bin/sh

# NAT control script for EdgeRouter-VPNGateway

set -e

INTERNAL_NET="192.168.0.0/16"
DMZ_NET="172.16.50.0/24"
EXTERNAL_IFACE="${EXTERNAL_IFACE:-eth3}"

echo "[INFO] Applying NAT control on EdgeRouter..."
echo "[INFO] External interface: $EXTERNAL_IFACE"

# Enable IPv4 forwarding
sysctl -w net.ipv4.ip_forward=1

# Remove previous NAT rules to avoid duplicates
iptables -t nat -D POSTROUTING -s "$INTERNAL_NET" -o "$EXTERNAL_IFACE" -j MASQUERADE 2>/dev/null || true
iptables -t nat -D POSTROUTING -s "$DMZ_NET" -o "$EXTERNAL_IFACE" -j MASQUERADE 2>/dev/null || true

# Apply NAT only on the external-facing interface
iptables -t nat -A POSTROUTING -s "$INTERNAL_NET" -o "$EXTERNAL_IFACE" -j MASQUERADE
iptables -t nat -A POSTROUTING -s "$DMZ_NET" -o "$EXTERNAL_IFACE" -j MASQUERADE

echo "[INFO] NAT rules applied."
iptables -t nat -L -v -n --line-numbers