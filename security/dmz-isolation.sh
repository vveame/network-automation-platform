#!/bin/sh

# DMZ isolation rules on EdgeRouter-VPNGateway.

set -e

INTERNAL_NET="192.168.0.0/16"
DMZ_NET="172.16.50.0/24"
WEB_SERVER="172.16.50.10"
DNS_SERVER="172.16.50.20"

echo "[INFO] Applying DMZ isolation rules..."

# Remove old custom rules if the script was already applied.
iptables -D FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -m conntrack --ctstate INVALID -j DROP 2>/dev/null || true

iptables -D FORWARD -s "$INTERNAL_NET" -d "$WEB_SERVER" -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -s "$INTERNAL_NET" -d "$WEB_SERVER" -p tcp --dport 443 -j ACCEPT 2>/dev/null || true

iptables -D FORWARD -s "$INTERNAL_NET" -d "$DNS_SERVER" -p udp --dport 53 -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -s "$INTERNAL_NET" -d "$DNS_SERVER" -p tcp --dport 53 -j ACCEPT 2>/dev/null || true

iptables -D FORWARD -s "$DMZ_NET" -d "$INTERNAL_NET" -j DROP 2>/dev/null || true
iptables -D FORWARD -s "$INTERNAL_NET" -d "$DMZ_NET" -j DROP 2>/dev/null || true

# Allow return traffic first.
iptables -I FORWARD 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Drop invalid packets.
iptables -I FORWARD 2 -m conntrack --ctstate INVALID -j DROP

# Allow internal access to Web server services.
iptables -A FORWARD -s "$INTERNAL_NET" -d "$WEB_SERVER" -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -s "$INTERNAL_NET" -d "$WEB_SERVER" -p tcp --dport 443 -j ACCEPT

# Allow internal access to DNS server services.
iptables -A FORWARD -s "$INTERNAL_NET" -d "$DNS_SERVER" -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -s "$INTERNAL_NET" -d "$DNS_SERVER" -p tcp --dport 53 -j ACCEPT

# Block DMZ from initiating access to internal VLANs.
iptables -A FORWARD -s "$DMZ_NET" -d "$INTERNAL_NET" -j DROP

# Block other internal-to-DMZ traffic not explicitly allowed above.
iptables -A FORWARD -s "$INTERNAL_NET" -d "$DMZ_NET" -j DROP

echo "[INFO] DMZ isolation rules applied."
iptables -L FORWARD -v -n --line-numbers