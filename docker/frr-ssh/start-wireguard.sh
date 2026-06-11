#!/bin/sh
set -eu

WG_NAME="${WG_NAME:-wg0}"
LOCAL_WG_CONF="${LOCAL_WG_CONF:-/etc/local/wireguard/wg0.conf}"
RUNTIME_WG_CONF="${RUNTIME_WG_CONF:-/etc/wireguard/wg0.conf}"
UNDERLAY_ENV="${UNDERLAY_ENV:-/etc/local/wireguard/edge-underlay.env}"

if [ ! -f "$LOCAL_WG_CONF" ]; then
  echo "[WG] No $LOCAL_WG_CONF found. Skipping WireGuard startup."
  exit 0
fi

if ! command -v wg >/dev/null 2>&1 || ! command -v wg-quick >/dev/null 2>&1; then
  echo "[WG][WARN] wg or wg-quick not found. Skipping WireGuard startup."
  exit 0
fi

mkdir -p /etc/wireguard
cp "$LOCAL_WG_CONF" "$RUNTIME_WG_CONF"
chmod 600 "$RUNTIME_WG_CONF"

if [ -f "$UNDERLAY_ENV" ]; then
  echo "[WG] Loading underlay env: $UNDERLAY_ENV"
  . "$UNDERLAY_ENV"
else
  echo "[WG][WARN] Missing $UNDERLAY_ENV."
fi

UNDERLAY_MODE="${UNDERLAY_MODE:-direct}"
AWS_VPC_CIDR="${AWS_VPC_CIDR:-10.50.0.0/16}"
DEVOPS_UNDERLAY_GW="${DEVOPS_UNDERLAY_GW:-10.200.0.10}"
EDGE_OOB_IF="${EDGE_OOB_IF:-eth4}"
WAN_IF="${WAN_IF:-eth3}"

if [ -z "${AWS_TUNNEL_PUBLIC_IP:-}" ]; then
  AWS_TUNNEL_PUBLIC_IP="$(awk -F= '
    /^[[:space:]]*Endpoint[[:space:]]*=/ {
      gsub(/[[:space:]]/, "", $2)
      split($2, a, ":")
      print a[1]
      exit
    }
  ' "$RUNTIME_WG_CONF" || true)"
fi

if echo "${AWS_TUNNEL_PUBLIC_IP:-}" | grep -Eq '^10\.50\.'; then
  echo "[WG][ERROR] Endpoint is private AWS VPC IP: $AWS_TUNNEL_PUBLIC_IP"
  echo "[WG][ERROR] Endpoint must be the AWS tunnel gateway PUBLIC IP."
  exit 1
fi

if [ "$UNDERLAY_MODE" = "devops" ]; then
  echo "[WG] DevOps underlay mode."
  ip route replace "${AWS_TUNNEL_PUBLIC_IP}/32" via "$DEVOPS_UNDERLAY_GW" dev "$EDGE_OOB_IF" || true
else
  echo "[WG] Direct EdgeRouter underlay mode."
  ip route get "$AWS_TUNNEL_PUBLIC_IP" || {
    echo "[WG][ERROR] No route to AWS public tunnel endpoint."
    echo "[WG][ERROR] Check eth3 DHCP/default route."
    exit 1
  }
fi

echo "[WG] Starting $WG_NAME..."
wg-quick down "$WG_NAME" 2>/dev/null || true
wg-quick up "$WG_NAME"

ip route replace "$AWS_VPC_CIDR" dev "$WG_NAME" 2>/dev/null || true

echo "[WG][OK] WireGuard started."
wg show "$WG_NAME" || true
ip route | grep -E 'default|10.50|10.255' || true
