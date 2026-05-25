#!/bin/sh

# DMZ isolation rules on EdgeRouter-VPNGateway.
#
# Policy:
# - DMZ is isolated from internal networks.
# - Internal networks may access only explicit DMZ services.
# - DevOps OOB may access only explicit DMZ validation services.
# - OOB-to-DMZ is not open by default.
# - DMZ cannot initiate access to internal or OOB networks.

set -e

INTERNAL_NET="192.168.0.0/16"
OOB_NET="10.200.0.0/24"
DEVOPS_OOB_SERVER="10.200.0.10"

DMZ_NET="172.16.50.0/24"
DMZ_OVS_OOB="10.200.0.33"
WEB_SERVER="172.16.50.10"
DNS_SERVER="172.16.50.20"

CHAIN="PFE_DMZ_FORWARD"

echo "[INFO] Applying DMZ isolation rules..."

iptables -N "$CHAIN" 2>/dev/null || true
iptables -F "$CHAIN"

while iptables -D FORWARD -j "$CHAIN" 2>/dev/null; do
  :
done

iptables -I FORWARD 1 -j "$CHAIN"

# Always allow established return traffic.
iptables -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A "$CHAIN" -m conntrack --ctstate INVALID -j DROP

# DevOps OOB can validate DMZ Web service.
iptables -A "$CHAIN" -s "$DEVOPS_OOB_SERVER" -d "$WEB_SERVER" -p tcp --dport 80 -j ACCEPT
iptables -A "$CHAIN" -s "$DEVOPS_OOB_SERVER" -d "$WEB_SERVER" -p tcp --dport 443 -j ACCEPT

# DevOps OOB can validate DMZ DNS service.
iptables -A "$CHAIN" -s "$DEVOPS_OOB_SERVER" -d "$DNS_SERVER" -p udp --dport 53 -j ACCEPT
iptables -A "$CHAIN" -s "$DEVOPS_OOB_SERVER" -d "$DNS_SERVER" -p tcp --dport 53 -j ACCEPT

# Block any other OOB-to-DMZ traffic.
iptables -A "$CHAIN" -s "$OOB_NET" -d "$DMZ_NET" -j DROP

# Internal networks can access only explicit DMZ services.
iptables -A "$CHAIN" -s "$INTERNAL_NET" -d "$WEB_SERVER" -p tcp --dport 80 -j ACCEPT
iptables -A "$CHAIN" -s "$INTERNAL_NET" -d "$WEB_SERVER" -p tcp --dport 443 -j ACCEPT

iptables -A "$CHAIN" -s "$INTERNAL_NET" -d "$DNS_SERVER" -p udp --dport 53 -j ACCEPT
iptables -A "$CHAIN" -s "$INTERNAL_NET" -d "$DNS_SERVER" -p tcp --dport 53 -j ACCEPT

# DMZ cannot initiate access to internal or OOB networks.
iptables -A "$CHAIN" -s "$DMZ_NET" -d "$INTERNAL_NET" -j DROP
iptables -A "$CHAIN" -s "$DMZ_NET" -d "$OOB_NET" -j DROP

# Internal networks cannot access DMZ except explicit allowed services above.
iptables -A "$CHAIN" -s "$INTERNAL_NET" -d "$DMZ_NET" -j DROP

iptables -A "$CHAIN" -j RETURN

echo "[INFO] DMZ isolation rules applied."
iptables -L "$CHAIN" -v -n --line-numbers