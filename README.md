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
├── ci-cd/
│   ├── github-actions-jenkins-bridge.md
│   ├── trigger-jenkins-pfe.example.sh
│   ├── jenkins-netrc.example
│   └── gha-runner-sudoers.example
├── dashboard/
│   ├── app.py
│   ├── config.py
│   ├── extensions.py
│   ├── global_error_handler.py
│   ├── requirements.txt
│   ├── dto/
│   ├── entity/
│   ├── mappe/
│   ├── repository/
│   ├── security/
│   ├── service/
│   ├── templates/
│   ├── web/
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
│   ├── startup-order.md
│   └── scripts/
│       ├── bootstrap-gns3.sh
│       ├── bootstrap-persistent-gns3.sh
│       └── gns3-status.sh
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
- NAT control on the EdgeRouter.
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
8. Inventory consistency validation
9. Report artifact validation
10. Jenkins-ready assertion gates
11. Report summary generation in `ansible/outputs/`. 

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

## Cloud Infrastructure Baseline

The project includes an initial AWS cloud infrastructure baseline provisioned with Terraform.

This cloud layer is the foundation for the future hybrid extension of the local GNS3 network automation platform. Its purpose is to prepare the AWS networking, security, storage, optional compute and future hybrid connectivity environment that will later host monitoring, analysis, logs, datasets and cloud-side services.

### Implemented Cloud Components

The current Terraform baseline includes:

* One AWS VPC.
* One public subnet.
* One private subnet.
* One monitoring / AI subnet.
* One Internet Gateway.
* One public route table.
* One private route table.
* One monitoring route table.
* Route table associations for the three subnets.
* Security group baseline for future cloud services.
* One private S3 bucket for future logs, metrics exports, AI outputs and reports.
* Optional compute module prepared for future EC2 instances.
* VPN / hybrid connectivity module prepared but disabled by default.

### Cloud CIDR Plan

```text
AWS VPC:              10.50.0.0/16
Public subnet:        10.50.10.0/24
Private subnet:       10.50.20.0/24
Monitoring/AI subnet: 10.50.30.0/24
```

The cloud CIDR range is separated from the local GNS3/on-premises addressing plan to prepare for future hybrid connectivity.

### Subnet Roles

| Subnet                 | Role                                                           |
| ---------------------- | -------------------------------------------------------------- |
| Public subnet          | Future bastion/admin access or public-facing cloud services    |
| Private subnet         | Future internal cloud services                                 |
| Monitoring / AI subnet | Future monitoring, observability and anomaly-analysis services |

Only the public subnet is connected to the Internet Gateway.

The private and monitoring subnets are intentionally isolated at this stage. They do not use a NAT Gateway yet in order to avoid unnecessary AWS costs during the student lab phase.

### Cloud Security Baseline

The Terraform security module defines the first AWS security group baseline:

| Security group                  | Purpose                                                     |
| ------------------------------- | ----------------------------------------------------------- |
| Admin security group            | Reserved for future bastion or management access            |
| Monitoring security group       | Reserved for future Prometheus and Grafana services         |
| AI security group               | Reserved for future anomaly detection / AI analysis service |
| Private services security group | Reserved for future internal cloud services                 |

The admin, Prometheus and Grafana access rules are restricted using the `admin_allowed_cidr` variable.

In the public example file, this value is intentionally set to:

```text
0.0.0.0/32
```

The real administrator public IP must be configured only in the local untracked `terraform.tfvars` file.

Additional internal SSH rules are prepared so that a future bastion/admin instance can access the future monitoring and AI instances through security group references.

### Cloud Storage Baseline

The Terraform storage module creates a private S3 bucket reserved for future platform artifacts.

The bucket is intended for:

* monitoring exports
* logs
* AI analysis outputs
* datasets
* Jenkins/cloud reports
* Jenkins/Ansible validation artifacts

The S3 bucket is configured with:

* public access blocking
* bucket owner enforced object ownership
* versioning
* server-side encryption using AES256
* lifecycle retention rules for validation artifacts

This storage baseline prepares the project for future monitoring and AI phases without exposing data publicly.

### Validation Artifact Retention

