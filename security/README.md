# Security Configuration

This folder contains the versioned security scripts used by the GNS3 local infrastructure.

The security design separates:

```text
Production/data-plane security
OOB management security
Cloud monitoring access security
Hybrid tunnel underlay and tunnel routing
```

## Security Objectives

The security baseline follows these principles:

```text
Administrative SSH access is limited to the DevOps OOB IP.
OOB management traffic is separated from production traffic.
User VLANs cannot initiate access to the in-band management VLAN.
The DMZ is isolated from internal networks except explicit service rules.
OSPF routing exchanges are authenticated.
NAT is controlled on the EdgeRouter cloud-facing/WAN interface.
Cloud monitoring access is explicitly allowed for the private AWS monitoring EC2.
Service nodes are validated through health checks instead of SSH.
```

## Active Scripts

| File                            | Applied On                       | Purpose                                                           |
| ------------------------------- | -------------------------------- | ----------------------------------------------------------------- |
| `admin-access-control.sh`       | FRR and OVS infrastructure nodes | Allows SSH/ICMP administration only from DevOps OOB IP            |
| `management-vlan-protection.sh` | Distribution routers             | Protects VLAN 99 from user VLANs                                  |
| `dmz-isolation.sh`              | EdgeRouter-VPNGateway            | Controls internal-to-DMZ and DMZ-to-internal flows                |
| `nat-control.sh`                | EdgeRouter-VPNGateway            | Enables controlled NAT on the EdgeRouter direct WAN interface     |
| `ospf-auth.sh`                  | FRR routers                      | Applies OSPF message-digest authentication                        |
| `cloud-monitoring-access.sh`    | FRR and OVS OOB-managed nodes    | Allows AWS cloud Prometheus/SNMP access through the hybrid tunnel |

## Management Security Model

The final architecture uses two management concepts:

```text
VLAN 99:
  In-band management VLAN inside the simulated enterprise topology

OOB 10.200.0.0/24:
  Dedicated DevOps automation and infrastructure control plane
```

The OOB network is the primary SSH, Ansible, Jenkins and monitoring control path.

The DevOps OOB IP is:

```text
10.200.0.10
```

The EdgeRouter OOB IP is:

```text
10.200.0.30
```

## EdgeRouter NAT Control

The final topology uses direct EdgeRouter internet underlay.

The EdgeRouter interface model is:

```text
eth3  Direct WAN / GNS3 NAT / internet underlay
eth4  OOB management / 10.200.0.30
wg0   WireGuard tunnel to AWS
```

`nat-control.sh` is responsible for:

```text
Bringing eth3 up
Requesting DHCP on eth3
Enabling IPv4 forwarding
Installing idempotent NAT rules
Installing idempotent forwarding rules
```

It is installed persistently under:

```text
/etc/local/security/nat-control.sh
```

and is called automatically by the FRR container entrypoint.

The final model does not require DevOps NAT underlay.

## Cloud Monitoring Access

`cloud-monitoring-access.sh` allows cloud Prometheus to scrape local SNMPv3 targets through the hybrid tunnel.

Default sources:

```text
Primary cloud monitoring EC2: 10.50.30.154
WireGuard gateway-side source: 10.255.0.1
```

Default AWS VPC:

```text
10.50.0.0/16
```

Default EdgeRouter OOB gateway:

```text
10.200.0.30
```

The script installs:

```text
Return route to AWS VPC through EdgeRouter
ICMP allow rules from cloud monitoring sources
UDP/1161 allow rules from cloud monitoring sources
```

This script is used by:

```text
scripts/devops/apply-cloud-monitoring-access-to-oob-nodes.sh
gns3/scripts/bootstrap-persistent-gns3.sh
FRR and OVS container entrypoints
```

## DMZ Isolation

DMZ network:

```text
172.16.50.0/24
```

DMZ services:

| Node       | IP           | Role                   |
| ---------- | ------------ | ---------------------- |
| Web server | 172.16.50.10 | HTTP service           |
| DNS server | 172.16.50.20 | DNS service            |
| DMZ-OVS-3  | 10.200.0.33  | OOB-managed DMZ switch |

Allowed internal-to-DMZ flows:

```text
192.168.0.0/16 -> 172.16.50.10 TCP/80, TCP/443
192.168.0.0/16 -> 172.16.50.20 UDP/53, TCP/53
```

Denied:

```text
DMZ -> internal networks by default
Internal -> DMZ except explicit allowed services
```

DMZ infrastructure is managed through OOB, not through production DMZ exceptions.

## Management VLAN Protection

VLAN 99 remains the in-band management VLAN inside the simulated topology.

```text
VLAN 99: 192.168.99.0/24
```

Policy:

```text
VLAN 99 -> FRR loopbacks: allowed
FRR loopbacks -> VLAN 99: allowed
VLAN 10 / VLAN 20 -> VLAN 99: denied
Established/related traffic: allowed
```

## OSPF Authentication

`ospf-auth.sh` applies OSPF message-digest authentication on FRR production routing links.

OSPF secrets are local-only and should be stored under:

```text
secrets/ospf.env
```

Do not commit real OSPF secrets.

## Administrative Access Control

`admin-access-control.sh` restricts administrative access to the DevOps OOB IP.

Allowed:

```text
10.200.0.10 -> managed nodes TCP/22
10.200.0.10 -> managed nodes ICMP
```

Denied:

```text
Any other source -> managed nodes TCP/22
```

## Persistent Installation

Security scripts are copied into GNS3 persistent node directories by:

```text
gns3/scripts/bootstrap-persistent-gns3.sh
```

Live repair can also be performed from DevOps using:

```text
scripts/devops/apply-cloud-monitoring-access-to-oob-nodes.sh
scripts/devops/restore-full-hybrid-tunnel.sh
```

## Secret Policy

Do not commit:

```text
secrets/ospf.env
secrets/edge-router-wg0.conf.secret
frr/wireguard/edge-underlay.env
frr/wireguard/edge-router-wg0.conf
SNMP auth local files
AWS credentials
private SSH keys
WireGuard private keys
```

Safe to commit:

```text
.example files
security scripts
README files
non-secret templates
```
