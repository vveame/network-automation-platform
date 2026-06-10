#!/usr/bin/env bash
set -euo pipefail

# Disable DevOps NAT underlay for EdgeRouter-VPNGateway.

EDGE_OOB_IP="${EDGE_OOB_IP:-10.200.0.30}"

if [ "$(id -u)" -ne 0 ]; then
  exec sudo EDGE_OOB_IP="$EDGE_OOB_IP" "$0" "$@"
fi

INTERNET_IF="$(ip route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1); exit}')"
OOB_IF="$(ip route get "$EDGE_OOB_IP" | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1); exit}')"

echo "[INFO] Removing DevOps NAT underlay rules for EdgeRouter $EDGE_OOB_IP"

iptables -t nat -D POSTROUTING -s "${EDGE_OOB_IP}/32" -o "$INTERNET_IF" -j MASQUERADE 2>/dev/null || true

iptables -D FORWARD -i "$OOB_IF" -o "$INTERNET_IF" -s "${EDGE_OOB_IP}/32" -j ACCEPT 2>/dev/null || true

iptables -D FORWARD -i "$INTERNET_IF" -o "$OOB_IF" -d "${EDGE_OOB_IP}/32" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true

iptables -t mangle -D FORWARD -s "${EDGE_OOB_IP}/32" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true

iptables -t mangle -D FORWARD -d "${EDGE_OOB_IP}/32" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true

if command -v netfilter-persistent >/dev/null 2>&1; then
  netfilter-persistent save || true
elif [ -d /etc/iptables ]; then
  iptables-save > /etc/iptables/rules.v4
fi

echo "[OK] DevOps NAT underlay rules removed."
