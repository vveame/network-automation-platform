#!/bin/sh

# Management VLAN protection on Distribution FRR routers.
#
# Policy:
# - VLAN 99 remains an in-band management VLAN inside the production topology.
# - User VLANs cannot initiate traffic toward VLAN 99.
# - VLAN 99 may reach selected infrastructure validation targets.
# - Primary SSH/Ansible/Jenkins control now uses the OOB network 10.200.0.0/24.
#
# Important:
# Do not drop ctstate INVALID here. Distribution routers may use ECMP/asymmetric
# routed paths, and conntrack may mark legitimate return traffic as INVALID.

set -e

USER_VLAN_10="192.168.10.0/24"
USER_VLAN_20="192.168.20.0/24"
MGMT_VLAN="192.168.99.0/24"
FRR_LOOPBACKS="10.255.0.0/24"

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

# VLAN 99 can reach FRR loopbacks for in-band management/routing validation.
iptables -A "$CHAIN" -s "$MGMT_VLAN" -d "$FRR_LOOPBACKS" -j ACCEPT

# FRR loopbacks can reply to VLAN 99.
iptables -A "$CHAIN" -s "$FRR_LOOPBACKS" -d "$MGMT_VLAN" -j ACCEPT

# VLAN 99 can initiate toward user VLANs if needed for admin/testing.
iptables -A "$CHAIN" -s "$MGMT_VLAN" -d "$USER_VLAN_10" -j ACCEPT
iptables -A "$CHAIN" -s "$MGMT_VLAN" -d "$USER_VLAN_20" -j ACCEPT

# User VLANs cannot initiate traffic to VLAN 99.
iptables -A "$CHAIN" -s "$USER_VLAN_10" -d "$MGMT_VLAN" -j DROP
iptables -A "$CHAIN" -s "$USER_VLAN_20" -d "$MGMT_VLAN" -j DROP

# Do not affect unrelated forwarding traffic.
iptables -A "$CHAIN" -j RETURN

echo "[INFO] Management VLAN protection applied."
iptables -L "$CHAIN" -v -n --line-numbers