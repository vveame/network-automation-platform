#!/bin/sh

# Management VLAN protection on Distribution FRR routers.

set -e

USER_VLAN_10="192.168.10.0/24"
USER_VLAN_20="192.168.20.0/24"
MGMT_VLAN="192.168.99.0/24"

echo "[INFO] Applying Management VLAN protection..."

# Remove old custom rules if the script was already applied.
iptables -D FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -m conntrack --ctstate INVALID -j DROP 2>/dev/null || true
iptables -D FORWARD -s "$MGMT_VLAN" -d "$USER_VLAN_10" -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -s "$MGMT_VLAN" -d "$USER_VLAN_20" -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -s "$USER_VLAN_10" -d "$MGMT_VLAN" -j DROP 2>/dev/null || true
iptables -D FORWARD -s "$USER_VLAN_20" -d "$MGMT_VLAN" -j DROP 2>/dev/null || true

# Allow replies to existing connections FIRST.
iptables -I FORWARD 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Drop invalid packets
iptables -I FORWARD 2 -m conntrack --ctstate INVALID -j DROP

# Allow Management VLAN to initiate traffic to user VLANs.
iptables -A FORWARD -s "$MGMT_VLAN" -d "$USER_VLAN_10" -j ACCEPT
iptables -A FORWARD -s "$MGMT_VLAN" -d "$USER_VLAN_20" -j ACCEPT

# Block user VLANs from initiating traffic to Management VLAN.
iptables -A FORWARD -s "$USER_VLAN_10" -d "$MGMT_VLAN" -j DROP
iptables -A FORWARD -s "$USER_VLAN_20" -d "$MGMT_VLAN" -j DROP

echo "[INFO] Management VLAN protection applied."
iptables -L FORWARD -v -n --line-numbers