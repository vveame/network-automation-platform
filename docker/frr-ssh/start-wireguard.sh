
#!/bin/sh
set -eu

# Optional WireGuard startup for EdgeRouter-VPNGateway.
# This script is safe on non-edge FRR routers: if no config exists, it exits cleanly.

WG_NAME="${WG_NAME:-wg0}"
WG_LOCAL_CONFIG="${WG_LOCAL_CONFIG:-/etc/local/wireguard/${WG_NAME}.conf}"
WG_RUNTIME_CONFIG="${WG_RUNTIME_CONFIG:-/etc/wireguard/${WG_NAME}.conf}"
UNDERLAY_ENV="${UNDERLAY_ENV:-/etc/local/wireguard/edge-underlay.env}"
AWS_VPC_CIDR="${AWS_VPC_CIDR:-10.50.0.0/16}"

if [ ! -f "$WG_LOCAL_CONFIG" ]; then
  echo "[WG] No $WG_LOCAL_CONFIG found. Skipping WireGuard startup."
  exit 0
fi

if ! command -v wg >/dev/null 2>&1 || ! command -v wg-quick >/dev/null 2>&1; then
  echo "[WG][WARN] wg or wg-quick not installed. Skipping WireGuard startup."
  exit 0
fi

mkdir -p /etc/wireguard
cp "$WG_LOCAL_CONFIG" "$WG_RUNTIME_CONFIG"
chmod 600 "$WG_RUNTIME_CONFIG"

# Optional underlay route metadata.
# Used so EdgeRouter reaches the public AWS tunnel gateway through DevOps NAT.
if [ -f "$UNDERLAY_ENV" ]; then
  echo "[WG] Loading underlay environment: $UNDERLAY_ENV"
  # shellcheck disable=SC1090
  . "$UNDERLAY_ENV"
else
  echo "[WG][WARN] No $UNDERLAY_ENV found. Will rely on existing route to WireGuard Endpoint."
fi

# If AWS_TUNNEL_PUBLIC_IP is not set, try to parse it from wg0.conf Endpoint.
if [ -z "${AWS_TUNNEL_PUBLIC_IP:-}" ]; then
  AWS_TUNNEL_PUBLIC_IP="$(awk -F= '
    /^[[:space:]]*Endpoint[[:space:]]*=/ {
      gsub(/[[:space:]]/, "", $2)
      split($2, a, ":")
      print a[1]
      exit
    }
  ' "$WG_RUNTIME_CONFIG" || true)"
fi

DEVOPS_UNDERLAY_GW="${DEVOPS_UNDERLAY_GW:-10.200.0.10}"
EDGE_OOB_IF="${EDGE_OOB_IF:-eth4}"

if echo "${AWS_TUNNEL_PUBLIC_IP:-}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "[WG] Installing underlay host route to AWS public tunnel endpoint:"
  echo "[WG] ${AWS_TUNNEL_PUBLIC_IP}/32 via ${DEVOPS_UNDERLAY_GW} dev ${EDGE_OOB_IF}"

  if ip link show "$EDGE_OOB_IF" >/dev/null 2>&1; then
    ip route replace "${AWS_TUNNEL_PUBLIC_IP}/32" via "$DEVOPS_UNDERLAY_GW" dev "$EDGE_OOB_IF" || true
  else
    echo "[WG][WARN] Interface $EDGE_OOB_IF not found. Trying route without dev."
    ip route replace "${AWS_TUNNEL_PUBLIC_IP}/32" via "$DEVOPS_UNDERLAY_GW" || true
  fi
else
  echo "[WG][WARN] Could not determine AWS_TUNNEL_PUBLIC_IP. Underlay host route not installed."
fi

echo "[WG] Restarting WireGuard interface $WG_NAME..."
wg-quick down "$WG_NAME" 2>/dev/null || true
wg-quick up "$WG_NAME"

# Defensive explicit route. wg-quick should install AllowedIPs routes,
# but this keeps the AWS VPC path stable in the lab.
ip route replace "$AWS_VPC_CIDR" dev "$WG_NAME" 2>/dev/null || true

echo "[WG] WireGuard status:"
wg show "$WG_NAME" || true

echo "[WG] Route check:"
ip route | grep -E "$AWS_VPC_CIDR|${AWS_TUNNEL_PUBLIC_IP:-NO_PUBLIC_IP}" || true

echo "[WG][OK] WireGuard startup completed."
