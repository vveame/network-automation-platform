#!/bin/sh
# Restrict SSH/admin access to the DevOps server only.
# Applied on SSH-managed infrastructure nodes:
# - FRR routers
# - internal OVS switches
# - DMZ-OVS-3
#
# ICMP from DevOps is allowed for management readiness checks.
# SNMPv3 is allowed only from DevOps for monitored FRR nodes.

set -e

DEVOPS_SERVER="10.200.0.10"
SSH_PORT="22"
SNMP_PORT="1161"
CHAIN="PFE_ADMIN_INPUT"

echo "[INFO] Applying SSH/admin access restriction..."

iptables -N "$CHAIN" 2>/dev/null || true
iptables -F "$CHAIN"

while iptables -D INPUT -j "$CHAIN" 2>/dev/null; do
    :
done

iptables -I INPUT 1 -j "$CHAIN"

# Always allow loopback and return traffic.
iptables -A "$CHAIN" -i lo -j ACCEPT
iptables -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow ICMP from DevOps for readiness/troubleshooting.
iptables -A "$CHAIN" -p icmp -s "$DEVOPS_SERVER" -j ACCEPT

# Allow SSH only from DevOps server.
iptables -A "$CHAIN" -p tcp --dport "$SSH_PORT" -s "$DEVOPS_SERVER" -j ACCEPT

# Allow SNMPv3 monitoring only from DevOps server.
iptables -A "$CHAIN" -p udp --dport "$SNMP_PORT" -s "$DEVOPS_SERVER" -j ACCEPT

# Drop SSH/SNMP from all other sources.
iptables -A "$CHAIN" -p tcp --dport "$SSH_PORT" -j DROP
iptables -A "$CHAIN" -p udp --dport "$SNMP_PORT" -j DROP

# Do not affect other traffic.
iptables -A "$CHAIN" -j RETURN

echo "[INFO] SSH/admin/SNMP restriction applied."
iptables -L "$CHAIN" -v -n --line-numbers
