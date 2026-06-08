# Intelligent Network Automation Platform

This repository contains the versioned source code, configuration files, automation scripts and documentation for an intelligent network automation platform built around a local GNS3 enterprise lab, Jenkins automation, AWS S3 artifact storage, Prometheus monitoring, SNMPv3 network-device metrics, a rule-based cloud analyzer and a Flask multi-page dashboard.

## Objective

The objective of this project is to transform a manually validated GNS3 network topology into a reproducible, automatable and observable infrastructure baseline.

The platform separates the infrastructure into three operational categories:

```text
Network infrastructure nodes:
  SSH required and managed by Ansible/Jenkins.

Service nodes:
  SSH not required; validated through health checks.

Endpoint/test hosts:
  SSH not required; validated through connectivity tests.
```

The final local architecture follows a clear separation between:

```text
Production / Data Plane:
  VLANs, routing, DMZ, NAT, firewall rules, user/service traffic.

Management / Control Plane:
  DevOps server, SSH, Ansible, Jenkins, Prometheus, SNMP Exporter and infrastructure administration.
```

## Current Implementation Status

At the current checkpoint, the platform includes:

```text
Local GNS3 enterprise topology
Dedicated DevOps control VM
Out-of-band management plane
FRR and OVS infrastructure automation
Ansible validation workflow
Jenkins CI/CD orchestration
GitHub Actions to Jenkins trigger bridge
AWS Terraform baseline
S3-backed artifact storage
Prometheus monitoring baseline
Node Exporter host metrics
Blackbox Exporter service probes
SNMPv3 monitoring for all FRR routers
Rule-based cloud analyzer
Multi-page Flask dashboard
```

## High-Level End-to-End Flow

```text
GitHub push
        ↓
GitHub Actions self-hosted runner
        ↓
Jenkins pipeline on DevOps VM
        ↓
Ansible validation
        ↓
Prometheus metrics snapshot export
        ↓
Cloud analyzer
        ↓
AWS S3 artifact upload
        ↓
/var/lib/pfe-dashboard cache sync
        ↓
Flask multi-page dashboard
```

## Source of Truth Model

The platform uses the following artifact model:

```text
GitHub = source code, templates, examples and documentation
Jenkins workspace = temporary execution/generation area
AWS S3 = durable source of truth for generated outputs
/var/lib/pfe-dashboard = local dashboard cache synchronized from S3
```

Generated outputs are not committed to GitHub.

Current latest S3 prefixes:

```text
latest/validation-artifacts/
latest/analyzer/
latest/metrics/
```

Current local dashboard cache:

```text
/var/lib/pfe-dashboard/
├── outputs/
├── analyzer/
│   └── latest/
└── metrics/
    └── latest/
```

## Local Architecture

The local scope is based on a GNS3 on-premises topology and a dedicated DevOps control VM.

The topology contains:

```text
Three-tier internal network architecture
DMZ service zone
Dedicated out-of-band management plane
DevOps control VM
FRR routers
Open vSwitch switches
Web and DNS service containers
Endpoint/test hosts
```

## DevOps Control Node

The DevOps server is a dedicated Ubuntu VM with two network interfaces:

| Interface | Role                                        | Configuration           |
| --------- | ------------------------------------------- | ----------------------- |
| ens33     | Internet, package updates, GitHub, AWS APIs | DHCP through VMware NAT |
| ens34     | Out-of-band management network              | 10.200.0.10/24          |

The DevOps VM is the central control node for:

```text
Ansible
Jenkins
Git/GitHub integration
Terraform
AWS CLI
Prometheus
SNMP Exporter
Blackbox Exporter
SSH-based infrastructure administration
Automated validation of the local topology
Dashboard service
```

## Management Model

The platform uses a dedicated out-of-band management network for infrastructure automation.

| Node family    | Management method                  |
| -------------- | ---------------------------------- |
| FRR routers    | SSH over OOB network 10.200.0.0/24 |
| OVS switches   | SSH over OOB network 10.200.0.0/24 |
| DMZ-OVS-3      | SSH over OOB network 10.200.0.0/24 |
| Web server     | HTTP health check only             |
| DNS server     | DNS health check only              |
| VPCS endpoints | Connectivity tests only            |

