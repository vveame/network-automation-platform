#!/bin/sh

# Management VLAN protection on Distribution FRR routers.
#
# Policy:
# - Management VLAN can reach infrastructure management loopbacks.
# - Infrastructure loopbacks can reply to the Management VLAN.
# - Management VLAN can initiate traffic to user VLANs if needed.
# - User VLANs cannot initiate traffic toward the Management VLAN.
#
# Important:
# Do not drop ctstate INVALID here. Distribution routers use ECMP/asymmetric
# routed paths, and conntrack may mark legitimate return traffic as INVALID.

set -e

USER_VLAN_10="192.168.10.0/24"
USER_VLAN_20="192.168.20.0/24"
MGMT_VLAN="192.168.99.0/24"
FRR_MGMT_LOOPBACKS="10.255.0.0/24"

CHAIN="PFE_MGMT_FORWARD"

echo "[INFO] Applying Management VLAN protection..."

iptables -N "$CHAIN" 2>/dev/null || true
iptables -F "$CHAIN"

while iptables -D FORWARD -j "$CHAIN" 2>/dev/null; do
  :
done

iptables -I FORWARD 1 -j "$CHAIN"

# Allow already established return traffic when conntrack can track it.
iptables -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow DevOps/Management VLAN to reach routed FRR management loopbacks.
iptables -A "$CHAIN" -s "$MGMT_VLAN" -d "$FRR_MGMT_LOOPBACKS" -j ACCEPT

# Allow FRR management loopbacks to reply to Management VLAN.
iptables -A "$CHAIN" -s "$FRR_MGMT_LOOPBACKS" -d "$MGMT_VLAN" -j ACCEPT

# Management VLAN can initiate toward user VLANs if needed for admin/testing.
iptables -A "$CHAIN" -s "$MGMT_VLAN" -d "$USER_VLAN_10" -j ACCEPT
iptables -A "$CHAIN" -s "$MGMT_VLAN" -d "$USER_VLAN_20" -j ACCEPT

# User VLANs cannot initiate traffic to Management VLAN.
iptables -A "$CHAIN" -s "$USER_VLAN_10" -d "$MGMT_VLAN" -j DROP
iptables -A "$CHAIN" -s "$USER_VLAN_20" -d "$MGMT_VLAN" -j DROP

# Do not affect unrelated forwarding traffic.
iptables -A "$CHAIN" -j RETURN

echo "[INFO] Management VLAN protection applied."
iptables -L "$CHAIN" -v -n --line-numbers