Jenkins uploads validation outputs to S3 after successful local validation.

Each Jenkins build writes to a dedicated S3 prefix:

```text
validation-artifacts/<jenkins-job-name>-<build-number>/
```

Manual uploads use a timestamped prefix:

```text
validation-artifacts/manual-<timestamp>/
```

This keeps each validation run immutable and traceable.

To avoid unnecessary long-term storage growth, the S3 bucket uses a lifecycle policy for the `validation-artifacts/` prefix:

```text
Validation artifacts: deleted after 30 days
Noncurrent object versions: deleted after 7 days
Incomplete multipart uploads: deleted after 1 day
```

This provides a balanced approach:

* recent Jenkins validation history remains available
* cloud storage does not grow forever
* future monitoring and AI services can consume recent validation artifacts from S3
* old artifacts are cleaned automatically by AWS lifecycle rules

### Cloud Compute Baseline

The Terraform compute module is prepared but disabled by default.

It is controlled using:

```hcl
enable_compute = false
```

When enabled later, the module will create optional EC2 placeholder instances for:

* bastion/admin access
* monitoring services
* AI/anomaly analysis services

At the current stage, no EC2 instances are created. This avoids unnecessary AWS costs while keeping the cloud architecture ready for the next implementation phase.

### Hybrid / VPN Baseline

The Terraform VPN module is prepared but disabled by default.

It is controlled using:

```hcl
enable_vpn = false
```

When enabled later, the module is designed to create:

* AWS Customer Gateway.
* AWS Virtual Private Gateway.
* AWS Site-to-Site VPN connection.
* Static VPN routes.
* VPC route table routes toward the on-premises CIDRs.

The intended hybrid design is:

```text
GNS3 EdgeRouter / VPN Gateway
        ↕
AWS Site-to-Site VPN
        ↕
AWS VPC
```

At the current stage, no VPN resources are created. This avoids unnecessary AWS VPN cost and prevents accidental exposure before the real on-premises public gateway strategy is selected.

The default on-premises CIDRs prepared for future VPN routing are:

```text
OOB management network: 10.200.0.0/24
Local routed lab space: 172.16.0.0/16
```

A real AWS Site-to-Site VPN requires a reachable public IP address for the on-premises customer gateway. If the GNS3 EdgeRouter is behind VMware NAT or a home router without a stable public endpoint, another hybrid connectivity strategy may be required.

### Terraform Structure

The Terraform cloud baseline is stored under:

```text
cloud/terraform/
```

The current environment is:

```text
cloud/terraform/environments/dev/
```

The Terraform modules are organized as:

```text
cloud/terraform/modules/
├── network/
├── security/
├── compute/
├── storage/
└── vpn/
```

At the current stage, the `network`, `security`, `storage`, optional `compute`, and disabled `vpn` modules are implemented.

### Current Cloud Status

The current Terraform implementation creates the AWS network, security and storage baseline only.

It does not create yet:

* EC2 instances.
* NAT Gateway.
* Active VPN connection.
* Monitoring services.
* AI analysis services.

These components will be added progressively in the next cloud implementation phases.

### Terraform Commands

From the DevOps VM:

