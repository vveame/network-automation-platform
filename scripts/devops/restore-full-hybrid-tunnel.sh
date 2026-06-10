#!/usr/bin/env bash
set -euo pipefail

# Full hybrid tunnel restore after GNS3/container restart.
#
# Run from DevOps VM.
#
# Responsibilities:
# - refresh SSH known_hosts for recreated GNS3 containers
# - enable DevOps NAT underlay for EdgeRouter
# - install DevOps route to AWS VPC through EdgeRouter
# - optionally start WireGuard on EdgeRouter from local secret config
# - reapply cloud monitoring access to all OOB SNMP nodes
# - repair AWS monitoring EC2 egress NAT through tunnel gateway
# - validate EdgeRouter, AWS private monitoring EC2, and cloud Prometheus/SNMP

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

AWS_VPC_CIDR="${AWS_VPC_CIDR:-10.50.0.0/16}"
EDGE_OOB_IP="${EDGE_OOB_IP:-10.200.0.30}"
EDGE_OOB_GW="${EDGE_OOB_GW:-10.200.0.30}"
CLOUD_MONITORING_IP="${CLOUD_MONITORING_IP:-10.50.30.154}"
CLOUD_MONITORING_EXTRA_IPS="${CLOUD_MONITORING_EXTRA_IPS:-10.255.0.1}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:19090}"

WG_SECRET_FILE="${WG_SECRET_FILE:-$REPO_ROOT/secrets/edge-router-wg0.conf.secret}"
EDGE_WG_REMOTE_FILE="${EDGE_WG_REMOTE_FILE:-/etc/wireguard/wg0.conf}"

RUN_AWS_EGRESS_REPAIR="${RUN_AWS_EGRESS_REPAIR:-true}"
RUN_CLOUD_PROMETHEUS_CHECK="${RUN_CLOUD_PROMETHEUS_CHECK:-true}"
START_EDGE_WG="${START_EDGE_WG:-auto}"

echo "=================================================="
echo "PFE Full Hybrid Tunnel Restore"
echo "=================================================="
echo "[INFO] Repo: $REPO_ROOT"
echo "[INFO] EdgeRouter OOB IP: $EDGE_OOB_IP"
echo "[INFO] AWS VPC CIDR: $AWS_VPC_CIDR"
echo "[INFO] Cloud monitoring IP: $CLOUD_MONITORING_IP"
echo "[INFO] Cloud monitoring extra IPs: $CLOUD_MONITORING_EXTRA_IPS"
echo "[INFO] Prometheus URL: $PROMETHEUS_URL"
echo

echo "=================================================="
echo "1. Refresh SSH known_hosts for recreated GNS3 nodes"
echo "=================================================="
./scripts/devops/refresh-gns3-known-hosts.sh || true

echo
echo "=================================================="
echo "2. Enable DevOps NAT underlay for EdgeRouter"
echo "=================================================="
sudo EDGE_OOB_IP="$EDGE_OOB_IP" \
  ./scripts/devops/enable-edge-router-internet-underlay-nat.sh

echo
echo "=================================================="
echo "3. Route DevOps AWS VPC traffic through EdgeRouter"
echo "=================================================="
sudo AWS_VPC_CIDR="$AWS_VPC_CIDR" EDGE_OOB_IP="$EDGE_OOB_IP" \
  ./scripts/devops/route-cloud-via-edge-router.sh

echo
echo "=================================================="
echo "4. Ensure EdgeRouter WireGuard is up"
echo "=================================================="

if [ "$START_EDGE_WG" = "true" ] || [ "$START_EDGE_WG" = "auto" ]; then
  if [ -f "$WG_SECRET_FILE" ]; then
    echo "[INFO] Found local WireGuard secret config: $WG_SECRET_FILE"
    echo "[INFO] Copying WireGuard config to EdgeRouter: $EDGE_WG_REMOTE_FILE"

    ssh root@"$EDGE_OOB_IP" 'mkdir -p /etc/wireguard && chmod 700 /etc/wireguard'
    scp "$WG_SECRET_FILE" "root@$EDGE_OOB_IP:$EDGE_WG_REMOTE_FILE"

    ssh root@"$EDGE_OOB_IP" "
      set -e
      chmod 600 '$EDGE_WG_REMOTE_FILE'
      if command -v wg-quick >/dev/null 2>&1; then
        wg-quick down wg0 2>/dev/null || true
        wg-quick up wg0
      else
        echo '[ERROR] wg-quick not found inside EdgeRouter container.'
        echo '[ERROR] Rebuild FRR image with wireguard-tools.'
        exit 1
      fi
      ip route replace '$AWS_VPC_CIDR' dev wg0 2>/dev/null || true
      wg show || true
      ip route | grep -E '10.50|10.255' || true
    "
  else
    echo "[WARN] No local WireGuard secret file found:"
    echo "[WARN]   $WG_SECRET_FILE"
    echo "[WARN] Skipping WireGuard config copy/start."
    echo "[WARN] If wg0 is down, create this file from frr/wireguard/edge-router-wg0.conf.example."
  fi
