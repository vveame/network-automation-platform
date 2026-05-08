#!/bin/sh

# EdgeRouter-VPNGateway
# eth0 -> Core-FRR-1
# eth1 -> Core-FRR-2
# eth2 -> DMZ-OVS
# eth3 -> External / Cloud / Internet

# Networks:
# Edge <-> Core-FRR-1    : 10.0.100.0/30
# Edge <-> Core-FRR-2    : 10.0.101.0/30
# DMZ                    : 172.16.50.0/24

# External/cloud-facing link:
# EdgeRouter eth3: 203.0.113.2/30
# External gateway: 203.0.113.1/30

set -e

# Bring physical interfaces up
ip link set eth0 up
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up

# Clean old IP addresses
ip addr flush dev eth0 || true
ip addr flush dev eth1 || true
ip addr flush dev eth2 || true
ip addr flush dev eth3 || true

# Assign DMZ and routed point-to-point links
ip addr add 10.0.100.2/30 dev eth0
ip addr add 10.0.101.2/30 dev eth1
ip addr add 172.16.50.1/24 dev eth2
ip addr add 203.0.113.2/30 dev eth3

# Default route toward Internet/cloud gateway
ip route replace default via 203.0.113.1 dev eth3

# Enable IPv4 forwarding
sysctl -w net.ipv4.ip_forward=1

# Display resulting configuration
ip -br addr
ip route