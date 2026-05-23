# Host and Management IP Plan

This file documents addressing for end hosts, services, OVS management interfaces, FRR routed management loopbacks and the external/cloud link.

## VLANs and Networks

| Zone / VLAN | Role | Network | Gateway / Next hop |
|---|---|---|---|
| VLAN 10 | User network | `192.168.10.0/24` | `192.168.10.1` |
| VLAN 20 | User network | `192.168.20.0/24` | `192.168.20.1` |
| VLAN 99 | In-band management VLAN | `192.168.99.0/24` | `192.168.99.1` |
| OOB management | DevOps automation/control plane | `10.200.0.0/24` | Direct L2 management network |
| FRR loopbacks | Routing validation loopbacks | `10.255.0.0/24` | Advertised by OSPF |
| DMZ | Exposed services | `172.16.50.0/24` | `172.16.50.1` |
| External/cloud link | Edge external connectivity | `203.0.113.0/30` | `203.0.113.1` |

## Dedicated DevOps VM

The final control node is a dedicated Ubuntu DevOps VM.

| Interface | Role | Addressing |
|---|---|---|
| `ens33` | Internet / package updates / GitHub | DHCP via VMware NAT |
| `ens34` | OOB management access | `10.200.0.10/24` |

The DevOps VM should not use `ens34` as its default gateway. Its default route stays on the NAT interface.

The DevOps VM uses the OOB network for SSH, Ansible and future Jenkins automation.

## Out-of-Band Management IP Plan

| Node | OOB interface | OOB IP |
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

The OOB interfaces must remain outside OVS bridges and outside production routing.

## Endpoint and Service Nodes

| Host | Zone / VLAN | IP Address | Gateway | Validation method |
|---|---|---|---|---|
| PC1 | VLAN 10 | `192.168.10.11/24` | `192.168.10.1` | VPCS connectivity test |
| PC2 | VLAN 10 | `192.168.10.12/24` | `192.168.10.1` | VPCS connectivity test |
| PC3 | VLAN 20 | `192.168.20.13/24` | `192.168.20.1` | VPCS connectivity test |
| Web Server | DMZ | `172.16.50.10/24` | `172.16.50.1` | HTTP health check |
| DNS Server | DMZ | `172.16.50.20/24` | `172.16.50.1` | DNS health check |

## Internal OVS Management IPs

Internal OVS nodes keep an internal interface named `mgmt0` on VLAN 99.

These addresses remain part of the in-band management VLAN but are no longer the primary Ansible control path.

| OVS Node | Management Interface | In-band Management IP | Gateway |
|---|---|---|---|
| Dist-OVS-1 | `mgmt0` | `192.168.99.31/24` | `192.168.99.1` |
| Dist-OVS-2 | `mgmt0` | `192.168.99.32/24` | `192.168.99.1` |
| Access-OVS-4 | `mgmt0` | `192.168.99.44/24` | `192.168.99.1` |
| Access-OVS-5 | `mgmt0` | `192.168.99.45/24` | `192.168.99.1` |
| Access-OVS-6 | `mgmt0` | `192.168.99.46/24` | `192.168.99.1` |

## DMZ-OVS Management

DMZ-OVS-3 is managed through the OOB network.

| Node | OOB Interface | OOB IP | Management path |
|---|---|---|---|
| DMZ-OVS-3 | `eth3` | `10.200.0.33/24` | DevOps VM -> OOB management plane |

The previous `172.16.50.3/24` DMZ management path is no longer the primary SSH/Ansible path.

## FRR Routed Management Loopbacks

FRR routers keep loopback addresses advertised by OSPF for routing validation.

| Router | Loopback IP |
|---|---|
| Core-FRR-1 | `10.255.0.11/32` |
| Core-FRR-2 | `10.255.0.12/32` |
| Dist-FRR-1 | `10.255.0.21/32` |
| Dist-FRR-2 | `10.255.0.22/32` |
| EdgeRouter-VPNGateway | `10.255.0.30/32` |

These loopbacks validate production routing. They are no longer the primary Ansible SSH path.

## External / Cloud Link

| Device | Interface | IP Address | Peer |
|---|---|---|---|
| EdgeRouter-VPNGateway | `eth3` | `203.0.113.2/30` | `203.0.113.1` |
| External / Cloud Gateway | `eth0` | `203.0.113.1/30` | EdgeRouter `eth3` |

## VPCS Configuration Commands

```text
PC1> ip 192.168.10.11/24 192.168.10.1
PC2> ip 192.168.10.12/24 192.168.10.1
PC3> ip 192.168.20.13/24 192.168.20.1
```

## Service Host IP Scripts

The custom service images use:

```text
hosts/web-server.sh -> /opt/pfe/host-ip.sh inside the Web image
hosts/dns-server.sh -> /opt/pfe/host-ip.sh inside the DNS image
```