# GNS3 Node Mapping

This file maps logical nodes to interfaces, roles, VLANs, production addresses and OOB management addresses.

## Layer Overview

| Layer | Node type | Purpose |
|---|---|---|
| DevOps | Ubuntu VM | Automation control node: Ansible, Git, Jenkins and Terraform |
| OOB Management | GNS3 Cloud + Ethernet switches | Dedicated management/control plane |
| Access | Open vSwitch | Connect endpoint VPCS hosts and trunk VLANs upward |
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
| `ens34` | `10.200.0.0/24` | OOB management access, `10.200.0.10` |

## Out-of-Band Management Plane

| OOB Node | Role |
|---|---|
| `Cloud-OOB-MGMT` | Bridge between GNS3 and the DevOps VM OOB network |
| `OOB-MGMT-AGG` | Aggregation switch for the OOB management plane |
| `OOB-CORE-MGMT-SW` | OOB switch for core infrastructure nodes |
| `OOB-DIST-MGMT-SW` | OOB switch for distribution infrastructure nodes |
| `OOB-ACCESS-MGMT-SW` | OOB switch for access infrastructure nodes |
| `OOB-EDGE-MGMT-SW` | OOB switch for edge infrastructure nodes |
| `OOB-DMZ-MGMT-SW` | OOB switch for DMZ infrastructure nodes |

## OOB Addressing

| Node | OOB Interface | OOB IP |
|---|---|---|
| Core-FRR-1 | `eth3` | `10.200.0.11/24` |
| Core-FRR-2 | `eth3` | `10.200.0.12/24` |
| Dist-FRR-1 | `eth3` | `10.200.0.21/24` |
| Dist-FRR-2 | `eth3` | `10.200.0.22/24` |
| EdgeRouter-VPNGateway | `eth4` | `10.200.0.30/24` |
| Dist-OVS-1 | `eth4` | `10.200.0.31/24` |
| Dist-OVS-2 | `eth4` | `10.200.0.32/24` |
| DMZ-OVS-3 | `eth3` | `10.200.0.33/24` |
| Access-OVS-4 | `eth3` | `10.200.0.44/24` |
| Access-OVS-5 | `eth3` | `10.200.0.45/24` |
| Access-OVS-6 | `eth4` | `10.200.0.46/24` |

## Access Layer

### Access-OVS-4

| Interface | Connected To | Mode | VLANs / Role |
|---|---|---|---|
| `eth0` | PC1 | Access | 10 |
| `eth1` | Dist-OVS-1 | Trunk | 10, 20, 99 |
| `eth2` | Dist-OVS-2 | Trunk | 10, 20, 99 |
| `eth3` | OOB-ACCESS-MGMT-SW | OOB | `10.200.0.44/24` |
| `mgmt0` | Internal OVS interface | Management | VLAN 99 / `192.168.99.44` |

### Access-OVS-5

| Interface | Connected To | Mode | VLANs / Role |
|---|---|---|---|
| `eth0` | PC2 | Access | 10 |
| `eth1` | Dist-OVS-1 | Trunk | 10, 20, 99 |
| `eth2` | Dist-OVS-2 | Trunk | 10, 20, 99 |
| `eth3` | OOB-ACCESS-MGMT-SW | OOB | `10.200.0.45/24` |
| `mgmt0` | Internal OVS interface | Management | VLAN 99 / `192.168.99.45` |

### Access-OVS-6

| Interface | Connected To | Mode | VLANs / Role |
|---|---|---|---|
| `eth0` | PC3 | Access | 20 |
| `eth1` | DevOps VM / VLAN 99 management cloud | Access | 99 |
| `eth2` | Dist-OVS-1 | Trunk | 10, 20, 99 |
| `eth3` | Dist-OVS-2 | Trunk | 10, 20, 99 |
| `eth4` | OOB-ACCESS-MGMT-SW | OOB | `10.200.0.46/24` |
| `mgmt0` | Internal OVS interface | Management | VLAN 99 / `192.168.99.46` |

## Distribution OVS Layer

### Dist-OVS-1

