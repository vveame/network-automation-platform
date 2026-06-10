#!/bin/sh
set -eu

# Allow private AWS monitoring EC2 to scrape local OOB monitoring endpoints.
#
# Context:
#   Prometheus/SNMP Exporter moved from local DevOps to private AWS monitoring EC2.
#
# Cloud monitoring source:
#   10.50.30.154
#
# Required local return route:
#   10.50.0.0/16 via EdgeRouter-VPNGateway OOB 10.200.0.30
#
# Allowed:
#   ICMP from cloud monitoring for diagnostics
#   UDP/1161 from cloud monitoring for SNMPv3 metrics
#
# SSH/admin access remains controlled separately.

CLOUD_MONITORING_IP="${CLOUD_MONITORING_IP:-10.50.30.154}"
CLOUD_MONITORING_EXTRA_IPS="${CLOUD_MONITORING_EXTRA_IPS:-}"
AWS_VPC_CIDR="${AWS_VPC_CIDR:-10.50.0.0/16}"
EDGE_OOB_GW="${EDGE_OOB_GW:-10.200.0.30}"
ENABLE_CLOUD_MONITORING_ROUTE="${ENABLE_CLOUD_MONITORING_ROUTE:-true}"

echo "[INFO] Cloud monitoring primary source: $CLOUD_MONITORING_IP"
echo "[INFO] Cloud monitoring extra sources: ${CLOUD_MONITORING_EXTRA_IPS:-none}"
echo "[INFO] AWS VPC CIDR: $AWS_VPC_CIDR"
echo "[INFO] EdgeRouter OOB gateway: $EDGE_OOB_GW"

# Add route back to AWS VPC unless this node is the EdgeRouter itself.
if [ "$ENABLE_CLOUD_MONITORING_ROUTE" = "true" ]; then
  if ip -o addr show 2>/dev/null | grep -qw "$EDGE_OOB_GW"; then
    echo "[INFO] This node owns $EDGE_OOB_GW; skipping route via itself."
  else
    ip route replace "$AWS_VPC_CIDR" via "$EDGE_OOB_GW" 2>/dev/null || \
      echo "[WARN] Could not install route $AWS_VPC_CIDR via $EDGE_OOB_GW"
  fi
fi

for SRC in $CLOUD_MONITORING_IP $CLOUD_MONITORING_EXTRA_IPS; do
  [ -n "$SRC" ] || continue

  echo "[INFO] Allowing cloud monitoring source: $SRC"

  iptables -C INPUT -p icmp -s "$SRC" -j ACCEPT 2>/dev/null || \
    iptables -I INPUT 1 -p icmp -s "$SRC" -j ACCEPT

  iptables -C INPUT -p udp -s "$SRC" --dport 1161 -j ACCEPT 2>/dev/null || \
    iptables -I INPUT 1 -p udp -s "$SRC" --dport 1161 -j ACCEPT
done

echo "[OK] Cloud monitoring access rules installed."

echo "[INFO] Route check:"
ip route | grep "$AWS_VPC_CIDR" || true

echo "[INFO] Firewall check:"
iptables -L INPUT -n -v | grep -E "$CLOUD_MONITORING_IP|${CLOUD_MONITORING_EXTRA_IPS:-NO_EXTRA_SOURCE}" || true