The old VLAN 99 management segment remains part of the simulated production topology as an in-band management VLAN, but it is not the primary DevOps automation path.

```text
VLAN 99:
  In-band management VLAN inside the simulated enterprise topology.

OOB 10.200.0.0/24:
  Dedicated DevOps, Ansible, Jenkins, monitoring and infrastructure control plane.
```

## Out-of-Band Management Plane

The OOB management plane provides a stable control path independent of the production network.

It allows the DevOps VM to reach infrastructure nodes even when production VLANs, OSPF routes, firewall policies or DMZ rules are being tested or modified.

```text
OOB subnet: 10.200.0.0/24
DevOps VM: 10.200.0.10
```

### OOB IP Plan

| Node                  | OOB interface | OOB IP         |
| --------------------- | ------------- | -------------- |
| Core-FRR-1            | eth3          | 10.200.0.11/24 |
| Core-FRR-2            | eth3          | 10.200.0.12/24 |
| Dist-FRR-1            | eth3          | 10.200.0.21/24 |
| Dist-FRR-2            | eth3          | 10.200.0.22/24 |
| EdgeRouter-VPNGateway | eth4          | 10.200.0.30/24 |
| Dist-OVS-1            | eth4          | 10.200.0.31/24 |
| Dist-OVS-2            | eth4          | 10.200.0.32/24 |
| DMZ-OVS-3             | eth3          | 10.200.0.33/24 |
| Access-OVS-4          | eth3          | 10.200.0.44/24 |
| Access-OVS-5          | eth3          | 10.200.0.45/24 |
| Access-OVS-6          | eth4          | 10.200.0.46/24 |

## Implemented Local Components

The local infrastructure currently includes:

```text
Three-tier GNS3 topology
Open vSwitch access, distribution and DMZ switching
VLAN 10, VLAN 20 and VLAN 99 segmentation
Dedicated OOB management plane
FRRouting routers for distribution, core and edge layers
OSPF dynamic routing
Routed loopback addresses for routing validation
VRRP-style redundant gateways at the distribution layer
DMZ with custom Web and DNS Docker service images
DMZ isolation through EdgeRouter firewall rules
Security rules for admin access, management VLAN protection, DMZ isolation, NAT control and OSPF authentication
SSH-enabled FRR and OVS custom Docker images
Root key-only SSH access for managed infrastructure containers
Running-container and persistent-volume bootstrap scripts
Ansible inventory, readiness gates and validation playbooks
Dedicated service health checks for Web and DNS nodes
Connectivity tests for endpoint/test hosts
```

## Main Local Network Components

### Open vSwitch

Open vSwitch is used for Layer 2 switching, VLAN access ports and trunk links.

OVS nodes are organized into:

```text
Access layer switches
Distribution layer switches
DMZ switch
```

OVS provides:

```text
VLAN access ports
VLAN trunk links
VLAN 10 user segment
VLAN 20 user segment
VLAN 99 in-band management segment
RSTP-capable switching baseline
Dedicated OOB Linux interface for SSH and Ansible access
```

The OOB interface on OVS nodes remains outside the main OVS bridge.

### FRRouting

FRRouting is used for Layer 3 routing.

FRR nodes are organized into:

```text
Distribution routers
Core routers
EdgeRouter / VPN gateway
```

FRR provides:

```text
OSPF routing
VRRP-style gateway redundancy
Routing between internal networks, DMZ and future cloud link
Routed loopback addresses for validation
Dedicated OOB Linux interface for SSH and Ansible access
SNMPv3 monitoring endpoint
```

## Security Baseline

Security is implemented through versioned scripts using Linux firewall rules and FRR configuration.

Security includes:

```text
SSH/admin access restricted to the DevOps OOB IP 10.200.0.10
ICMP allowed from the DevOps OOB IP for readiness checks
Management VLAN protection
DMZ isolation
Controlled DMZ service access
NAT control on the EdgeRouter
OSPF authentication
Root key-only SSH access on managed infrastructure containers
SNMPv3 read-only access restricted to the DevOps OOB IP
```

## Docker Automation

Custom Docker entrypoints are used to start and initialize FRR, OVS, Web and DNS containers.

The FRR and OVS entrypoints handle:

