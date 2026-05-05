#!/bin/sh

# Core-FRR-2
# eth0 -> Dist-FRR-1
# eth1 -> Dist-FRR-2
# eth2 -> EdgeRouter-VPNGateway

# Routed links:
# Core-FRR-2 <-> Dist-FRR-1  : 10.0.12.0/30
# Core-FRR-2 <-> Dist-FRR-2  : 10.0.22.0/30
# Core-FRR-2 <-> EdgeRouter  : 10.0.101.0/30

# Bring physical interfaces up
ip link set eth0 up
ip link set eth1 up
ip link set eth2 up

# Clean old IP addresses
ip addr flush dev eth0 || true
ip addr flush dev eth1 || true
ip addr flush dev eth2 || true

# Assign routed point-to-point links
ip addr add 10.0.12.1/30 dev eth0
ip addr add 10.0.22.1/30 dev eth1
ip addr add 10.0.101.1/30 dev eth2

# Enable IPv4 forwarding
sysctl -w net.ipv4.ip_forward=1

# Display resulting configuration
ip -br addr
ip route