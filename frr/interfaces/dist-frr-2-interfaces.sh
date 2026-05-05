#!/bin/sh

# Dist-FRR-2
# eth0 -> Dist-OVS-2 trunk (VLAN 10, 20, 99)
# eth1 -> Core-FRR-1
# eth2 -> Core-FRR-2

# Backup/secondary VLAN gateway IPs:
# VLAN 10 HR         -> 192.168.10.2/24
# VLAN 20 IT         -> 192.168.20.2/24
# VLAN 99 Management -> 192.168.99.2/24

# Routed links:
# Dist-FRR-2 <-> Core-FRR-1 : 10.0.21.0/30
# Dist-FRR-2 <-> Core-FRR-2 : 10.0.22.0/30

# Bring physical interfaces up
ip link set eth0 up
ip link set eth1 up
ip link set eth2 up

# Clean previous IP addresses on routed links
ip addr flush dev eth1 || true
ip addr flush dev eth2 || true

# Remove existing VLAN subinterfaces if they already exist
ip link delete eth0.10 2>/dev/null || true
ip link delete eth0.20 2>/dev/null || true
ip link delete eth0.99 2>/dev/null || true

# Create VLAN subinterfaces on trunk toward Dist-OVS-2
ip link add link eth0 name eth0.10 type vlan id 10
ip link add link eth0 name eth0.20 type vlan id 20
ip link add link eth0 name eth0.99 type vlan id 99

# Assign secondary VLAN gateway IPs
ip addr add 192.168.10.2/24 dev eth0.10
ip addr add 192.168.20.2/24 dev eth0.20
ip addr add 192.168.99.2/24 dev eth0.99

# Bring VLAN subinterfaces up
ip link set eth0.10 up
ip link set eth0.20 up
ip link set eth0.99 up

# Assign routed point-to-point links to core
ip addr add 10.0.21.2/30 dev eth1
ip addr add 10.0.22.2/30 dev eth2

# Enable IPv4 forwarding
sysctl -w net.ipv4.ip_forward=1

# Display resulting configuration
ip -br addr
ip route