```bash
cd cloud/terraform/environments/dev

terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

To apply the cloud baseline:

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

To inspect the deployed resource identifiers:

```bash
terraform output
```

### Terraform State and Secrets

Terraform state files, real variable files and plan files must not be committed to GitHub.

The following files remain local:

```text
terraform.tfvars
terraform.tfstate
terraform.tfstate.backup
tfplan
.terraform/
```

Only example files such as `terraform.tfvars.example` are versioned.

## CI/CD Integration with Jenkins and GitHub Actions

The project uses Jenkins as the main CI/CD automation server for validating and maintaining the local network automation platform.

Jenkins runs from the DevOps control VM and remains private inside the local lab. Because the GitHub repository is public, Jenkins is not exposed directly to the Internet. Instead, a GitHub Actions self-hosted runner is installed on the DevOps VM under a dedicated limited Linux user named `gha-runner`.

The runner does not build, test, deploy, or checkout the repository. Its only role is to act as a secure trigger bridge between GitHub and Jenkins.

When a push is made to the `main` branch, GitHub Actions runs the following protected local command on the DevOps VM:

```bash
sudo /usr/local/sbin/trigger-jenkins-pfe
```

This script triggers the Jenkins job through the local Jenkins API:

```text
http://10.200.0.10:8080
```

The Jenkins API token is not stored in GitHub. It is stored locally on the DevOps VM in:

```text
/root/.jenkins_netrc
```

### GitHub Actions Bridge

The GitHub Actions workflow is stored in:

```text
.github/workflows/trigger-jenkins.yml
```

It is triggered only by:

* push events on the `main` branch
* manual execution using `workflow_dispatch`

The workflow does not use `actions/checkout`. This prevents repository code from being executed directly by the self-hosted runner.

### Jenkins Pipeline Modes

The Jenkins pipeline is parameterized and supports multiple execution modes:

| Mode                 | Purpose                                                                                                               |
| -------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `AUTO`               | Default mode used by GitHub push triggers. Validates the topology and optionally builds/pushes changed Docker images. |
| `VALIDATE_ONLY`      | Runs validation, report generation and dashboard publishing only.                                                     |
| `BUILD_IMAGES`       | Builds all custom Docker images on the GNS3 host.                                                                     |
| `PUSH_IMAGES`        | Builds and pushes all custom Docker images to Docker Hub.                                                             |
| `BOOTSTRAP_GNS3`     | Runs the persistent GNS3 bootstrap process.                                                                           |
| `FULL_LOCAL_REFRESH` | Performs a complete local maintenance workflow including image refresh, bootstrap and validation.                     |

Topology-changing actions require:

```text
CONFIRM_APPLY=true
```

This confirmation is required for actions such as GNS3 bootstrap and full local refresh, because they modify the lab environment or persistent node configuration.

### Jenkins Pipeline Workflow

In its default validation workflow, Jenkins performs the following actions:

1. Cleans the workspace.
2. Checks out the repository.
3. Detects changed repository areas.
4. Prepares Ansible output directories.
5. Validates the Ansible inventory.
6. Runs Ansible syntax checks.
7. Executes the local topology validation gate.
8. Generates an HTML summary report.
9. Synchronizes reports to the Flask dashboard folder.
10. Archives validation outputs as Jenkins artifacts.
11. Updates the Jenkins build description with dashboard and artifact links.

### Docker Image Automation

Custom Docker images are used for the simulated GNS3 nodes:

* FRR routers.
* OVS switches.
* Web service node.
* DNS service node.

Docker build and push operations are delegated to the GNS3 host through SSH, because Docker is installed on the GNS3 VM and not on the DevOps VM.

This keeps the DevOps VM focused on orchestration, Ansible validation and reporting, while the GNS3 VM remains responsible for image building and topology-related Docker operations.

Important distinction:

```text
docker build  → creates or updates a local image on the GNS3 host
docker push   → publishes the image to Docker Hub
GNS3 nodes    → existing containers are not automatically recreated
```

Pushing a new image to Docker Hub does not automatically update already-created GNS3 nodes. Applying a new image to existing GNS3 nodes requires a controlled maintenance action, such as recreating the affected nodes or using a future GNS3 API-based refresh workflow.

### GNS3 Host Synchronization

For Docker build and bootstrap operations, Jenkins connects to the GNS3 host through SSH and synchronizes the local repository copy located at:

```text
/home/gns3/pfe-repo
```

The GitHub repository is treated as the source of truth for tracked files.

Real environment and secret files are not committed to GitHub. They are preserved locally on the GNS3 host, for example under:

```text
/home/gns3/pfe-local-files
```

Only example files are versioned in the repository.

### Security Summary

This CI/CD design provides the following security properties:

* Jenkins remains private inside the local lab.
* The GitHub Actions runner only triggers Jenkins.
* The runner runs under a limited Linux user.
* The runner does not checkout or execute repository code.
* Jenkins credentials remain local to the DevOps VM.
* Docker operations are delegated to the GNS3 host.
* GNS3 topology-changing actions are manual and protected by confirmation.

This design keeps the CI/CD workflow enterprise-like while remaining suitable for an academic hybrid network automation lab.

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