```text
Directory initialization
SSH host key generation
DevOps public key installation
Root key-only SSH preparation
Interface configuration
OOB management interface configuration
OVS or FRR service startup
Security script execution
SNMP service startup for FRR routers
SSH daemon startup
```

Docker image building is performed on the GNS3 host, not on the DevOps VM.

## Deployment Logic

The intended local deployment order is:

```text
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
11. Start SNMPv3 service on FRR routers.
12. Validate OOB reachability from the DevOps VM.
13. Validate Ansible SSH connectivity.
14. Validate OVS, FRR, DMZ, security and end-to-end behavior.
15. Export monitoring metrics.
16. Run analyzer.
17. Upload/sync generated artifacts.
18. Display results in the dashboard.
```

## Bootstrap Scripts

Two bootstrap modes are provided.

### Running-Container Bootstrap

```bash
./gns3/scripts/bootstrap-gns3.sh
```

Use this when all GNS3 Docker nodes are already running. It copies configuration into the running containers and immediately applies the required settings.

### Persistent-Volume Bootstrap

```bash
./gns3/scripts/bootstrap-persistent-gns3.sh
```

Use this when containers may be stopped or recreated. It writes desired files into GNS3 persistent directories so they are applied on the next container start.

## Ansible Workflow

Ansible is executed from the dedicated DevOps VM.

The site playbook runs:

```text
1. Management readiness checks.
2. Ansible SSH connection readiness.
3. OVS validation.
4. FRR validation.
5. DMZ Web/DNS health checks.
6. Security behavior validation.
7. End-to-end connectivity validation.
8. Inventory consistency validation.
9. Report artifact validation.
10. Jenkins-ready assertion gates.
11. Report summary generation in ansible/outputs/.
```

Ansible outputs are generated locally during the pipeline, uploaded to S3, then synchronized to the local dashboard cache.

## CI/CD Integration with Jenkins and GitHub Actions

The project uses Jenkins as the main CI/CD automation server.

Jenkins runs from the DevOps control VM and remains private inside the local lab. Because the GitHub repository is public, Jenkins is not exposed directly to the Internet.

Instead, a GitHub Actions self-hosted runner is installed on the DevOps VM under a dedicated limited Linux user named:

```text
gha-runner
```

The runner does not build, test, deploy or checkout the repository. Its only role is to act as a secure trigger bridge between GitHub and Jenkins.

When a push is made to the `main` branch, GitHub Actions runs the protected local command:

```bash
sudo /usr/local/sbin/trigger-jenkins-pfe
```

This script triggers the Jenkins job through the local Jenkins API.

Jenkins credentials are not stored in GitHub. They remain local to the DevOps VM.

### Jenkins Pipeline Modes

The Jenkins pipeline is parameterized and supports several execution modes:

| Mode               | Purpose                                              |
| ------------------ | ---------------------------------------------------- |
| AUTO               | Default mode used by GitHub push triggers            |
| VALIDATE_ONLY      | Runs validation, reports and dashboard publishing    |
| BUILD_IMAGES       | Builds custom Docker images on the GNS3 host         |
| PUSH_IMAGES        | Builds and pushes custom Docker images to Docker Hub |
| BOOTSTRAP_GNS3     | Runs the persistent GNS3 bootstrap workflow          |
| FULL_LOCAL_REFRESH | Performs image refresh, bootstrap and validation     |

Topology-changing actions require:

```text
CONFIRM_APPLY=true
```

This protects actions that modify the lab environment or persistent node configuration.

### Jenkins Default Workflow

In its default workflow, Jenkins performs:

```text
1. Clean workspace.
2. Checkout repository.
3. Detect changed repository areas.
4. Prepare output directories.
5. Validate Ansible inventory.
6. Run Ansible syntax checks.
7. Execute topology validation gate.
8. Export Prometheus metrics snapshot.
9. Run cloud analyzer.
10. Upload validation, analyzer and metrics outputs to S3.
11. Sync latest S3 outputs into /var/lib/pfe-dashboard.
12. Generate HTML summary report.
13. Archive Jenkins artifacts.
14. Update Jenkins build description with dashboard and artifact links.
```

## AWS Cloud Infrastructure Baseline

The project includes an initial AWS cloud infrastructure baseline provisioned with Terraform.

This cloud layer prepares the future hybrid extension of the local GNS3 network automation platform.

The current Terraform baseline creates:

