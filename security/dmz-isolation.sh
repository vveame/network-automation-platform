#!/bin/sh

# DMZ isolation rules on EdgeRouter-VPNGateway.
#
# Policy:
# - DMZ is isolated from internal networks.
# - Internal networks may access only explicit DMZ services.
# - DevOps server may manage DMZ-OVS through EdgeRouter.
# - DMZ-OVS may send narrow ICMP warm-up to DevOps server.

set -e

INTERNAL_NET="192.168.0.0/16"
DEVOPS_SERVER="192.168.99.10"

DMZ_NET="172.16.50.0/24"
DMZ_OVS="172.16.50.3"
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

iptables -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A "$CHAIN" -m conntrack --ctstate INVALID -j DROP

# DevOps can SSH to DMZ-OVS.
iptables -A "$CHAIN" -s "$DEVOPS_SERVER" -d "$DMZ_OVS" -p tcp --dport 22 -j ACCEPT

# DevOps can ping DMZ-OVS for troubleshooting.
iptables -A "$CHAIN" -s "$DEVOPS_SERVER" -d "$DMZ_OVS" -p icmp -j ACCEPT

# DMZ-OVS can send warm-up ping to DevOps.
iptables -A "$CHAIN" -s "$DMZ_OVS" -d "$DEVOPS_SERVER" -p icmp -j ACCEPT

# Web service.
iptables -A "$CHAIN" -s "$INTERNAL_NET" -d "$WEB_SERVER" -p tcp --dport 80 -j ACCEPT
iptables -A "$CHAIN" -s "$INTERNAL_NET" -d "$WEB_SERVER" -p tcp --dport 443 -j ACCEPT

# DNS service.
iptables -A "$CHAIN" -s "$INTERNAL_NET" -d "$DNS_SERVER" -p udp --dport 53 -j ACCEPT
iptables -A "$CHAIN" -s "$INTERNAL_NET" -d "$DNS_SERVER" -p tcp --dport 53 -j ACCEPT

# DMZ cannot initiate access to internal networks except explicit rules above.
iptables -A "$CHAIN" -s "$DMZ_NET" -d "$INTERNAL_NET" -j DROP

# Internal networks cannot access DMZ except explicit rules above.
iptables -A "$CHAIN" -s "$INTERNAL_NET" -d "$DMZ_NET" -j DROP

iptables -A "$CHAIN" -j RETURN

echo "[INFO] DMZ isolation rules applied."
iptables -L "$CHAIN" -v -n --line-numbers