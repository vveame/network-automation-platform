# GNS3 Node Mapping

This file documents the role of each GNS3 node, its layer, technology, and interface connections.

## Layer Overview

| Layer | Technology | Role |
|---|---|---|
| Access | Open vSwitch | Connect end devices and assign access VLANs |
| Distribution L2 | Open vSwitch | Aggregate access switches and transport VLAN trunks |
| Distribution L3 | FRRouting Docker | Provide inter-VLAN routing and OSPF toward the core |
| Core | FRRouting Docker | Provide backbone routing between distribution and edge |
| Edge | FRRouting Docker | Connect internal network to DMZ, Internet/cloud, and future VPN |
| DMZ | Open vSwitch | Isolate public-facing services |

## Access Layer

### Access-OVS-4

| Interface | Connected To | Mode | VLANs |
|---|---|---|---|
| eth0 | PC1 | Access | VLAN 10 |
| eth1 | Dist-OVS-1 | Trunk | 10, 20, 99 |
| eth2 | Dist-OVS-2 | Trunk | 10, 20, 99 |
| mgmt0 | Internal OVS interface | Management | VLAN 99 / 192.168.99.44 |

### Access-OVS-5

| Interface | Connected To | Mode | VLANs |
|---|---|---|---|
| eth0 | PC2 | Access | VLAN 10 |
| eth1 | Dist-OVS-1 | Trunk | 10, 20, 99 |
| eth2 | Dist-OVS-2 | Trunk | 10, 20, 99 |
| mgmt0 | Internal OVS interface | Management | VLAN 99 / 192.168.99.45 |

### Access-OVS-6

| Interface | Connected To | Mode | VLANs |
|---|---|---|---|
| eth0 | PC3 | Access | VLAN 20 |
| eth1 | DevOps Server | Access | VLAN 99 |
| eth2 | Dist-OVS-1 | Trunk | 10, 20, 99 |
| eth3 | Dist-OVS-2 | Trunk | 10, 20, 99 |
| mgmt0 | Internal OVS interface | Management | VLAN 99 / 192.168.99.46 |

## Distribution Layer - Open vSwitch

### Dist-OVS-1

| Interface | Connected To | Mode | VLANs |
|---|---|---|---|
| eth0 | Access-OVS-4 | Trunk | 10, 20, 99 |
| eth1 | Access-OVS-5 | Trunk | 10, 20, 99 |
| eth2 | Access-OVS-6 | Trunk | 10, 20, 99 |
| eth3 | Dist-FRR-1 | Trunk | 10, 20, 99 |
| mgmt0 | Internal OVS interface | Management | VLAN 99 / 192.168.99.31 |

### Dist-OVS-2

| Interface | Connected To | Mode | VLANs |
|---|---|---|---|
| eth0 | Access-OVS-4 | Trunk | 10, 20, 99 |
| eth1 | Access-OVS-5 | Trunk | 10, 20, 99 |
| eth2 | Access-OVS-6 | Trunk | 10, 20, 99 |
| eth3 | Dist-FRR-2 | Trunk | 10, 20, 99 |
| mgmt0 | Internal OVS interface | Management | VLAN 99 / 192.168.99.32 |

## Distribution Layer - FRRouting

### Dist-FRR-1

| Interface | Connected To | IP / Network | Role |
|---|---|---|---|
| eth0 | Dist-OVS-1 | VLAN trunk | Trunk carrying VLAN 10, 20, 99 |
| eth0.10 | VLAN 10 | 192.168.10.1/24 | Gateway for VLAN 10 |
| eth0.20 | VLAN 20 | 192.168.20.1/24 | Gateway for VLAN 20 |
| eth0.99 | VLAN 99 | 192.168.99.1/24 | Gateway for VLAN 99 |
| eth1 | Core-FRR-1 | 10.0.11.2/30 | Routed OSPF link |
| eth2 | Core-FRR-2 | 10.0.12.2/30 | Routed OSPF link |

### Dist-FRR-2

| Interface | Connected To | IP / Network | Role |
|---|---|---|---|
| eth0 | Dist-OVS-2 | VLAN trunk | Trunk carrying VLAN 10, 20, 99 |
| eth0.10 | VLAN 10 | 192.168.10.2/24 | Secondary gateway / redundancy path |
| eth0.20 | VLAN 20 | 192.168.20.2/24 | Secondary gateway / redundancy path |
| eth0.99 | VLAN 99 | 192.168.99.2/24 | Secondary gateway / redundancy path |
| eth1 | Core-FRR-1 | 10.0.21.2/30 | Routed OSPF link |
| eth2 | Core-FRR-2 | 10.0.22.2/30 | Routed OSPF link |

## Core Layer

### Core-FRR-1

| Interface | Connected To | IP / Network | Role |
|---|---|---|---|
| eth0 | Dist-FRR-1 | 10.0.11.1/30 | Routed OSPF link |
| eth1 | Dist-FRR-2 | 10.0.21.1/30 | Routed OSPF link |
| eth2 | EdgeRouter-VPNGateway | 10.0.100.1/30 | Routed OSPF link to edge |

### Core-FRR-2

| Interface | Connected To | IP / Network | Role |
|---|---|---|---|
| eth0 | Dist-FRR-1 | 10.0.12.1/30 | Routed OSPF link |
| eth1 | Dist-FRR-2 | 10.0.22.1/30 | Routed OSPF link |
| eth2 | EdgeRouter-VPNGateway | 10.0.101.1/30 | Routed OSPF link to edge |

## Edge Layer

### EdgeRouter-VPNGateway

| Interface | Connected To | IP / Network | Role |
|---|---|---|---|
| eth0 | Core-FRR-1 | 10.0.100.2/30 | Routed OSPF link |
| eth1 | Core-FRR-2 | 10.0.101.2/30 | Routed OSPF link |
| eth2 | DMZ-OVS | 172.16.50.1/24 | Gateway for DMZ |
| eth3 | External / Cloud / Internet Gateway | 203.0.113.2/30 | External-facing interface for NAT and future VPN |

### External / Cloud / Internet Gateway

| Interface | Connected To | IP / Network | Role |
|---|---|---|---|
| eth0 | EdgeRouter-VPNGateway eth3 | 203.0.113.1/30 | Simulated external gateway for Internet/cloud access |

## DMZ Layer

### DMZ-OVS

| Interface | Connected To | Mode | Network |
|---|---|---|---|
| eth0 | Web Server | Access | DMZ |
| eth1 | DNS Server | Access | DMZ |
| eth2 | EdgeRouter-VPNGateway | Access | DMZ |

## DMZ Servers

| Server | Interface | IP Address | Gateway |
|---|---|---|---|
| Web Server | eth0 | 172.16.50.10/24 | 172.16.50.1 |
| DNS Server | eth0 | 172.16.50.20/24 | 172.16.50.1 |

## Notes

- Open vSwitch nodes handle Layer 2 switching, VLAN access ports and trunk ports.
- FRRouting nodes handle Layer 3 routing and OSPF.
- The distribution layer is implemented as a combination of Open vSwitch and FRRouting.
- Dist-OVS to Dist-FRR links are trunk links carrying VLANs 10, 20 and 99.
- Distribution FRR to Core FRR links are routed point-to-point OSPF links.
- Core FRR to EdgeRouter links are routed point-to-point OSPF links.