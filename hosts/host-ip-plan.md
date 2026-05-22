# Host and Management IP Plan

This file documents addressing for end hosts, services, OVS management interfaces, FRR routed management loopbacks and the external/cloud link.

## VLANs and Networks

| Zone / VLAN | Role | Network | Gateway / Next hop |
|---|---|---|---|
| VLAN 10 | User network | `192.168.10.0/24` | `192.168.10.1` |
| VLAN 20 | User network | `192.168.20.0/24` | `192.168.20.1` |
| VLAN 99 | Internal management / DevOps | `192.168.99.0/24` | `192.168.99.1` |
| FRR routed management | Router loopback management | `10.255.0.0/24` | via `192.168.99.1` from DevOps VM |
| DMZ | Exposed services | `172.16.50.0/24` | `172.16.50.1` |

## Dedicated DevOps VM

The final control node is a dedicated Ubuntu DevOps VM.

| Interface | Role | Addressing |
|---|---|---|
| `ens33` | Internet / package updates / GitHub | DHCP via VMware NAT |
| `ens34` | Lab management access | `192.168.99.10/24` |

The DevOps VM should not use `ens34` as its default gateway. Its default route stays on the NAT interface, while lab routes point to `192.168.99.1`.

Required lab routes on the DevOps VM:

```text
10.255.0.0/24 via 192.168.99.1
172.16.50.0/24 via 192.168.99.1
192.168.10.0/24 via 192.168.99.1
192.168.20.0/24 via 192.168.99.1
```

## Endpoint and Service Nodes

| Host | Zone / VLAN | IP Address | Gateway | Validation method |
|---|---|---|---|---|
| PC1 | VLAN 10 | `192.168.10.11/24` | `192.168.10.1` | VPCS connectivity test |
| PC2 | VLAN 10 | `192.168.10.12/24` | `192.168.10.1` | VPCS connectivity test |
| PC3 | VLAN 20 | `192.168.20.13/24` | `192.168.20.1` | VPCS connectivity test |
| Web Server | DMZ | `172.16.50.10/24` | `172.16.50.1` | HTTP health check |
| DNS Server | DMZ | `172.16.50.20/24` | `172.16.50.1` | DNS health check |

## Internal OVS Management IPs

Internal OVS nodes use an internal interface named `mgmt0` on VLAN 99.

| OVS Node | Management Interface | Management IP | Gateway |
|---|---|---|---|
| Dist-OVS-1 | `mgmt0` | `192.168.99.31/24` | `192.168.99.1` |
| Dist-OVS-2 | `mgmt0` | `192.168.99.32/24` | `192.168.99.1` |
| Access-OVS-4 | `mgmt0` | `192.168.99.44/24` | `192.168.99.1` |
| Access-OVS-5 | `mgmt0` | `192.168.99.45/24` | `192.168.99.1` |
| Access-OVS-6 | `mgmt0` | `192.168.99.46/24` | `192.168.99.1` |

## DMZ-OVS Management

`DMZ-OVS-3` is not connected directly to VLAN 99. It is managed through the DMZ path and EdgeRouter firewall rules.

| Node | Interface | Management IP | Gateway | Management path |
|---|---|---|---|---|
| DMZ-OVS-3 | `mgmt0` | `172.16.50.3/24` | `172.16.50.1` | DevOps VM -> EdgeRouter -> DMZ |

## FRR Routed Management Loopbacks

FRR routers use loopback management addresses advertised by OSPF.

| Router | Loopback management IP |
|---|---|
| Core-FRR-1 | `10.255.0.11/32` |
| Core-FRR-2 | `10.255.0.12/32` |
| Dist-FRR-1 | `10.255.0.21/32` |
| Dist-FRR-2 | `10.255.0.22/32` |
| EdgeRouter-VPNGateway | `10.255.0.30/32` |

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