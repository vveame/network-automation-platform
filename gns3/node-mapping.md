# GNS3 Node Mapping

This file maps logical nodes to interfaces, roles, VLANs and management addresses.

## Layer Overview

| Layer | Node type | Purpose |
|---|---|---|
| DevOps | Ubuntu VM | Automation control node: Ansible, Git, Jenkins later |
| Access | Open vSwitch | Connect endpoint VPCS hosts and management access |
| Distribution switching | Open vSwitch | Aggregate access switches and trunk VLANs toward FRR routers |
| Distribution routing | FRRouting | Inter-VLAN routing, VRRP-style gateways and OSPF uplinks |
| Core | FRRouting | Backbone routing between distribution and edge |
| Edge | FRRouting | DMZ, external/cloud link, NAT and future VPN gateway |
| DMZ | Open vSwitch | Switch for Web, DNS and EdgeRouter DMZ interface |
| Services | Docker services | Web and DNS health-check targets |

## DevOps VM

| Interface | Network | Role |
|---|---|---|
| `ens33` | VMware NAT | Internet, updates, GitHub |
| `ens34` | `192.168.99.0/24` | Lab management access, `192.168.99.10` |

## Access Layer

### Access-OVS-4

| Interface | Connected To | Mode | VLANs |
|---|---|---|---|
| `eth0` | PC1 | Access | 10 |
| `eth1` | Dist-OVS-1 | Trunk | 10, 20, 99 |
| `eth2` | Dist-OVS-2 | Trunk | 10, 20, 99 |
| `mgmt0` | Internal OVS interface | Management | VLAN 99 / `192.168.99.44` |

### Access-OVS-5

| Interface | Connected To | Mode | VLANs |
|---|---|---|---|
| `eth0` | PC2 | Access | 10 |
| `eth1` | Dist-OVS-1 | Trunk | 10, 20, 99 |
| `eth2` | Dist-OVS-2 | Trunk | 10, 20, 99 |
| `mgmt0` | Internal OVS interface | Management | VLAN 99 / `192.168.99.45` |

### Access-OVS-6

| Interface | Connected To | Mode | VLANs |
|---|---|---|---|
| `eth0` | PC3 | Access | 20 |
| `eth1` | DevOps VM / management cloud | Access | 99 |
| `eth2` | Dist-OVS-1 | Trunk | 10, 20, 99 |
| `eth3` | Dist-OVS-2 | Trunk | 10, 20, 99 |
| `mgmt0` | Internal OVS interface | Management | VLAN 99 / `192.168.99.46` |

## Distribution OVS Layer

### Dist-OVS-1

| Interface | Connected To | Mode | VLANs |
|---|---|---|---|
| `eth0` | Access-OVS-4 | Trunk | 10, 20, 99 |
| `eth1` | Access-OVS-5 | Trunk | 10, 20, 99 |
| `eth2` | Access-OVS-6 | Trunk | 10, 20, 99 |
| `eth3` | Dist-FRR-1 | Trunk | 10, 20, 99 |
| `mgmt0` | Internal OVS interface | Management | VLAN 99 / `192.168.99.31` |

### Dist-OVS-2

| Interface | Connected To | Mode | VLANs |
|---|---|---|---|
| `eth0` | Access-OVS-4 | Trunk | 10, 20, 99 |
| `eth1` | Access-OVS-5 | Trunk | 10, 20, 99 |
| `eth2` | Access-OVS-6 | Trunk | 10, 20, 99 |
| `eth3` | Dist-FRR-2 | Trunk | 10, 20, 99 |
| `mgmt0` | Internal OVS interface | Management | VLAN 99 / `192.168.99.32` |

## Distribution FRR Layer

### Dist-FRR-1

