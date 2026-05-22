# Intelligent Network Automation Platform

This repository contains the versioned configuration files for the local network infrastructure used in the intelligent network automation platform.

## Objective

The objective is to transform a manually validated GNS3 topology into a reproducible and automatable infrastructure baseline. The final local architecture follows this management model:

```text
Network infrastructure nodes:
  SSH required and managed by Ansible

Service nodes:
  SSH not required; validated through health checks

Endpoint/test hosts:
  SSH not required; validated through connectivity tests
```

## Current Architecture

The current scope covers the local on-premises topology and the dedicated DevOps control VM.

### DevOps Control Node

The DevOps server is a dedicated Ubuntu VM. It has two interfaces:

| Interface | Role | Configuration |
|---|---|---|
| ens33 | Internet / package updates / GitHub | DHCP through VMware NAT |
| ens34 | GNS3 management and lab access | 192.168.99.10/24 |

Lab routes are configured permanently through Netplan:

```bash

network:
  version: 2
  ethernets:
    ens33:
      dhcp4: true
    ens34:
      addresses:
      - "192.168.99.10/24"
      routes:
        - to: 10.255.0.0/24
          via: 192.168.99.1
        - to: 172.16.50.0/24
          via: 192.168.99.1
        - to: 192.168.10.0/24
          via: 192.168.99.1
        - to: 192.168.20.0/24
          via: 192.168.99.1
```

### Management Model

| Node family | Management method |
|---|---|
| Internal OVS switches | SSH over VLAN 99 (`192.168.99.x`) |
| FRR routers | SSH over routed loopback management prefix (`10.255.0.0/24`) |
| DMZ-OVS-3	| SSH to `172.16.50.3` through EdgeRouter firewall exception |
| Web server | HTTP health check only |
| DNS server | DNS health check only |
| VPCS endpoints | Connectivity tests only |

## Implemented Components

- Open vSwitch access, distribution and DMZ switching.
- VLAN 10, VLAN 20 and VLAN 99 segmentation.
- OVS management interfaces for SSH/Ansible automation.
- FRRouting routers for distribution, core and edge layers.
- OSPF dynamic routing.
- FRR routed loopback management addresses.
- VRRP-style redundant gateways at the distribution layer.
- DMZ with custom Web and DNS Docker service images.
- DMZ-OVS management through EdgeRouter instead of a direct internal management link.
- Security rules for admin access control, management VLAN protection, DMZ isolation, NAT control and OSPF authentication.
- Running-container and persistent-volume bootstrap scripts.
- Ansible inventory, readiness gates and validation playbooks.

## Repository Structure

```text
.
├── ansible/
│   ├── group_vars/
│   ├── host_vars/
│   ├── inventory/
│   ├── playbooks/
│   ├── roles/
|   │   ├── dmz_validate/
|   │   ├── frr_validate/
|   │   ├── ovs_validate/
|   │   ├── security_validate/
|   │   └── report_collect/
│   └── ansible.cfg
├── docker/
│   ├── dns/
│   ├── frr-ssh/
│   ├── ovs-ssh/
│   └── web-nginx/
├── frr/
│   ├── env/
│   ├── interfaces/
│   ├── routing/
├── gns3/
│   ├── node-mapping.md
│   └── startup-order.md
├── hosts/
│   ├── host-ip-plan.md
│   ├── devops-server-ip.sh
│   ├── web-server-ip.sh
│   └── dns-server-ip.sh
├── ovs/
│   ├── access/
│   ├── distribution/
│   ├── dmz/
│   └── management/
├── security/
│   ├── admin-access-control.sh
│   ├── management-vlan-protection.sh
│   ├── dmz-isolation.sh
│   ├── nat-control.sh
│   └── ospf-auth.sh
├── scripts/
├── tests/
└── secrets/
    └── ospf.env.example
```

## Main Components

### Open vSwitch

Open vSwitch is used for Layer 2 switching, VLAN access ports and trunk links.

OVS nodes are organized into:

- Access layer switches.
- Distribution layer switches.
- DMZ switch.
- Management interfaces for SSH/Ansible access.

### FRRouting

FRRouting is used for Layer 3 routing.

FRR nodes are organized into:

- Distribution routers.
- Core routers.
- EdgeRouter/VPN gateway.

FRR provides:

- OSPF routing.
- VRRP gateway redundancy.
- Routing between internal networks, DMZ and external/cloud link.

## Security

Security is implemented through versioned scripts using Linux firewall rules and FRR configuration.

Security includes:

- Management VLAN protection.
- SSH/admin access restricted to the DevOps server.
- DMZ isolation.
- NAT control on the EdgeRouter.
- OSPF authentication.

## Docker Automation

Custom Docker entrypoints are used to start and initialize FRR and OVS containers.

This prepares the platform for future automation through Jenkins and Ansible.

## Deployment Logic

The intended deployment order is:

1. Start OVS containers.
2. Apply OVS bridge, VLAN and trunk configuration.
3. Apply OVS management IP configuration.
4. Start FRR containers.
5. Apply FRR interface configuration.
6. Start FRR daemons.
7. Apply FRR routing configuration.
8. Apply OSPF authentication.
9. Apply role-specific security rules.
10. Validate connectivity, OSPF, VRRP and firewall behavior.
11. Integrate Jenkins and Ansible for automated deployment.

## Bootstrap Scripts

Two bootstrap modes are provided.

### Running-container bootstrap

```bash
./bootstrap-gns3.sh
```

Use this when all GNS3 Docker nodes are already running. It copies configuration into the running containers and immediately applies the DMZ-OVS configuration.

### Persistent-volume bootstrap

```bash
./bootstrap-persistent-gns3.sh
```

Use this when containers may be stopped or exited. It writes the desired files into the GNS3 persistent directories so they are applied on the next container start.

## Ansible Workflow

Ansible is executed from the dedicated DevOps VM.

The site playbook runs:

1. Management readiness checks.
2. Ansible SSH connection readiness.
3. OVS validation.
4. FRR validation.
5. DMZ Web/DNS health checks.
6. Security behavior validation.
7. End-to-end connectivity validation.
8. Report summary generation in `ansible/outputs/`. 