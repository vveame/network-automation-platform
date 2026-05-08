# Intelligent Network Automation Platform

This repository contains the versioned configuration files for the local network infrastructure used in the intelligent network automation platform.

## Objective

The goal is to transform a manually validated GNS3 topology into reusable, traceable and automatable configuration files.

The repository acts as the source of truth for:

- Network configuration.
- Routing configuration.
- VLAN and trunk configuration.
- Security rules.
- Docker startup automation.
- Future Jenkins and Ansible automation.

## Current Scope

The current implementation focuses on the local GNS3 infrastructure.

Implemented and versioned components:

- Open vSwitch Layer 2 switching.
- VLAN access and trunk configuration.
- OVS management interfaces for SSH automation.
- FRRouting Layer 3 routing.
- OSPF dynamic routing.
- VRRP gateway redundancy at the distribution layer.
- EdgeRouter external interface for NAT and future VPN.
- Security scripts for management VLAN protection, DMZ isolation, NAT control, admin access control and OSPF authentication.
- Custom Docker startup scripts for FRR and OVS nodes.

Planned for later phases:

- Ansible playbooks.
- Jenkins pipeline.
- Terraform cloud provisioning.
- Monitoring with Prometheus, Fluentd and Grafana.
- AI-based anomaly detection.
- Automated remediation workflows.

## Repository Structure

```text
.
├── docker/
│   ├── frr-ssh/
│   └── ovs-ssh/
│
├── frr/
│   ├── env/
│   ├── interfaces/
│   ├── routing/
│   └── startup/
│
├── gns3/
│   ├── node-mapping.md
│   └── startup-order.md
│
├── hosts/
│   ├── host-ip-plan.md
│   ├── devops-server-ip.sh
│   ├── web-server-ip.sh
│   └── dns-server-ip.sh
│
├── ovs/
│   ├── access/
│   ├── distribution/
│   ├── dmz/
│   └── management/
│
├── security/
│   ├── admin-access-control.sh
│   ├── management-vlan-protection.sh
│   ├── dmz-isolation.sh
│   ├── nat-control.sh
│   └── ospf-auth.sh
│
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

## Current Status

The initial GNS3 topology has been validated manually.

The working configuration is being converted into versioned, reusable files to prepare for automation with Jenkins and Ansible.