else
  echo "[INFO] START_EDGE_WG=$START_EDGE_WG, skipping WireGuard startup."
fi

echo
echo "=================================================="
echo "5. Reapply cloud monitoring access to OOB SNMP nodes"
echo "=================================================="
CLOUD_MONITORING_IP="$CLOUD_MONITORING_IP" \
CLOUD_MONITORING_EXTRA_IPS="$CLOUD_MONITORING_EXTRA_IPS" \
AWS_VPC_CIDR="$AWS_VPC_CIDR" \
EDGE_OOB_GW="$EDGE_OOB_GW" \
./scripts/devops/apply-cloud-monitoring-access-to-oob-nodes.sh

echo
echo "=================================================="
echo "6. Repair AWS monitoring EC2 internet egress NAT"
echo "=================================================="
if [ "$RUN_AWS_EGRESS_REPAIR" = "true" ]; then
  ./scripts/devops/enable-monitoring-egress-nat-on-tunnel-gateway.sh || \
    echo "[WARN] AWS monitoring egress NAT repair failed or AWS access unavailable."
else
  echo "[INFO] RUN_AWS_EGRESS_REPAIR=false, skipping AWS NAT repair."
fi

echo
echo "=================================================="
echo "7. Validate EdgeRouter tunnel path"
echo "=================================================="
ssh root@"$EDGE_OOB_IP" "
  echo '[EDGE] WireGuard status:'
  wg show || true

  echo
  echo '[EDGE] Routes:'
  ip route | grep -E '10.50|10.255' || true

  echo
  echo '[EDGE] Ping AWS tunnel gateway 10.255.0.1:'
  ping -c 3 10.255.0.1 || true

  echo
  echo '[EDGE] Ping private monitoring EC2 $CLOUD_MONITORING_IP:'
  ping -c 3 '$CLOUD_MONITORING_IP' || true
"

echo
echo "=================================================="
echo "8. Validate DevOps route to AWS VPC"
echo "=================================================="
ip route | grep "$AWS_VPC_CIDR" || true
ip route get "$CLOUD_MONITORING_IP" || true
ping -c 3 "$CLOUD_MONITORING_IP" || true

echo
echo "=================================================="
echo "9. Validate cloud Prometheus SNMP through tunnel"
echo "=================================================="
if [ "$RUN_CLOUD_PROMETHEUS_CHECK" = "true" ]; then
  if curl -fsS "$PROMETHEUS_URL/-/ready" >/dev/null 2>&1; then
    echo "[OK] Cloud Prometheus tunnel is reachable: $PROMETHEUS_URL"

    echo
    echo "[INFO] SNMP target health:"
    curl -s --get "$PROMETHEUS_URL/api/v1/query" \
      --data-urlencode 'query=up{job="cloud-snmp-network-devices-through-tunnel"}' \
      | python3 -m json.tool || true

    echo
    echo "[INFO] SNMP interface metric count:"
    curl -s --get "$PROMETHEUS_URL/api/v1/query" \
      --data-urlencode 'query=count(ifOperStatus{job="cloud-snmp-network-devices-through-tunnel"})' \
      | python3 -m json.tool || true
  else
    echo "[WARN] Cloud Prometheus is not reachable at $PROMETHEUS_URL."
    echo "[WARN] Open your SSH tunnel to AWS monitoring EC2 first, or set RUN_CLOUD_PROMETHEUS_CHECK=false."
  fi
else
  echo "[INFO] RUN_CLOUD_PROMETHEUS_CHECK=false, skipping Prometheus checks."
fi

echo
echo "=================================================="
echo "[OK] Full hybrid tunnel restore completed"
echo "=================================================="

echo
echo "=================================================="
echo "10. Open Prometheus/Grafana UI tunnel in background"
echo "=================================================="
if [ "${OPEN_MONITORING_UI_TUNNEL:-true}" = "true" ]; then
  ./scripts/devops/cloud-monitoring-ui-tunnel.sh restart || \
    echo "[WARN] Could not open monitoring UI tunnel automatically."
else
  echo "[INFO] OPEN_MONITORING_UI_TUNNEL=false, skipping UI tunnel."
fi
