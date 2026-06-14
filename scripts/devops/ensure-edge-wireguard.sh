#!/usr/bin/env bash
set -euo pipefail

# Ensures the EdgeRouter-VPNGateway WireGuard tunnel is installed and running.
#
# Final hybrid model:
# - EdgeRouter eth3 = direct internet underlay through GNS3 NAT.
# - EdgeRouter eth4 = OOB management interface.
# - EdgeRouter wg0  = WireGuard tunnel to AWS.
#
# This script runs from the DevOps VM and manages the EdgeRouter over OOB SSH.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

EDGE_OOB_IP="${EDGE_OOB_IP:-10.200.0.30}"
AWS_VPC_CIDR="${AWS_VPC_CIDR:-10.50.0.0/16}"

WG_SECRET_FILE="${WG_SECRET_FILE:-$REPO_ROOT/secrets/edge-router-wg0.conf.secret}"
UNDERLAY_ENV_FILE="${UNDERLAY_ENV_FILE:-$REPO_ROOT/frr/wireguard/edge-underlay.env}"

REMOTE_WG_DIR="/etc/local/wireguard"
REMOTE_WG_CONF="$REMOTE_WG_DIR/wg0.conf"
REMOTE_UNDERLAY_ENV="$REMOTE_WG_DIR/edge-underlay.env"

SSH_OPTS=(
  -o BatchMode=yes
  -o StrictHostKeyChecking=no
  -o ConnectTimeout=10
)

echo "=================================================="
echo "Ensure EdgeRouter WireGuard"
echo "=================================================="
echo "[INFO] Repo: $REPO_ROOT"
echo "[INFO] EdgeRouter OOB IP: $EDGE_OOB_IP"
echo "[INFO] AWS VPC CIDR: $AWS_VPC_CIDR"
echo "[INFO] WireGuard secret: $WG_SECRET_FILE"
echo "[INFO] Underlay env: $UNDERLAY_ENV_FILE"
echo

if [ ! -f "$WG_SECRET_FILE" ]; then
  echo "[ERROR] Missing WireGuard secret file:"
  echo "        $WG_SECRET_FILE"
  echo
  echo "Create it locally from your EdgeRouter wg0 config."
  echo "Do not commit it."
  exit 1
fi

CURRENT_ENDPOINT="$(awk -F= '
  /^[[:space:]]*Endpoint[[:space:]]*=/ {
    gsub(/[[:space:]]/, "", $2)
    print $2
    exit
  }
' "$WG_SECRET_FILE" || true)"

if [ -z "$CURRENT_ENDPOINT" ]; then
  echo "[ERROR] No Endpoint found in $WG_SECRET_FILE"
  echo "[ERROR] The WireGuard config must contain:"
  echo "        Endpoint = <AWS_TUNNEL_GATEWAY_PUBLIC_IP>:51820"
  exit 1
fi

CURRENT_ENDPOINT_IP="${CURRENT_ENDPOINT%%:*}"

if echo "$CURRENT_ENDPOINT_IP" | grep -Eq '^10\.50\.'; then
  echo "[ERROR] Invalid WireGuard endpoint: $CURRENT_ENDPOINT"
  echo "[ERROR] This is an AWS private IP."
  echo "[ERROR] The endpoint must be the AWS tunnel gateway PUBLIC IP."
  exit 1
fi

if echo "$CURRENT_ENDPOINT_IP" | grep -Eq '^10\.'; then
  echo "[WARN] Endpoint is private-looking: $CURRENT_ENDPOINT"
  echo "[WARN] Continue only if this is intentional."
fi

if [ -f "$UNDERLAY_ENV_FILE" ]; then
  echo "[INFO] Found underlay environment file."
else
  echo "[WARN] Missing underlay env file:"
  echo "       $UNDERLAY_ENV_FILE"
  echo "[WARN] The EdgeRouter will rely only on the Endpoint inside wg0.conf."
fi

echo
echo "[INFO] Checking EdgeRouter OOB SSH..."
ssh "${SSH_OPTS[@]}" root@"$EDGE_OOB_IP" 'hostname; ip -br addr | grep -E "eth3|eth4|wg0" || true'

echo
echo "[INFO] Preparing remote WireGuard directory..."
ssh "${SSH_OPTS[@]}" root@"$EDGE_OOB_IP" "
set -e
mkdir -p '$REMOTE_WG_DIR' /etc/wireguard
chmod 700 '$REMOTE_WG_DIR' /etc/wireguard
"

echo
echo "[INFO] Copying WireGuard config to EdgeRouter..."
scp "${SSH_OPTS[@]}" "$WG_SECRET_FILE" "root@$EDGE_OOB_IP:$REMOTE_WG_CONF"

if [ -f "$UNDERLAY_ENV_FILE" ]; then
  echo "[INFO] Copying underlay env to EdgeRouter..."
  scp "${SSH_OPTS[@]}" "$UNDERLAY_ENV_FILE" "root@$EDGE_OOB_IP:$REMOTE_UNDERLAY_ENV"
fi

echo
echo "[INFO] Starting WireGuard on EdgeRouter..."
ssh "${SSH_OPTS[@]}" root@"$EDGE_OOB_IP" "
set -e

chmod 600 '$REMOTE_WG_CONF'
[ -f '$REMOTE_UNDERLAY_ENV' ] && chmod 600 '$REMOTE_UNDERLAY_ENV' || true

echo '[EDGE] Direct underlay route check:'
echo '[EDGE] eth3:'
ip -br addr show eth3 || true

echo
echo '[EDGE] Default route:'
ip route | grep default || true

echo
echo '[EDGE] Route to AWS public endpoint:'
ip route get '$CURRENT_ENDPOINT_IP' || true

echo
if [ -x /start-wireguard.sh ]; then
  echo '[EDGE] Using /start-wireguard.sh'
  /start-wireguard.sh
else
  echo '[EDGE][WARN] /start-wireguard.sh not found. Falling back to wg-quick.'
  cp '$REMOTE_WG_CONF' /etc/wireguard/wg0.conf
  chmod 600 /etc/wireguard/wg0.conf

  wg-quick down wg0 2>/dev/null || true
  wg-quick up wg0
  ip route replace '$AWS_VPC_CIDR' dev wg0 2>/dev/null || true
fi

echo
echo '[EDGE] WireGuard status:'
wg show wg0 || true

echo
echo '[EDGE] Routes:'
ip route | grep -E 'default|10.50|10.255' || true

echo
echo '[EDGE] Tunnel ping test:'
ping -c 3 10.255.0.1
"

echo
echo "=================================================="
echo "[OK] EdgeRouter WireGuard is running"
echo "=================================================="
