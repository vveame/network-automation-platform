#!/usr/bin/env bash
set -euo pipefail

# Enable DevOps NAT underlay for EdgeRouter-VPNGateway.
#
# Purpose:
#   EdgeRouter-VPNGateway is the real local WireGuard tunnel endpoint.
#   However, in the student GNS3/VMware lab, the EdgeRouter does not have a
#   direct working public internet uplink.
#
#   This script allows EdgeRouter to reach the AWS EC2 tunnel gateway public IP
#   through the DevOps VM internet interface.
#
# Validated path:
#   EdgeRouter 10.200.0.30
#       -> DevOps OOB 10.200.0.10
#       -> DevOps NAT / VMware internet
#       -> AWS EC2 tunnel gateway UDP/51820
#
# Important:
#   DevOps is NOT the cloud gateway.
#   DevOps does NOT terminate WireGuard.
#   DevOps only provides internet underlay NAT.
#   WireGuard terminates on EdgeRouter-VPNGateway.

EDGE_OOB_IP="${EDGE_OOB_IP:-10.200.0.30}"

if [ "$(id -u)" -ne 0 ]; then
  exec sudo EDGE_OOB_IP="$EDGE_OOB_IP" "$0" "$@"
fi

INTERNET_IF="$(ip route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1); exit}')"
OOB_IF="$(ip route get "$EDGE_OOB_IP" | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1); exit}')"

if [ -z "$INTERNET_IF" ] || [ -z "$OOB_IF" ]; then
  echo "[ERROR] Could not detect INTERNET_IF or OOB_IF."
  echo "INTERNET_IF=$INTERNET_IF"
  echo "OOB_IF=$OOB_IF"
  exit 1
fi

echo "[INFO] EdgeRouter OOB IP: $EDGE_OOB_IP"
echo "[INFO] DevOps internet interface: $INTERNET_IF"
echo "[INFO] DevOps OOB interface: $OOB_IF"

cat > /etc/sysctl.d/99-pfe-edge-underlay-nat.conf <<SYSCTL
# PFE DevOps NAT underlay for EdgeRouter-VPNGateway.
# Allows EdgeRouter to reach AWS public WireGuard endpoint through DevOps.
net.ipv4.ip_forward = 1
SYSCTL

sysctl --system >/dev/null

iptables -t nat -C POSTROUTING -s "${EDGE_OOB_IP}/32" -o "$INTERNET_IF" -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -s "${EDGE_OOB_IP}/32" -o "$INTERNET_IF" -j MASQUERADE

iptables -C FORWARD -i "$OOB_IF" -o "$INTERNET_IF" -s "${EDGE_OOB_IP}/32" -j ACCEPT 2>/dev/null || \
iptables -I FORWARD 1 -i "$OOB_IF" -o "$INTERNET_IF" -s "${EDGE_OOB_IP}/32" -j ACCEPT

iptables -C FORWARD -i "$INTERNET_IF" -o "$OOB_IF" -d "${EDGE_OOB_IP}/32" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
iptables -I FORWARD 1 -i "$INTERNET_IF" -o "$OOB_IF" -d "${EDGE_OOB_IP}/32" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Avoid TCP stalls through nested GNS3/VMware/NAT paths.
iptables -t mangle -C FORWARD -s "${EDGE_OOB_IP}/32" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || \
iptables -t mangle -A FORWARD -s "${EDGE_OOB_IP}/32" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

iptables -t mangle -C FORWARD -d "${EDGE_OOB_IP}/32" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || \
iptables -t mangle -A FORWARD -d "${EDGE_OOB_IP}/32" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

if command -v netfilter-persistent >/dev/null 2>&1; then
  netfilter-persistent save || true
elif [ -d /etc/iptables ]; then
  iptables-save > /etc/iptables/rules.v4
else
  echo "[WARN] iptables persistence package not detected."
  echo "[WARN] Rules are active now, but may not survive a DevOps VM reboot."
fi

echo "[OK] DevOps NAT underlay enabled for EdgeRouter-VPNGateway."

echo
echo "[INFO] NAT rule:"
iptables -t nat -L POSTROUTING -n -v | grep "$EDGE_OOB_IP" || true

echo
echo "[INFO] Forward rules:"
iptables -L FORWARD -n -v --line-numbers | grep -E "$EDGE_OOB_IP|Chain FORWARD" || true

echo
echo "[INFO] MSS clamp rules:"
iptables -t mangle -L FORWARD -n -v --line-numbers | grep "$EDGE_OOB_IP" || true
