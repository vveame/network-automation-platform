# Intelligent Network Automation Platform

This repository contains the versioned configuration files for the local network infrastructure used in the intelligent network automation platform.

## Objective

The objective is to transform a manually validated GNS3 topology into a reproducible and automatable infrastructure baseline.

The platform separates infrastructure nodes into three operational categories:

```text
Network infrastructure nodes:
  SSH required and managed by Ansible

Service nodes:
  SSH not required; validated through health checks

Endpoint/test hosts:
  SSH not required; validated through connectivity tests
```

The final local architecture follows a clear separation between:

```text
Production / Data Plane:
  VLANs, routing, DMZ, NAT, firewall rules, user/service traffic

Management / Control Plane:
  DevOps server, SSH, Ansible, Jenkins, infrastructure administration
```

## Current Architecture

The current scope covers the local on-premises topology and the dedicated DevOps control VM.

The topology contains:

- A three-tier internal network architecture.
- A DMZ service zone.
- A dedicated out-of-band management plane.
- A DevOps control VM used for automation, validation and future CI/CD orchestration.

### DevOps Control Node

The DevOps server is a dedicated Ubuntu VM. It has two interfaces:

| Interface | Role | Configuration |
|---|---|---|
| ens33 | Internet / package updates / GitHub | DHCP through VMware NAT |
| ens34 | Out-of-band management network | 10.200.0.10/24 |

Lab routes are configured permanently through Netplan:

```bash
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: true

    ens34:
      dhcp4: false
      addresses:
        - 10.200.0.10/24
      routes:
        - to: 172.16.50.0/24
          via: 10.200.0.30
```

The DevOps VM is the central control node for:

- Ansible.
- Jenkins.
- Git/GitHub integration.
- Terraform.
- SSH-based infrastructure administration.
- Automated validation of the local topology.

### Management Model

The final management model uses a dedicated out-of-band management network for SSH and Ansible access to infrastructure nodes.

| Node family | Management method |
|---|---|
| Internal OVS switches | SSH over OOB network `10.200.0.0/24` |
| FRR routers | SSH over OOB network `10.200.0.0/24` |
| DMZ-OVS-3	| SSH over OOB network `10.200.0.0/24` |
| Web server | HTTP health check only |
| DNS server | DNS health check only |
| VPCS endpoints | Connectivity tests only |

The old VLAN 99 management segment remains part of the production topology as an in-band management VLAN, but it is no longer the primary DevOps automation path.

```text
VLAN 99:
  In-band management VLAN inside the simulated enterprise topology

OOB 10.200.0.0/24:
  Dedicated DevOps / Ansible / Jenkins control plane
```

## Out-of-Band Management Plane

The out-of-band management plane provides a stable automation path independent of the production network.

It is used by the DevOps VM to reach infrastructure nodes even when production VLANs, OSPF routes, firewall policies or DMZ rules are being tested or modified.

### OOB Network

```text
OOB subnet: 10.200.0.0/24
DevOps VM: 10.200.0.10
```

### OOB IP Plan

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

## Implemented Components

- Three-tier GNS3 on-premises topology.
- Open vSwitch access, distribution and DMZ switching.
- VLAN 10, VLAN 20 and VLAN 99 segmentation.
- VLAN 99 in-band management segment.
- Dedicated OOB management plane for DevOps automation.
- OOB interface configuration for FRR and OVS infrastructure nodes.
- FRRouting routers for distribution, core and edge layers.
- OSPF dynamic routing.
- FRR routed loopback management addresses for routing validation.
- VRRP-style redundant gateways at the distribution layer.
- DMZ with custom Web and DNS Docker service images.
- DMZ isolation through EdgeRouter firewall rules.
- Security rules for admin access control, management VLAN protection, DMZ isolation, NAT control and OSPF authentication.
- SSH-enabled FRR and OVS custom Docker images.
- Root key-only SSH access for managed infrastructure nodes.
- Running-container and persistent-volume bootstrap scripts.
- Ansible inventory, readiness gates and validation playbooks.
- Dedicated service health checks for Web and DNS nodes.
- Connectivity tests for endpoint/test hosts.
- Flask validation dashboard microservice for readable Ansible report visualization.
- DTO, repository and service layers for structured dashboard logic.
- JSON API endpoint for future Jenkins integration.

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
├── dashboard/
│   ├── app.py
│   ├── requirements.txt
│   ├── dto/
│   ├── repositories/
│   ├── services/
│   ├── templates/
│   └── static/
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
├── management/
│   ├── oob-mgmt.sh
│   └── oob/
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

