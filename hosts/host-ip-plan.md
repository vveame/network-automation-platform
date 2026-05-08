# Host IP Plan

This file documents the IP addressing used for end hosts, servers, OVS management interfaces and the external/cloud link in the local GNS3 infrastructure.

## VLANs and Networks

| Zone / VLAN | Role | Network | Default Gateway |
|---|---|---|---|
| VLAN 10 | HR / User Network | 192.168.10.0/24 | 192.168.10.1 |
| VLAN 20 | IT / User Network | 192.168.20.0/24 | 192.168.20.1 |
| VLAN 99 | Management / DevOps | 192.168.99.0/24 | 192.168.99.1 |
| DMZ | Exposed Services | 172.16.50.0/24 | 172.16.50.1 |

## End Hosts and Servers

| Host | Zone / VLAN | IP Address | Default Gateway | Description |
|---|---|---|---|---|
| PC1 | VLAN 10 | 192.168.10.11/24 | 192.168.10.1 | HR user workstation |
| PC2 | VLAN 10 | 192.168.10.12/24 | 192.168.10.1 | HR user workstation |
| PC3 | VLAN 20 | 192.168.20.13/24 | 192.168.20.1 | IT user workstation |
| DevOps Server | VLAN 99 | 192.168.99.10/24 | 192.168.99.1 | Management and automation server |
| Web Server | DMZ | 172.16.50.10/24 | 172.16.50.1 | Public-facing web service |
| DNS Server | DMZ | 172.16.50.20/24 | 172.16.50.1 | Public-facing DNS service |

## OVS Management IPs

OVS nodes use an internal management interface named `mgmt0`.  
This interface belongs to VLAN 99 and is used for SSH/Ansible access from the DevOps server.

| OVS Node | Management Interface | Management IP | Gateway |
|---|---|---|---|
| Dist-OVS-1 | mgmt0 | 192.168.99.31/24 | 192.168.99.1 |
| Dist-OVS-2 | mgmt0 | 192.168.99.32/24 | 192.168.99.1 |
| Access-OVS-4 | mgmt0 | 192.168.99.44/24 | 192.168.99.1 |
| Access-OVS-5 | mgmt0 | 192.168.99.45/24 | 192.168.99.1 |
| Access-OVS-6 | mgmt0 | 192.168.99.46/24 | 192.168.99.1 |

## External / Cloud Link

| Device | Interface | IP Address | Gateway / Peer |
|---|---|---|---|
| EdgeRouter-VPNGateway | eth3 | 203.0.113.2/30 | 203.0.113.1 |
| External / Cloud Gateway | eth0 | 203.0.113.1/30 | Connected to EdgeRouter eth3 |

## EdgeRouter Default Route

| Device | Default Route |
|---|---|
| EdgeRouter-VPNGateway | 0.0.0.0/0 via 203.0.113.1 dev eth3 |

## VPCS Configuration Commands

### PC1

```bash
ip 192.168.10.11/24 192.168.10.1
save
```

### PC2

```bash
ip 192.168.10.12/24 192.168.10.1
save
```

### PC3

```bash
ip 192.168.20.13/24 192.168.20.1
save
```

## Linux Server Configuration Commands

- DevOps Server : `hosts/devops-server-ip.sh`

- Web Server : `hosts/web-server-ip.sh`

- DNS Server : `hosts/dns-server-ip.sh`