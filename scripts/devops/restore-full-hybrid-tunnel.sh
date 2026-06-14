#!/usr/bin/env bash
set -euo pipefail

# Full hybrid restore for final direct EdgeRouter underlay.
#
# Run from DevOps VM.
#
# Final model:
# - EdgeRouter eth3 provides direct internet underlay through GNS3 NAT.
# - EdgeRouter wg0 terminates the WireGuard tunnel to AWS.
# - DevOps does not provide tunnel underlay NAT.
# - DevOps still routes AWS private VPC traffic through EdgeRouter.
# - AWS monitoring EC2 remains private and is reached through the tunnel.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

AWS_VPC_CIDR="${AWS_VPC_CIDR:-10.50.0.0/16}"
EDGE_OOB_IP="${EDGE_OOB_IP:-10.200.0.30}"
EDGE_OOB_GW="${EDGE_OOB_GW:-10.200.0.30}"
CLOUD_MONITORING_IP="${CLOUD_MONITORING_IP:-10.50.30.154}"
CLOUD_MONITORING_EXTRA_IPS="${CLOUD_MONITORING_EXTRA_IPS:-10.255.0.1}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:19090}"

RUN_AWS_EGRESS_REPAIR="${RUN_AWS_EGRESS_REPAIR:-true}"
RUN_CLOUD_PROMETHEUS_CHECK="${RUN_CLOUD_PROMETHEUS_CHECK:-true}"
OPEN_MONITORING_UI_TUNNEL="${OPEN_MONITORING_UI_TUNNEL:-true}"

echo "=================================================="
echo "PFE Full Hybrid Restore - Direct EdgeRouter Underlay"
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
echo "2. Confirm direct EdgeRouter internet underlay"
echo "=================================================="
ssh root@"$EDGE_OOB_IP" '
echo "[EDGE] eth3:"
ip -br addr show eth3 || true

echo
echo "[EDGE] default route:"
ip route | grep default || true

echo
echo "[EDGE] route to internet test IP:"
ip route get 8.8.8.8 || true
'

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
./scripts/devops/ensure-edge-wireguard.sh

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
wg show wg0 || true

echo
echo '[EDGE] Routes:'
ip route | grep -E 'default|10.50|10.255' || true

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
echo "9. Validate cloud Prometheus through local tunnel"
echo "=================================================="
if [ "$RUN_CLOUD_PROMETHEUS_CHECK" = "true" ]; then
  if curl -fsS "$PROMETHEUS_URL/-/ready" >/dev/null 2>&1; then
    echo "[OK] Cloud Prometheus tunnel is reachable: $PROMETHEUS_URL"

    curl -s --get "$PROMETHEUS_URL/api/v1/query" \
      --data-urlencode 'query=up{job="cloud-snmp-network-devices-through-tunnel"}' \
      | python3 -m json.tool || true
  else
    echo "[WARN] Cloud Prometheus is not reachable at $PROMETHEUS_URL."
    echo "[WARN] The UI SSH tunnel may not be open yet."
  fi
else
  echo "[INFO] RUN_CLOUD_PROMETHEUS_CHECK=false, skipping Prometheus check."
fi

echo
echo "=================================================="
echo "10. Open Prometheus/Grafana UI tunnel in background"
echo "=================================================="
if [ "$OPEN_MONITORING_UI_TUNNEL" = "true" ]; then
  ./scripts/devops/cloud-monitoring-ui-tunnel.sh restart || \
    echo "[WARN] Could not open monitoring UI tunnel automatically."
else
  echo "[INFO] OPEN_MONITORING_UI_TUNNEL=false, skipping UI tunnel."
fi

echo
echo "=================================================="
echo "[OK] Full hybrid restore completed"
echo "=================================================="