| Interface | Connected To | Mode | VLANs / Role |
|---|---|---|---|
| `eth0` | Access-OVS-4 | Trunk | 10, 20, 99 |
| `eth1` | Access-OVS-5 | Trunk | 10, 20, 99 |
| `eth2` | Access-OVS-6 | Trunk | 10, 20, 99 |
| `eth3` | Dist-FRR-1 | Trunk | 10, 20, 99 |
| `eth4` | OOB-DIST-MGMT-SW | OOB | `10.200.0.31/24` |
| `mgmt0` | Internal OVS interface | Management | VLAN 99 / `192.168.99.31` |

### Dist-OVS-2

| Interface | Connected To | Mode | VLANs / Role |
|---|---|---|---|
| `eth0` | Access-OVS-4 | Trunk | 10, 20, 99 |
| `eth1` | Access-OVS-5 | Trunk | 10, 20, 99 |
| `eth2` | Access-OVS-6 | Trunk | 10, 20, 99 |
| `eth3` | Dist-FRR-2 | Trunk | 10, 20, 99 |
| `eth4` | OOB-DIST-MGMT-SW | OOB | `10.200.0.32/24` |
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
| `eth3` | `10.200.0.21/24` | OOB management interface |
| `lo` | `10.255.0.21/32` | Routed loopback for validation |

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
| `eth3` | `10.200.0.22/24` | OOB management interface |
| `lo` | `10.255.0.22/32` | Routed loopback for validation |

## Core Layer

| Router | Interface | IP / Network | Role |
|---|---|---|---|
| Core-FRR-1 | `eth0` | `10.0.11.1/30` | To Dist-FRR-1 |
| Core-FRR-1 | `eth1` | `10.0.21.1/30` | To Dist-FRR-2 |
| Core-FRR-1 | `eth2` | `10.0.100.1/30` | To EdgeRouter |
| Core-FRR-1 | `eth3` | `10.200.0.11/24` | OOB management interface |
| Core-FRR-1 | `lo` | `10.255.0.11/32` | Routed loopback for validation |
| Core-FRR-2 | `eth0` | `10.0.12.1/30` | To Dist-FRR-1 |
| Core-FRR-2 | `eth1` | `10.0.22.1/30` | To Dist-FRR-2 |
| Core-FRR-2 | `eth2` | `10.0.101.1/30` | To EdgeRouter |
| Core-FRR-2 | `eth3` | `10.200.0.12/24` | OOB management interface |
| Core-FRR-2 | `lo` | `10.255.0.12/32` | Routed loopback for validation |

## Edge Layer

| Interface | IP / Network | Role |
|---|---|---|
| `eth0` | `10.0.100.2/30` | Link to Core-FRR-1 |
| `eth1` | `10.0.101.2/30` | Link to Core-FRR-2 |
| `eth2` | `172.16.50.1/24` | DMZ gateway |
| `eth3` | `203.0.113.2/30` | External/cloud link |
| `eth4` | `10.200.0.30/24` | OOB management interface |
| `lo` | `10.255.0.30/32` | Routed loopback for validation |

## DMZ Layer

### DMZ-OVS-3

| Interface | Connected To | Network / Role |
|---|---|---|
| `eth0` | Web Server | DMZ data plane |
| `eth1` | DNS Server | DMZ data plane |
| `eth2` | EdgeRouter-VPNGateway | DMZ uplink |
| `eth3` | OOB-DMZ-MGMT-SW | OOB management, `10.200.0.33/24` |
| `mgmt0` | Internal OVS interface | Legacy DMZ management, `172.16.50.3/24` |

## DMZ Services

| Service | Interface | IP Address | Gateway |
|---|---|---|---|
| Web Server | `eth0` | `172.16.50.10/24` | `172.16.50.1` |
| DNS Server | `eth0` | `172.16.50.20/24` | `172.16.50.1` |

## Notes

- OOB `10.200.0.0/24` is the primary SSH/Ansible/Jenkins control path.
- VLAN 99 remains an in-band management VLAN inside the production topology.
- FRR loopbacks `10.255.0.0/24` are kept for routing validation.
- OOB interfaces must not be added to OVS bridges.
- OOB interfaces must not participate in OSPF.
- Web and DNS are service nodes and are validated through HTTP/DNS checks instead of SSH.