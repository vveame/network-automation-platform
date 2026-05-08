#!/bin/sh

# Restrict SSH/admin access to DevOps server only.

# Run inside each managed node:
# - Dist-FRR-1
# - Dist-FRR-2
# - Core-FRR-1
# - Core-FRR-2
# - EdgeRouter-VPNGateway
# - OVS nodes if SSH is enabled there

set -e

DEVOPS_SERVER="192.168.99.10"
SSH_PORT="22"

echo "[INFO] Applying SSH/admin access restriction..."

# Remove old rules to avoid duplicates
iptables -D INPUT -p tcp --dport "$SSH_PORT" -s "$DEVOPS_SERVER" -j ACCEPT 2>/dev/null || true
iptables -D INPUT -p tcp --dport "$SSH_PORT" -j DROP 2>/dev/null || true

# Allow established traffic first
iptables -D INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
iptables -I INPUT 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH only from DevOps server
iptables -A INPUT -p tcp --dport "$SSH_PORT" -s "$DEVOPS_SERVER" -j ACCEPT

# Drop SSH from all other sources
iptables -A INPUT -p tcp --dport "$SSH_PORT" -j DROP

echo "[INFO] SSH/admin restriction applied."
iptables -L INPUT -v -n --line-numbers