```text
One AWS VPC
One public subnet
One private subnet
One monitoring/AI subnet
One Internet Gateway
Route tables and associations
Security group baseline
Private S3 artifacts bucket
Optional compute module prepared but disabled
VPN/hybrid module prepared but disabled
```

### Cloud CIDR Plan

```text
AWS VPC:              10.50.0.0/16
Public subnet:        10.50.10.0/24
Private subnet:       10.50.20.0/24
Monitoring/AI subnet: 10.50.30.0/24
```

### Current Cloud Status

At the current stage, Terraform creates the network, security and storage baseline only.

It does not yet create:

```text
EC2 instances
NAT Gateway
Active VPN connection
Cloud monitoring services
Cloud AI services
```

This avoids unnecessary AWS costs while keeping the cloud architecture ready for future phases.

### S3 Artifacts Bucket

The Terraform storage module creates a private S3 bucket used for platform artifacts.

The bucket is intended for:

```text
validation reports
metrics snapshots
analyzer outputs
future logs
future datasets
future AI outputs
```

The bucket is configured with:

```text
public access blocking
bucket owner enforced object ownership
versioning
server-side encryption using AES256
lifecycle retention rules
```

## Monitoring Baseline

The local monitoring baseline includes:

```text
Prometheus
Node Exporter
Blackbox Exporter
SNMP Exporter
```

Prometheus collects:

```text
DevOps VM host metrics
GNS3 VM host metrics
DMZ Web/DNS probe metrics
FRR router SNMPv3 interface metrics
```

The monitoring snapshot is exported from the Prometheus HTTP API and stored temporarily in:

```text
monitoring/outputs/latest/
```

Jenkins uploads metrics to S3 under:

```text
metrics-snapshots/<jenkins-job-name>-<build-number>/
latest/metrics/
```

The latest metrics are synchronized to:

```text
/var/lib/pfe-dashboard/metrics/latest/
```

## SNMPv3 Monitoring for All FRR Routers

All FRR routers are monitored using SNMPv3 over the OOB management network.

| Router      | SNMP target      |
| ----------- | ---------------- |
| core-frr-1  | 10.200.0.11:1161 |
| core-frr-2  | 10.200.0.12:1161 |
| dist-frr-1  | 10.200.0.21:1161 |
| dist-frr-2  | 10.200.0.22:1161 |
| edge-router | 10.200.0.30:1161 |

Security model:

```text
SNMPv3 authPriv
SHA authentication
AES privacy
read-only access
UDP/1161
DevOps OOB source restriction
```

The SNMP Exporter uses the `if_mib` module to expose interface metrics to Prometheus.

Collected SNMP metrics include:

```text
SNMP target health
router uptime
interface admin status
interface operational status
traffic counters
interface error counters
```

Loopback and VRRP virtual interfaces may be displayed in the dashboard for visibility, but they are ignored for unexpected-down anomaly scoring.

## Cloud Analyzer and Anomaly Baseline

The analyzer combines validation reports with monitoring metrics.

Inputs:

```text
Ansible validation reports
Prometheus target health
Node Exporter memory/disk metrics
Blackbox service probe metrics
SNMPv3 FRR interface metrics
```

The analyzer produces:

```text
summary.json
decision.json
analysis-report.txt
```

The analyzer scores:

```text
validation failures
critical or warning report patterns
Prometheus targets down
Blackbox probes failed
memory or disk pressure
SNMP targets down
SNMP interfaces unexpectedly down
SNMP interface errors
```

The current analyzer is rule-based and explainable. It prepares the project for future statistical or machine-learning anomaly detection.

## Multi-Page Flask Dashboard

The Flask dashboard visualizes the latest S3-backed validation, analyzer and monitoring data.

The dashboard is split into multiple pages:

| Route             | Purpose                                              |
| ----------------- | ---------------------------------------------------- |
| `/`               | Overview                                             |
| `/analyzer`       | Cloud Analyzer Decision                              |
| `/monitoring`     | Prometheus, Node Exporter, Blackbox and SNMP metrics |
| `/validation`     | Validation domains and report previews               |
| `/infrastructure` | FRR and OVS node table                               |
| `/services`       | Validated services                                   |

The dashboard visualizes:

```text
global validation status
cloud analyzer decision
risk score and recommended action
Prometheus target health
host resource usage
Blackbox service probes
SNMP per-router interface status
SNMP interface counters
validation report domains
infrastructure node matrix
validated services
```

The dashboard reads from:

```text
/var/lib/pfe-dashboard/
```

Current cache structure:

```text
/var/lib/pfe-dashboard/
├── outputs/
│   └── latest validation reports
├── analyzer/
│   └── latest/
│       ├── decision.json
│       ├── summary.json
│       └── analysis-report.txt
└── metrics/
    └── latest/
        ├── manifest.json
        ├── up.json
        ├── node_*.json
        ├── blackbox_*.json
        └── snmp_*.json
```

## Repository Structure

```text
.
├── ansible/
│   ├── group_vars/
│   ├── host_vars/
│   ├── inventory/
│   ├── playbooks/
│   ├── roles/
│   └── ansible.cfg
├── ci-cd/
│   ├── github-actions-jenkins-bridge.md
│   ├── trigger-jenkins-pfe.example.sh
│   ├── jenkins-netrc.example
│   └── gha-runner-sudoers.example
├── cloud/
│   ├── analyzer/
│   └── terraform/
├── dashboard/
│   ├── app.py
│   ├── config.py
│   ├── dto/
│   ├── repository/
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
│   └── snmp/
├── gns3/
│   ├── node-mapping.md
│   ├── startup-order.md
│   └── scripts/
├── hosts/
├── management/
├── monitoring/
│   ├── prometheus/
│   ├── blackbox/
│   ├── snmp/
│   └── scripts/
├── ovs/
├── security/
├── scripts/
├── tests/
└── secrets/
    └── ospf.env.example
```

## Terraform Commands

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

To inspect deployed identifiers:

```bash
terraform output
```

## Dashboard Run Command

From the repository root:

```bash
python3 -m venv dashboard/.venv
source dashboard/.venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r dashboard/requirements.txt
python dashboard/app.py
```

Then open:

```text
http://localhost:5050
```

## Monitoring Validation Commands

Test SNMP targets from the DevOps VM:

```bash
for target in \
  10.200.0.11 \
  10.200.0.12 \
  10.200.0.21 \
  10.200.0.22 \
  10.200.0.30
do
  echo
  echo "=== Testing $target ==="
  snmpwalk -v3 \
    -l authPriv \
    -u pfe_snmp_ro \
    -a SHA \
    -A 'REAL_LONG_AUTH_PASSWORD' \
    -x AES \
    -X 'REAL_LONG_PRIV_PASSWORD' \
    "$target:1161" \
    1.3.6.1.2.1.1.5.0
done
```

Test Prometheus SNMP target health:

```bash
curl -fsS --get "http://localhost:9090/api/v1/query" \
  --data-urlencode 'query=up{job="snmp-network-devices"}' | python3 -m json.tool
```

Export a Prometheus metrics snapshot:

```bash
./monitoring/scripts/export-prometheus-snapshot.sh
```

Run the analyzer locally:

```bash
python3 cloud/analyzer/analyze_validation_artifacts.py \
  --input-dir /var/lib/pfe-dashboard/outputs \
  --metrics-dir monitoring/outputs/latest \
  --output-dir cloud/analyzer/outputs \
  --build-label local-test
```

## Generated Files Policy

Generated outputs, secrets and local state must not be committed.

Do not commit:

```text
ansible/outputs/
monitoring/outputs/
cloud/analyzer/outputs/
monitoring/snmp/snmp-auth.local.yml
frr/snmp/env/frr-routers.snmp.env
/etc/prometheus/snmp.yml
terraform.tfvars
terraform.tfstate
terraform.tfstate.backup
tfplan
.terraform/
```

Only safe source code, templates, scripts, examples and documentation are versioned.

## Final Management Principle

The final architecture keeps both management concepts:

```text
VLAN 99:
  In-band management VLAN inside the simulated enterprise network.

OOB 10.200.0.0/24:
  Dedicated DevOps automation, monitoring and infrastructure control plane.
```

Ansible, Jenkins and monitoring use the OOB network as the primary control path.

The production topology remains the validation target.

Validation results, metrics snapshots and analyzer decisions are generated by the pipeline, stored in S3 and visualized through the Flask multi-page dashboard.
