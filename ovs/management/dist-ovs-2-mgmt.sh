#!/bin/sh

# Management IP for Dist-OVS-2
# Requires br0 to already exist.
# Management VLAN: 99

set -e

MGMT_IF="mgmt0"
MGMT_IP="192.168.99.32/24"
MGMT_GW="192.168.99.1"
MGMT_MAC="02:99:00:00:00:32"
DEVOPS_SERVER="192.168.99.10"

ip link delete "$MGMT_IF" 2>/dev/null || true

ovs-vsctl --may-exist add-port br0 "$MGMT_IF" tag=99 -- set Interface "$MGMT_IF" type=internal

ip link set br0 up 2>/dev/null || true

ip addr flush dev "$MGMT_IF" 2>/dev/null || true
ip link set "$MGMT_IF" address "$MGMT_MAC" 2>/dev/null || true
ip addr add "$MGMT_IP" dev "$MGMT_IF"
ip link set "$MGMT_IF" up

ip route replace default via "$MGMT_GW"

# Delayed ARP/MAC warm-up toward DevOps laptop.
(
  sleep 8
  for i in 1 2 3 4 5; do
    ping -c 1 -W 1 "$DEVOPS_SERVER" >/dev/null 2>&1 || true
    sleep 2
  done
) &

ip addr
ip route