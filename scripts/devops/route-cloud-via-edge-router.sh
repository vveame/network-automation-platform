#!/usr/bin/env bash
set -euo pipefail

# Route DevOps cloud/VPC traffic through EdgeRouter-VPNGateway.
#
# Purpose:
#   After the EdgeRouter-based WireGuard tunnel is validated, DevOps should reach
#   private AWS networks through EdgeRouter, not through a local DevOps wg0 tunnel.
#
# Path:
#   DevOps VM 10.200.0.10
#       -> EdgeRouter-VPNGateway 10.200.0.30
#       -> WireGuard tunnel
#       -> AWS EC2 tunnel gateway
#       -> AWS VPC 10.50.0.0/16
#
# This script installs a runtime route. It is safe to re-run.
#
# Defaults:
#   AWS_VPC_CIDR=10.50.0.0/16
#   EDGE_OOB_IP=10.200.0.30

AWS_VPC_CIDR="${AWS_VPC_CIDR:-10.50.0.0/16}"
EDGE_OOB_IP="${EDGE_OOB_IP:-10.200.0.30}"

if [ "$(id -u)" -ne 0 ]; then
  exec sudo AWS_VPC_CIDR="$AWS_VPC_CIDR" EDGE_OOB_IP="$EDGE_OOB_IP" "$0" "$@"
fi

OOB_IF="${OOB_IF:-$(ip route get "$EDGE_OOB_IP" | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1); exit}')}"

if [ -z "$OOB_IF" ]; then
  echo "[ERROR] Could not detect OOB interface used to reach $EDGE_OOB_IP."
  exit 1
fi

echo "[INFO] AWS VPC CIDR: $AWS_VPC_CIDR"
echo "[INFO] EdgeRouter OOB IP: $EDGE_OOB_IP"
echo "[INFO] DevOps OOB interface: $OOB_IF"

ip route replace "$AWS_VPC_CIDR" via "$EDGE_OOB_IP" dev "$OOB_IF"

echo "[OK] DevOps route installed:"
ip route get "$(echo "$AWS_VPC_CIDR" | cut -d/ -f1)" || true
ip route | grep "$AWS_VPC_CIDR" || true
