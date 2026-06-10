#!/bin/sh
set -e

# EdgeRouter-VPNGateway
#
# Production interfaces:
#   eth0 -> Core-FRR-1
#   eth1 -> Core-FRR-2
#   eth2 -> DMZ-OVS
#
# Legacy simulated external interface:
#   eth3 -> External / Cloud / Internet placeholder
#
# OOB interface:
#   eth4 -> DevOps OOB network, configured by management/oob/edge-router.oob-env
#
# Important:
#   The old simulated external route through 203.0.113.1 is not used for the
#   validated AWS WireGuard tunnel because it does not provide real internet
#   access in the current lab.
#
# Current validated AWS underlay path:
#   EdgeRouter eth4 / 10.200.0.30
#       -> DevOps OOB / 10.200.0.10
#       -> DevOps NAT underlay
#       -> AWS public EC2 tunnel gateway UDP/51820
#
# The persistent default underlay route is configured in:
#   frr/routing/edge-router.conf
#
#   ip route 0.0.0.0/0 10.200.0.10
#
# This script only configures local interfaces and must not override the
# validated FRR default route.

echo "[INFO] Applying EdgeRouter interface configuration..."

# Bring production/legacy interfaces up.
ip link set eth0 up
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up

# Clean old IP addresses.
ip addr flush dev eth0 || true
ip addr flush dev eth1 || true
ip addr flush dev eth2 || true
ip addr flush dev eth3 || true

# Assign routed point-to-point links and DMZ gateway.
ip addr add 10.0.100.2/30 dev eth0
ip addr add 10.0.101.2/30 dev eth1
ip addr add 172.16.50.1/24 dev eth2

# Keep the legacy simulated external link address for topology visibility.
# Do not install a default route through this link.
ip addr add 203.0.113.2/30 dev eth3

# Remove the old broken default route if it exists.
ip route del default via 203.0.113.1 dev eth3 2>/dev/null || true

# Assign loopback management/validation IP.
ip addr add 10.255.0.30/32 dev lo 2>/dev/null || true

# Enable IPv4 forwarding for routing and WireGuard forwarding.
sysctl -w net.ipv4.ip_forward=1

echo "[INFO] EdgeRouter interface configuration applied."
ip -br addr
ip route