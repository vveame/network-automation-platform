#!/bin/sh

# Restrict SSH/admin access to the DevOps server only.
# Applied on SSH-managed infrastructure nodes:
# - FRR routers
# - internal OVS switches
# - DMZ-OVS-3
#
# ICMP from DevOps is allowed for management readiness checks.

set -e

DEVOPS_SERVER="10.200.0.10"
SSH_PORT="22"
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

# Drop SSH from all other sources.
iptables -A "$CHAIN" -p tcp --dport "$SSH_PORT" -j DROP

# Do not affect other non-SSH traffic.
iptables -A "$CHAIN" -j RETURN

echo "[INFO] SSH/admin restriction applied."
iptables -L "$CHAIN" -v -n --line-numbers