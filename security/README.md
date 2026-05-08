# Security Configuration

This folder contains the versioned security and resilience scripts used in the local GNS3 infrastructure.

## Objectives

The security configuration aims to:

- Protect the management VLAN.
- Restrict administrative access to the DevOps server.
- Isolate the DMZ from internal networks.
- Secure OSPF routing exchanges.
- Control NAT usage.
- Prepare the infrastructure for future monitoring and automation.

## Active Security Scripts

| File | Applied On | Purpose |
|---|---|---|
| `admin-access-control.sh` | All SSH-enabled FRR and OVS nodes | Allows SSH/admin access only from the DevOps server |
| `management-vlan-protection.sh` | Dist-FRR-1 and Dist-FRR-2 | Blocks user VLANs from initiating access to VLAN 99 |
| `dmz-isolation.sh` | EdgeRouter-VPNGateway | Isolates the DMZ from internal VLANs and allows only required services |
| `nat-control.sh` | EdgeRouter-VPNGateway | Enables controlled NAT on the external/cloud-facing interface |
| `ospf-auth.sh` | All FRR routers participating in OSPF | Applies OSPF message-digest authentication on routed links |

## Security Deployment by Node

| Node | Scripts |
|---|---|
| Dist-FRR-1 | `ospf-auth.sh`, `management-vlan-protection.sh`, `admin-access-control.sh` |
| Dist-FRR-2 | `ospf-auth.sh`, `management-vlan-protection.sh`, `admin-access-control.sh` |
| Core-FRR-1 | `ospf-auth.sh`, `admin-access-control.sh` |
| Core-FRR-2 | `ospf-auth.sh`, `admin-access-control.sh` |
| EdgeRouter-VPNGateway | `ospf-auth.sh`, `dmz-isolation.sh`, `nat-control.sh`, `admin-access-control.sh` |
| OVS nodes | `admin-access-control.sh` |

## Management VLAN Protection

The management VLAN is used for administration and automation.
It contains the DevOps server and must be protected from direct access by user VLANs.

Networks:

| VLAN | Role | Network |
|---|---|---|
| VLAN 10 | HR / User VLAN | 192.168.10.0/24 |
| VLAN 20 | IT / User VLAN | 192.168.20.0/24 |
| VLAN 99 | Management / DevOps | 192.168.99.0/24 |

Policy:

| Source | Destination | Action |
|---|---|---|
| VLAN 10 | VLAN 99 | Deny |
| VLAN 20 | VLAN 99 | Deny |
| VLAN 99 | VLAN 10 | Allow |
| VLAN 99 | VLAN 20 | Allow |
| Established/related traffic | Any | Allow |

The rules are applied on the distribution FRR routers because inter-VLAN routing happens at the distribution layer.

## Administrative Access Control

Administrative access is restricted to the DevOps server.

| Source | Destination | Service | Action |
|---|---|---|---|
| DevOps Server `192.168.99.10` | Managed nodes | SSH / TCP 22 | Allow |
| Other sources | Managed nodes | SSH / TCP 22 | Deny |

This rule is applied on all SSH-enabled FRR and OVS nodes.

## DMZ Isolation

The DMZ hosts services exposed to users or external networks, such as the Web server and DNS server.  
It must be isolated from the internal network in order to limit the impact of a possible compromise of a public-facing service.

Networks:

| Zone | Network |
|---|---|
| Internal VLANs | 192.168.0.0/16 |
| DMZ | 172.16.50.0/24 |

DMZ Services:

| Server | IP Address | Allowed Services |
|---|---|---|
| Web Server | 172.16.50.10 | HTTP/HTTPS |
| DNS Server | 172.16.50.20 | DNS TCP/UDP 53 |

Policy:

| Source | Destination | Service | Action |
|---|---|---|---|
| Internal VLANs | Web Server | HTTP/HTTPS | Allow |
| Internal VLANs | DNS Server | DNS | Allow |
| Internal VLANs | DMZ | Other services | Deny |
| DMZ | Internal VLANs | Any | Deny |
| Established/related traffic | Any | Any | Allow |

The rules are applied on the EdgeRouter because it separates the DMZ from the internal network.

## NAT Control

NAT is applied only on the EdgeRouter external interface.

| Interface | Role |
|---|---|
| eth3 | External/cloud-facing interface |

NAT is used for Internet/external access, updates, repositories and external APIs.

NAT is not the main secure communication mechanism between the on-premise infrastructure and the cloud environment.

Future secure cloud communication should be handled through VPN.

## OSPF Authentication

OSPF authentication protects routing adjacencies between FRR routers. It ensures that only routers configured with the same authentication parameters can exchange OSPF routing information.

The project uses OSPF MD5 message-digest authentication on routed point-to-point links between FRR routers.

The real key is not stored in GitHub. It is loaded from:

```text
/etc/local/ospf.env
```

or from a local ignored file:

```text
secrets/ospf.env
```

Only the example file is versioned:

```text
secrets/ospf.env.example
```

Protected links:

| Link | Router A Interface | Router B Interface | Network |
|---|---|---|---|
| Dist-FRR-1 ↔ Core-FRR-1 | Dist-FRR-1 eth1 | Core-FRR-1 eth1 | 10.0.11.0/30 |
| Dist-FRR-1 ↔ Core-FRR-2 | Dist-FRR-1 eth2 | Core-FRR-2 eth1 | 10.0.12.0/30 |
| Dist-FRR-2 ↔ Core-FRR-1 | Dist-FRR-2 eth1 | Core-FRR-1 eth2 | 10.0.21.0/30 |
| Dist-FRR-2 ↔ Core-FRR-2 | Dist-FRR-2 eth2 | Core-FRR-2 eth2 | 10.0.22.0/30 |
| Core-FRR-1 ↔ EdgeRouter | Core-FRR-1 eth0 | EdgeRouter eth0 | 10.0.100.0/30 |
| Core-FRR-2 ↔ EdgeRouter | Core-FRR-2 eth0 | EdgeRouter eth1 | 10.0.101.0/30 |


## Verification Commands

Firewall Rules:

```bash
iptables -L INPUT -v -n --line-numbers
iptables -L FORWARD -v -n --line-numbers
iptables -t nat -L -v -n --line-numbers
```

OSPF:

```bash
vtysh -c "show ip ospf neighbor"
vtysh -c "show ip route ospf"
```

VRRP:

```bash
vtysh -c "show vrrp"
```