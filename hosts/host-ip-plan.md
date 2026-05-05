# Host IP Plan

This file documents the IP addressing used for end hosts and servers in the local GNS3 infrastructure.

## VLANs and Networks

| Zone / VLAN | Role | Network | Default Gateway |
|---|---|---|---|
| VLAN 10 | HR / User Network | 192.168.10.0/24 | 192.168.10.1 |
| VLAN 20 | IT / User Network | 192.168.20.0/24 | 192.168.20.1 |
| VLAN 99 | Management / DevOps | 192.168.99.0/24 | 192.168.99.1 |
| DMZ | Exposed Services | 172.16.50.0/24 | 172.16.50.1 |

## End Hosts

| Host | Zone / VLAN | IP Address | Default Gateway | Description |
|---|---|---|---|---|
| PC1 | VLAN 10 | 192.168.10.11/24 | 192.168.10.1 | HR user workstation |
| PC2 | VLAN 10 | 192.168.10.12/24 | 192.168.10.1 | HR user workstation |
| PC3 | VLAN 20 | 192.168.20.13/24 | 192.168.20.1 | IT user workstation |
| DevOps Server | VLAN 99 | 192.168.99.10/24 | 192.168.99.1 | Management and automation server |
| Web Server | DMZ | 172.16.50.10/24 | 172.16.50.1 | Public-facing web service |
| DNS Server | DMZ | 172.16.50.20/24 | 172.16.50.1 | Public-facing DNS service |

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