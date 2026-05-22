#!/bin/sh

# Management IP for DMZ-OVS-3
# Requires br0 to already exist.

set -e

MGMT_IF="mgmt0"
MGMT_IP="172.16.50.3/24"
MGMT_GW="172.16.50.1"
MGMT_MAC="02:50:00:00:00:03"

echo "[INFO] Configuring DMZ-OVS-3 management interface..."

# Remove previous internal management interface cleanly.
ovs-vsctl --if-exists del-port br0 "$MGMT_IF"
ip link delete "$MGMT_IF" 2>/dev/null || true

# Recreate internal management interface inside the DMZ bridge.
ovs-vsctl --may-exist add-port br0 "$MGMT_IF" -- set Interface "$MGMT_IF" type=internal

ip link set br0 up 2>/dev/null || true
ip link set "$MGMT_IF" up
ip link set dev "$MGMT_IF" address "$MGMT_MAC" 2>/dev/null || true

ip addr flush dev "$MGMT_IF" 2>/dev/null || true
ip addr add "$MGMT_IP" dev "$MGMT_IF"
ip route replace default via "$MGMT_GW" dev "$MGMT_IF"

ip addr
ip route