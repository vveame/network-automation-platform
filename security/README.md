# Security Configuration

This folder contains the versioned security scripts used in the GNS3 on-premises infrastructure.

## Security Objectives

The security design follows these principles:

- Administrative access is limited to the dedicated DevOps server.
- User VLANs cannot initiate access to the management VLAN.
- The DMZ is isolated from internal networks except for explicit service and management exceptions.
- OSPF routing exchanges are authenticated.
- NAT is enabled only on the EdgeRouter external/cloud-facing interface.

## Active Scripts

| File | Applied On | Purpose |
|---|---|---|
| `admin-access-control.sh` | All SSH-managed FRR and OVS nodes | Allows SSH only from the DevOps server `192.168.99.10` |
| `management-vlan-protection.sh` | `Dist-FRR-1`, `Dist-FRR-2` | Blocks user VLANs from initiating traffic to VLAN 99 |
| `dmz-isolation.sh` | `EdgeRouter-VPNGateway` | Controls internal-to-DMZ, DMZ-to-internal and DevOps-to-DMZ-OVS flows |
| `nat-control.sh` | `EdgeRouter-VPNGateway` | Applies controlled NAT on the external interface |
| `ospf-auth.sh` | FRR routers | Applies OSPF message-digest authentication |

## Administrative Access Control

The DevOps server is the only administrative source:

```text
DevOps server: 192.168.99.10
```

Allowed:

```text
192.168.99.10 -> managed nodes TCP/22
```

Denied:

```text
Any other source -> managed nodes TCP/22
```

`admin-access-control.sh` uses a dedicated `PFE_ADMIN_INPUT` chain to avoid duplicate rules when bootstrap scripts are re-run.

## Management VLAN Protection

VLAN 99 is the management network:

```text
192.168.99.0/24
```

Policy:

| Source | Destination | Action |
|---|---|---|
| VLAN 99 | VLAN 10 / VLAN 20 | Allow |
| VLAN 10 / VLAN 20 | VLAN 99 | Drop |
| Established/related traffic | Any | Allow |

`management-vlan-protection.sh` uses the `PFE_MGMT_FORWARD` chain to keep repeated bootstrap runs clean.

## DMZ Isolation

DMZ network:

```text
172.16.50.0/24
```

DMZ nodes:

| Node | IP | Role |
|---|---|---|
| `DMZ-OVS-3` | `172.16.50.3` | DMZ switch management IP |
| Web server | `172.16.50.10` | HTTP service |
| DNS server | `172.16.50.20` | DNS service |

Allowed internal-to-DMZ flows:

| Source | Destination | Service |
|---|---|---|
| `192.168.0.0/16` | `172.16.50.10` | TCP/80, TCP/443 |
| `192.168.0.0/16` | `172.16.50.20` | UDP/53, TCP/53 |
| `192.168.99.10` | `172.16.50.3` | TCP/22 and ICMP |

Denied:

```text
DMZ -> internal networks by default
Internal -> DMZ except explicit allowed services above
```

The DMZ switch is not connected directly to VLAN 99. Its management traffic crosses EdgeRouter and is controlled by `dmz-isolation.sh`.

## FRR Routed Management

FRR routers are managed through loopback IPs advertised by OSPF:

| Router | Management loopback |
|---|---|
| Core-FRR-1 | `10.255.0.11/32` |
| Core-FRR-2 | `10.255.0.12/32` |
| Dist-FRR-1 | `10.255.0.21/32` |
| Dist-FRR-2 | `10.255.0.22/32` |
| EdgeRouter-VPNGateway | `10.255.0.30/32` |

SSH to these loopbacks is still restricted to `192.168.99.10` by `admin-access-control.sh`.