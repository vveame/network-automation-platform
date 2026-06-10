#!/usr/bin/env bash
set -euo pipefail

# Enable/repair NAT-instance behavior on the AWS EC2 tunnel gateway.
#
# Purpose:
#   The private monitoring EC2 has no public IP and the project avoids AWS NAT Gateway
#   to reduce cost. The public EC2 tunnel gateway is therefore also used as a small
#   NAT/routing instance for the monitoring subnet.
#
# Expected egress path:
#   Private monitoring EC2
#       -> monitoring route table 0.0.0.0/0
#       -> AWS EC2 tunnel gateway ENI
#       -> iptables MASQUERADE
#       -> Internet Gateway
#       -> internet
#
# This script is useful for existing EC2 tunnel gateway instances because Terraform
# user-data only runs at instance creation time.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="${TF_DIR:-$REPO_ROOT/cloud/terraform/environments/dev}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/pfe-aws-tunnel}"
SSH_USER="${SSH_USER:-ec2-user}"
MONITORING_SUBNET_CIDR="${MONITORING_SUBNET_CIDR:-10.50.30.0/24}"

cd "$TF_DIR"

TGW_PUBLIC_IP="$(terraform output -raw tunnel_gateway_public_ip)"

if [ -z "$TGW_PUBLIC_IP" ]; then
  echo "[ERROR] tunnel_gateway_public_ip Terraform output is empty."
  exit 1
fi

echo "[INFO] Tunnel gateway public IP: $TGW_PUBLIC_IP"
echo "[INFO] Monitoring subnet CIDR: $MONITORING_SUBNET_CIDR"
echo "[INFO] SSH key: $SSH_KEY"

ssh \
  -o IdentitiesOnly=yes \
  -i "$SSH_KEY" \
  "$SSH_USER@$TGW_PUBLIC_IP" \
  "MONITORING_SUBNET_CIDR='$MONITORING_SUBNET_CIDR' bash -s" <<'REMOTE'
set -euo pipefail

DEFAULT_IFACE="$(ip route show default | awk '{print $5; exit}')"

if [ -z "$DEFAULT_IFACE" ]; then
  echo "[ERROR] Could not detect default internet interface on tunnel gateway."
  exit 1
fi

echo "[INFO] Default internet interface: $DEFAULT_IFACE"
echo "[INFO] Monitoring subnet CIDR: $MONITORING_SUBNET_CIDR"

sudo tee /etc/sysctl.d/99-pfe-monitoring-nat.conf >/dev/null <<'SYSCTL'
# PFE monitoring subnet NAT egress through EC2 tunnel gateway.
net.ipv4.ip_forward = 1
SYSCTL

sudo sysctl --system >/dev/null
sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null

# NAT monitoring subnet to the tunnel gateway public internet interface.
sudo iptables -t nat -C POSTROUTING -s "$MONITORING_SUBNET_CIDR" -o "$DEFAULT_IFACE" -j MASQUERADE 2>/dev/null || \
sudo iptables -t nat -A POSTROUTING -s "$MONITORING_SUBNET_CIDR" -o "$DEFAULT_IFACE" -j MASQUERADE

# Allow monitoring subnet outbound traffic through the tunnel gateway.
sudo iptables -C FORWARD -s "$MONITORING_SUBNET_CIDR" -o "$DEFAULT_IFACE" -j ACCEPT 2>/dev/null || \
sudo iptables -I FORWARD 1 -s "$MONITORING_SUBNET_CIDR" -o "$DEFAULT_IFACE" -j ACCEPT

# Allow return traffic from the internet back to the monitoring subnet.
sudo iptables -C FORWARD -d "$MONITORING_SUBNET_CIDR" -i "$DEFAULT_IFACE" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
sudo iptables -I FORWARD 1 -d "$MONITORING_SUBNET_CIDR" -i "$DEFAULT_IFACE" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Keep WireGuard/VPC forwarding rules present.
sudo iptables -C FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
sudo iptables -I FORWARD 1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

sudo iptables -C FORWARD -i wg0 -d 10.50.0.0/16 -j ACCEPT 2>/dev/null || \
sudo iptables -I FORWARD 1 -i wg0 -d 10.50.0.0/16 -j ACCEPT

sudo iptables -C FORWARD -o wg0 -s 10.50.0.0/16 -j ACCEPT 2>/dev/null || \
sudo iptables -I FORWARD 1 -o wg0 -s 10.50.0.0/16 -j ACCEPT

if command -v service >/dev/null 2>&1; then
  sudo service iptables save || true
fi

if [ -d /etc/sysconfig ]; then
  sudo iptables-save | sudo tee /etc/sysconfig/iptables >/dev/null
fi

echo "[OK] Monitoring subnet NAT egress rules are active."

echo
echo "[INFO] NAT POSTROUTING rules:"
sudo iptables -t nat -L POSTROUTING -n -v --line-numbers

echo
echo "[INFO] FORWARD rules:"
sudo iptables -L FORWARD -n -v --line-numbers | head -40
REMOTE