OVS provides:

- VLAN access ports.
- VLAN trunk links.
- VLAN 10 user segment.
- VLAN 20 user segment.
- VLAN 99 in-band management segment.
- RSTP-capable switching baseline.
- Dedicated OOB Linux interface for SSH/Ansible access.

The OOB interface on OVS nodes must remain outside br0.

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
- Routed loopback addresses for routing validation.
- Dedicated OOB Linux interface for SSH/Ansible access.

## Security

Security is implemented through versioned scripts using Linux firewall rules and FRR configuration.

Security includes:

- SSH/admin access restricted to the DevOps OOB IP 10.200.0.10.
- ICMP allowed from the DevOps OOB IP for readiness checks.
- Management VLAN protection.
- DMZ isolation.
- Controlled DMZ service access.
-NAT control on the EdgeRouter.
- OSPF authentication.
- Root key-only SSH access on managed infrastructure containers.

## Docker Automation

Custom Docker entrypoints are used to start and initialize FRR and OVS containers.

The FRR and OVS entrypoints handle:

- Directory initialization.
- SSH host key generation.
- DevOps public key installation.
- Root key-only SSH preparation.
- Interface configuration.
- OOB management interface configuration.
- OVS/FRR service startup.
- Security script execution.
- SSH daemon startup.

This prepares the platform for automation through Ansible and Jenkins.

## Deployment Logic

The intended deployment order is:

1. Start GNS3 topology nodes.
2. Apply OVS bridge, VLAN and trunk configuration.
3. Apply OVS in-band management VLAN configuration if enabled.
4. Apply OOB management interface configuration.
5. Apply FRR interface configuration.
6. Start FRR daemons.
7. Apply FRR routing configuration.
8. Apply OSPF authentication.
9. Apply role-specific security rules.
10. Apply SSH/admin access restrictions.
11. Validate OOB reachability from the DevOps VM.
12. Validate Ansible SSH connectivity.
13. Validate OVS, FRR, DMZ, security and end-to-end behavior.

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

## Validation Dashboard Microservice

A lightweight Flask dashboard microservice is included to transform raw Ansible validation outputs into a readable web interface.

The dashboard reads:

```text
ansible/outputs/*.txt
ansible/group_vars/all.yml
```

It displays:

- Global validation status.
- Total, passed, failed and missing report counters.
- Validation domains grouped by category.
- OOB management information.
- Infrastructure node matrix.
- OVS and FRR validation summaries.
- DMZ service health status.
- Security and end-to-end validation summaries.
- Full raw report access when detailed inspection is needed.
- JSON API endpoint for future Jenkins integration.

The dashboard follows a small microservice-style structure using:

DTO layer for structured dashboard objects.
Repository layer for reading Ansible variables and output reports.
Service layer for parsing reports and building dashboard data.
Flask routes for UI and API exposure.

### Dashboard Purpose

The dashboard is not responsible for changing the network state.
It only visualizes validation artifacts generated by Ansible.

### Run Dashboard Locally

```bash
py -m venv dashboard/.venv
source dashboard/.venv/Scripts/activate

python -m pip install --upgrade pip
python -m pip install -r dashboard/requirements.txt

python dashboard/app.py
```

## Final Management Principle

The final architecture keeps both management concepts:

```text
VLAN 99:
  In-band management VLAN inside the simulated enterprise network

OOB 10.200.0.0/24:
  Dedicated DevOps automation and infrastructure control plane
```

Ansible and Jenkins use the OOB network as the primary control path.

The production topology remains the validation target.

Validation results are generated by Ansible and visualized through the Flask dashboard microservice.