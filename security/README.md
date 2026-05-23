# Security Configuration

This folder contains the versioned security scripts used in the GNS3 on-premises infrastructure.

## Security Objectives

The security design follows these principles:

- Administrative SSH access is limited to the dedicated DevOps server through the out-of-band management network.
- OOB management traffic is separated from production/data-plane traffic.
- User VLANs cannot initiate access to the in-band management VLAN.
- The DMZ is isolated from internal networks except for explicit service rules.
- OSPF routing exchanges are authenticated.
- NAT is enabled only on the EdgeRouter external/cloud-facing interface.
- Service nodes are validated through health checks instead of SSH.

## Management Security Model

The final architecture uses two management concepts:

```text
VLAN 99:
  In-band management VLAN inside the simulated enterprise network

OOB 10.200.0.0/24:
  Dedicated DevOps automation and infrastructure control plane
```

The OOB network is the primary SSH/Ansible/Jenkins control path.

The VLAN 99 network remains part of the production topology as an in-band management segment, but it is no longer the main DevOps automation path.

## Active Scripts

| File | Applied On | Purpose |
|---|---|---|
| `admin-access-control.sh` | All SSH-managed FRR and OVS infrastructure nodes | Allows SSH only from the DevOps OOB IP `10.200.0.10` |
| `management-vlan-protection.sh` | `Dist-FRR-1`, `Dist-FRR-2` | Protects VLAN 99 from user VLANs |
| `dmz-isolation.sh` | `EdgeRouter-VPNGateway` | Controls internal-to-DMZ and DMZ-to-internal production flows |
| `nat-control.sh` | `EdgeRouter-VPNGateway` | Applies controlled NAT on the external/cloud-facing interface |
| `ospf-auth.sh` | FRR routers | Applies OSPF message-digest authentication on production routing links |

### Administrative Access Control

The DevOps server is the only administrative SSH source:

```text
DevOps OOB IP: 10.200.0.10
```

Allowed:

```text
10.200.0.10 -> managed infrastructure nodes TCP/22
10.200.0.10 -> managed infrastructure nodes ICMP
```

Denied:

```text
Any other source -> managed infrastructure nodes TCP/22
```

`admin-access-control.sh` uses a dedicated PFE_ADMIN_INPUT chain to avoid duplicate rules when bootstrap scripts are re-run.

The script allows ICMP from the DevOps OOB IP for readiness checks and troubleshooting.

### Management VLAN Protection

VLAN 99 remains the in-band management VLAN inside the production topology:

```text
192.168.99.0/24
```

Policy:

| Source | Destination | Action |
|---|---|---|
| VLAN 99 | FRR loopbacks `10.255.0.0/24` | Allow |
| FRR loopbacks `10.255.0.0/24` | VLAN 99 | Allow |
| VLAN 99 | VLAN 10 / VLAN 20 | Allow if needed for admin/testing |
| VLAN 10 / VLAN 20 | VLAN 99 | Drop |
| Established/related traffic | Any | Allow |

`management-vlan-protection.sh` uses the PFE_MGMT_FORWARD chain to keep repeated bootstrap runs clean.

The script does not drop ctstate INVALID traffic because the distribution routers can use ECMP/asymmetric routed paths, and conntrack can mark legitimate return traffic as invalid in this lab environment.

### DMZ Isolation

DMZ network:

```text
172.16.50.0/24
```

DMZ nodes:

| Node | IP | Role |
|---|---|---|
| Web server  | `172.16.50.10` | HTTP service |
| DNS server  | `172.16.50.20` | DNS service |
| `DMZ-OVS-3` | `10.200.0.33`  | OOB-managed infrastructure switch |

Allowed internal-to-DMZ production flows:

| Source | Destination | Service |
|---|---|---|
| `192.168.0.0/16` | `172.16.50.10` | TCP/80, TCP/443 |
| `192.168.0.0/16` | `172.16.50.20` | UDP/53, TCP/53 |


Denied:

```text
DMZ -> internal networks by default
Internal -> DMZ except explicit allowed services above
```

DMZ-OVS-3 is no longer managed through 172.16.50.3 via EdgeRouter firewall exceptions. It is managed through the OOB network using 10.200.0.33.

### FRR Loopbacks

FRR routers still use loopback addresses advertised by OSPF for routing validation:

| Router | Loopback IP |
|---| ---|
| Core-FRR-1 | `10.255.0.11/32` |
| Core-FRR-2 | `10.255.0.12/32` |
| Dist-FRR-1 | `10.255.0.21/32` |
| Dist-FRR-2 | `10.255.0.22/32` |
| EdgeRouter-VPNGateway | `10.255.0.30/32` |

These loopbacks are no longer the primary Ansible SSH path. Ansible uses the OOB IPs in 10.200.0.0/24.

### NAT Control

NAT is applied only on the EdgeRouter external/cloud-facing interface.

| Source | NAT Interface  |
|---|---|
| `192.168.0.0/16` | Edge external interface |
| `172.16.50.0/24` | Edge external interface |

### OSPF Authentication

`ospf-auth.sh` applies message-digest authentication only on production routing links.