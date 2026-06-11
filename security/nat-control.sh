#!/bin/sh
set -eu

# NAT control script for EdgeRouter-VPNGateway.
#
# Modes:
#   direct = EdgeRouter has its own WAN interface connected to GNS3 NAT node.
#   devops = old fallback, DevOps provides underlay NAT.
#
# In direct mode, this script brings the WAN interface up, requests DHCP,
# enables forwarding, and applies NAT on the EdgeRouter WAN interface.

UNDERLAY_MODE="${UNDERLAY_MODE:-direct}"

if [ "$UNDERLAY_MODE" = "direct" ]; then
  EXTERNAL_IFACE="${WAN_IF:-eth3}"
  ENABLE_DHCP="${ENABLE_DHCP:-true}"
else
  EXTERNAL_IFACE="${EXTERNAL_IFACE:-eth3}"
  ENABLE_DHCP="${ENABLE_DHCP:-false}"
fi

NAT_SOURCE_CIDRS="${NAT_SOURCE_CIDRS:-192.168.0.0/16 172.16.50.0/24}"

echo "[NAT] Applying NAT control on EdgeRouter..."
echo "[NAT] Underlay mode: $UNDERLAY_MODE"
echo "[NAT] External/WAN interface: $EXTERNAL_IFACE"
echo "[NAT] Source CIDRs: $NAT_SOURCE_CIDRS"

if ! ip link show "$EXTERNAL_IFACE" >/dev/null 2>&1; then
  echo "[NAT][ERROR] Interface not found: $EXTERNAL_IFACE"
  echo "[NAT][ERROR] Check GNS3 NAT link and EdgeRouter interface name."
  exit 1
fi

ip link set "$EXTERNAL_IFACE" up || true

if [ "$ENABLE_DHCP" = "true" ]; then
  echo "[NAT] Requesting DHCP on $EXTERNAL_IFACE..."
  if command -v udhcpc >/dev/null 2>&1; then
    udhcpc -i "$EXTERNAL_IFACE" -q -n || echo "[NAT][WARN] DHCP failed or already configured."
  else
    echo "[NAT][WARN] udhcpc not found. Skipping DHCP."
  fi
fi

echo "[NAT] Enabling IPv4 forwarding..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null || true

# Idempotent NAT chain.
iptables -t nat -N PFE_EDGE_NAT 2>/dev/null || true
iptables -t nat -F PFE_EDGE_NAT

iptables -t nat -C POSTROUTING -j PFE_EDGE_NAT 2>/dev/null || \
  iptables -t nat -A POSTROUTING -j PFE_EDGE_NAT

for CIDR in $NAT_SOURCE_CIDRS; do
  iptables -t nat -A PFE_EDGE_NAT -s "$CIDR" -o "$EXTERNAL_IFACE" -j MASQUERADE
done

# Idempotent forwarding chain.
iptables -N PFE_EDGE_FORWARD 2>/dev/null || true
iptables -F PFE_EDGE_FORWARD

iptables -C FORWARD -j PFE_EDGE_FORWARD 2>/dev/null || \
  iptables -I FORWARD 1 -j PFE_EDGE_FORWARD

iptables -A PFE_EDGE_FORWARD -i "$EXTERNAL_IFACE" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

for CIDR in $NAT_SOURCE_CIDRS; do
  iptables -A PFE_EDGE_FORWARD -s "$CIDR" -o "$EXTERNAL_IFACE" -j ACCEPT
done

echo "[NAT][OK] EdgeRouter NAT is active."

echo
echo "[NAT] Interface:"
ip -br addr show "$EXTERNAL_IFACE" || true

echo
echo "[NAT] Routes:"
ip route | grep -E "default|10.50|10.255" || true

echo
echo "[NAT] NAT rules:"
iptables -t nat -L PFE_EDGE_NAT -n -v || true