| Interface | IP / Network | Role |
|---|---|---|
| `eth0` | Trunk | Toward Dist-OVS-1 |
| `eth0.10` | `192.168.10.2/24` | Real VLAN 10 interface |
| `eth0.20` | `192.168.20.2/24` | Real VLAN 20 interface |
| `eth0.99` | `192.168.99.2/24` | Real management VLAN interface |
| `vrrp10` | `192.168.10.1/24` | VLAN 10 virtual gateway |
| `vrrp20` | `192.168.20.1/24` | VLAN 20 virtual gateway |
| `vrrp99` | `192.168.99.1/24` | VLAN 99 virtual gateway |
| `eth1` | `10.0.11.2/30` | Link to Core-FRR-1 |
| `eth2` | `10.0.12.2/30` | Link to Core-FRR-2 |
| `lo` | `10.255.0.21/32` | Routed management loopback |

### Dist-FRR-2

| Interface | IP / Network | Role |
|---|---|---|
| `eth0` | Trunk | Toward Dist-OVS-2 |
| `eth0.10` | `192.168.10.3/24` | Real VLAN 10 interface |
| `eth0.20` | `192.168.20.3/24` | Real VLAN 20 interface |
| `eth0.99` | `192.168.99.3/24` | Real management VLAN interface |
| `vrrp10` | `192.168.10.1/24` | VLAN 10 virtual gateway |
| `vrrp20` | `192.168.20.1/24` | VLAN 20 virtual gateway |
| `vrrp99` | `192.168.99.1/24` | VLAN 99 virtual gateway |
| `eth1` | `10.0.21.2/30` | Link to Core-FRR-1 |
| `eth2` | `10.0.22.2/30` | Link to Core-FRR-2 |
| `lo` | `10.255.0.22/32` | Routed management loopback |

## Core Layer

| Router | Interface | IP / Network | Role |
|---|---|---|---|
| Core-FRR-1 | `eth0` | `10.0.11.1/30` | To Dist-FRR-1 |
| Core-FRR-1 | `eth1` | `10.0.21.1/30` | To Dist-FRR-2 |
| Core-FRR-1 | `eth2` | `10.0.100.1/30` | To EdgeRouter |
| Core-FRR-1 | `lo` | `10.255.0.11/32` | Routed management loopback |
| Core-FRR-2 | `eth0` | `10.0.12.1/30` | To Dist-FRR-1 |
| Core-FRR-2 | `eth1` | `10.0.22.1/30` | To Dist-FRR-2 |
| Core-FRR-2 | `eth2` | `10.0.101.1/30` | To EdgeRouter |
| Core-FRR-2 | `lo` | `10.255.0.12/32` | Routed management loopback |

## Edge Layer

| Interface | IP / Network | Role |
|---|---|---|
| `eth0` | `10.0.100.2/30` | Link to Core-FRR-1 |
| `eth1` | `10.0.101.2/30` | Link to Core-FRR-2 |
| `eth2` | `172.16.50.1/24` | DMZ gateway |
| `eth3` | `203.0.113.2/30` | External/cloud link |
| `lo` | `10.255.0.30/32` | Routed management loopback |

## DMZ Layer

### DMZ-OVS-3

| Interface | Connected To | Network / Role |
|---|---|---|
| `eth0` | Web Server | DMZ data plane |
| `eth1` | DNS Server | DMZ data plane |
| `eth2` | EdgeRouter-VPNGateway | DMZ uplink |
| `mgmt0` | Internal OVS interface | `172.16.50.3/24`, managed through EdgeRouter |

## DMZ Services

| Service | Interface | IP Address | Gateway |
|---|---|---|---|
| Web Server | `eth0` | `172.16.50.10/24` | `172.16.50.1` |
| DNS Server | `eth0` | `172.16.50.20/24` | `172.16.50.1` |

## Notes

- Internal OVS nodes are managed through VLAN 99.
- FRR routers are managed through routed OSPF-advertised loopbacks.
- DMZ-OVS-3 is managed through the DMZ and EdgeRouter firewall exception, not through a direct VLAN 99 link.
- Web and DNS are service nodes and are validated through HTTP/DNS checks instead of SSH.