# Intelligent Network Automation Platform

This repository contains the source code, configuration files, automation scripts and documentation for an intelligent network automation platform built around a local GNS3 enterprise lab, Jenkins CI/CD automation, AWS S3 artifact storage, Prometheus monitoring, SNMPv3 network-device metrics, a rule-based cloud analyzer and a Flask multi-page dashboard.

## Objective

The objective of this project is to transform a manually validated GNS3 network topology into a reproducible, automatable and observable infrastructure baseline.

The platform is designed around three major goals:

```text
Automate infrastructure validation.
Collect monitoring data from hosts, services and network devices.
Analyze validation and monitoring outputs to support anomaly detection.
```

The implementation separates the network into three operational categories:

```text
Network infrastructure nodes:
  FRR routers and OVS switches managed through SSH, Ansible, Jenkins and SNMP.

Service nodes:
  Web and DNS containers validated through service health checks.

Endpoint/test hosts:
  Client/test nodes validated through connectivity tests.
```

The architecture also separates the production network from the management network:

```text
Production / Data Plane:
  VLANs, routing, DMZ, NAT, firewall rules and service traffic.

Management / Control Plane:
  DevOps server, SSH, Ansible, Jenkins, Prometheus, SNMP Exporter and dashboard synchronization.
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
Private S3 artifact bucket
Prometheus monitoring baseline
Node Exporter host metrics
Blackbox Exporter service probes
SNMPv3 monitoring for FRR routers and OVS switches
Rule-based cloud analyzer
Multi-page Flask dashboard
```

## End-to-End Flow

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

The platform follows this artifact model:

```text
GitHub:
  Versioned source code, safe configuration templates, examples, scripts and documentation.

Jenkins workspace:
  Temporary execution and generation area.

AWS S3:
  Durable source of truth for generated validation reports, metrics snapshots and analyzer outputs.

/var/lib/pfe-dashboard:
  Local dashboard cache synchronized from S3.
```

Generated outputs and secrets are not committed to GitHub.

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

## Local GNS3 Architecture

The local topology is based on a simulated enterprise network in GNS3.

It includes:

```text
Three-tier internal network architecture
DMZ service zone
Dedicated out-of-band management network
DevOps control VM
FRR routers
Open vSwitch switches
Web and DNS service containers
Endpoint/test hosts
```

The local network uses:

```text
VLAN segmentation
OSPF dynamic routing
VRRP-style redundant gateways
DMZ isolation
NAT control
Firewall rules
OOB management access
SSH-based infrastructure administration
SNMPv3 network-device monitoring
```

## DevOps Control Node

The DevOps server is a dedicated Ubuntu VM with two network interfaces.

| Interface | Role                                        | Configuration           |
| --------- | ------------------------------------------- | ----------------------- |
| ens33     | Internet, package updates, GitHub, AWS APIs | DHCP through VMware NAT |
| ens34     | Out-of-band management network              | 10.200.0.10/24          |

The DevOps VM runs or controls:

```text
Ansible
Jenkins
Git/GitHub integration
Terraform
AWS CLI
Prometheus
SNMP Exporter
Blackbox Exporter
Node Exporter
SSH-based infrastructure administration
Automated validation
Dashboard service
```

## Management Model

The main management path is the OOB network:

```text
OOB subnet: 10.200.0.0/24
DevOps VM: 10.200.0.10
```

The old VLAN 99 management segment remains part of the simulated enterprise topology as an in-band management VLAN, but it is not the primary DevOps automation path.

```text
VLAN 99:
  In-band management VLAN inside the simulated enterprise topology.

OOB 10.200.0.0/24:
  Dedicated DevOps automation, monitoring and infrastructure control plane.
```

## OOB IP Plan

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

## Main Infrastructure Components

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
SNMPv3 interface monitoring endpoint
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
SNMPv3 interface monitoring endpoint
```

## Security Baseline

Security is implemented through versioned scripts using Linux firewall rules and FRR configuration.

Current security controls include:

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

Custom Docker images and entrypoints are used to start and initialize FRR, OVS, Web and DNS containers.

The FRR and OVS entrypoints handle:

```text
Directory initialization
SSH host key generation
DevOps public key installation
Root key-only SSH preparation
Interface configuration
OOB management interface configuration
FRR or OVS service startup
Security script execution
Optional SNMP service startup
SSH daemon startup
```

Docker image building is performed on the GNS3 host, not on the DevOps VM.

## Bootstrap Scripts

Two bootstrap modes are provided.

### Running-Container Bootstrap

```bash
./gns3/scripts/bootstrap-gns3.sh
```

Use this when all GNS3 Docker nodes are already running.

It copies configuration into running containers and immediately applies the required settings.

### Persistent-Volume Bootstrap

```bash
./gns3/scripts/bootstrap-persistent-gns3.sh
```

Use this when containers may be stopped or recreated.

It writes desired files into GNS3 persistent directories so they are applied on the next container start.

The persistent bootstrap installs:

```text
FRR router environment files
FRR interface configuration
FRR routing configuration
OVS bridge/VLAN/trunk configuration
OVS management configuration
OOB management files
Security scripts
SSH authorized keys
FRR SNMPv3 files
OVS SNMPv3 files
```

## Ansible Workflow

Ansible is executed from the dedicated DevOps VM.

The site playbook validates:

```text
Management readiness
Ansible SSH connection readiness
OVS configuration
FRR configuration
DMZ Web/DNS services
Security behavior
End-to-end connectivity
Inventory consistency
Report artifact generation
Jenkins-ready assertion gates
```

Ansible outputs are generated locally during the pipeline, uploaded to S3, then synchronized to the local dashboard cache.

## Jenkins and GitHub Actions Integration

Jenkins is the main CI/CD orchestrator.

Because the GitHub repository is public, Jenkins is not exposed directly to the Internet.

A GitHub Actions self-hosted runner is installed on the DevOps VM under a limited Linux user:

```text
gha-runner
```

The runner only triggers Jenkins through a protected local script:

```text
/usr/local/sbin/trigger-jenkins-pfe
```

The runner does not build, deploy or run validation by itself.

## Jenkins Pipeline Modes

The Jenkins pipeline is parameterized and supports several execution modes.

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

## Jenkins Default Workflow

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

## AWS Cloud Baseline

The project includes an initial AWS cloud infrastructure baseline provisioned with Terraform.

This cloud layer prepares the future hybrid extension of the local GNS3 network automation platform.

Current Terraform scope:

```text
VPC
public subnet
private subnet
monitoring/AI subnet
Internet Gateway
route tables
security group baseline
private S3 artifact bucket
optional compute module prepared but disabled
optional VPN/hybrid module prepared but disabled
```

Current cloud status:

```text
Network, security and storage baseline created.
EC2 instances are not enabled yet.
NAT Gateway is not enabled yet.
VPN connection is not enabled yet.
Cloud monitoring services are not enabled yet.
Cloud AI services are not enabled yet.
```

This keeps the project cost-aware while preparing the future hybrid extension.

### Cloud CIDR Plan

```text
AWS VPC:              10.50.0.0/16
Public subnet:        10.50.10.0/24
Private subnet:       10.50.20.0/24
Monitoring/AI subnet: 10.50.30.0/24
```

### S3 Artifact Bucket

The Terraform storage module creates a private S3 bucket used for generated platform artifacts.

The bucket stores:

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
server-side encryption
lifecycle retention rules
```

## Monitoring Baseline

The monitoring stack includes:

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
OVS switch SNMPv3 interface metrics
```

Metrics snapshots are exported from the Prometheus HTTP API into:

```text
monitoring/outputs/latest/
```

Jenkins uploads the latest metrics to S3 and synchronizes them into:

```text
/var/lib/pfe-dashboard/metrics/latest/
```

## SNMPv3 Network-Device Monitoring

SNMPv3 is used to monitor network-device interface state and counters.

Current SNMP scope:

```text
5 FRR routers
6 OVS switches
11 total SNMP network devices
```

Current SNMP targets:

| Device       | Target           | Device type |
| ------------ | ---------------- | ----------- |
| core-frr-1   | 10.200.0.11:1161 | FRR router  |
| core-frr-2   | 10.200.0.12:1161 | FRR router  |
| dist-frr-1   | 10.200.0.21:1161 | FRR router  |
| dist-frr-2   | 10.200.0.22:1161 | FRR router  |
| edge-router  | 10.200.0.30:1161 | FRR router  |
| dist-ovs-1   | 10.200.0.31:1161 | OVS switch  |
| dist-ovs-2   | 10.200.0.32:1161 | OVS switch  |
| dmz-ovs-3    | 10.200.0.33:1161 | OVS switch  |
| access-ovs-4 | 10.200.0.44:1161 | OVS switch  |
| access-ovs-5 | 10.200.0.45:1161 | OVS switch  |
| access-ovs-6 | 10.200.0.46:1161 | OVS switch  |

SNMP security model:

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
device uptime
interface admin status
interface operational status
traffic counters
interface error counters
```

Special/internal interfaces are displayed for visibility but ignored in anomaly scoring:

```text
lo
vrrp*
ovs-system
```

## Cloud Analyzer Baseline

The cloud analyzer combines validation reports with monitoring metrics.

Analyzer inputs:

```text
Ansible validation reports
Prometheus scrape target health
Node Exporter memory/disk metrics
Blackbox service probe metrics
SNMPv3 network-device interface metrics
```

Analyzer outputs:

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

The current analyzer is rule-based and explainable.

It prepares the project for future statistical or machine-learning anomaly detection.

## Multi-Page Flask Dashboard

The Flask dashboard visualizes the latest S3-backed validation, analyzer and monitoring data.

Current routes:

| Route             | Purpose                                              |
| ----------------- | ---------------------------------------------------- |
| `/`               | Overview                                             |
| `/analyzer`       | Cloud Analyzer Decision                              |
| `/monitoring`     | Prometheus, Node Exporter, Blackbox and SNMP metrics |
| `/validation`     | Validation domains and report previews               |
| `/infrastructure` | FRR and OVS node table                               |
| `/services`       | Validated services                                   |

The dashboard displays:

```text
global validation status
cloud analyzer decision
risk score and recommended action
Prometheus target health
host resource usage
Blackbox service probes
SNMP per-device interface status
SNMP interface counters
validation report domains
infrastructure node matrix
validated services
```

The dashboard reads from:

```text
/var/lib/pfe-dashboard/
```

Current dashboard cache structure:

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
│   ├── access/
│   ├── distribution/
│   ├── dmz/
│   ├── management/
│   └── snmp/
├── security/
├── scripts/
├── tests/
└── secrets/
    └── ospf.env.example
```

## Common Commands

### Terraform

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

### Dashboard

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

### SNMP Validation

Test all SNMP network devices from the DevOps VM:

```bash
for target in \
  10.200.0.11 \
  10.200.0.12 \
  10.200.0.21 \
  10.200.0.22 \
  10.200.0.30 \
  10.200.0.31 \
  10.200.0.32 \
  10.200.0.33 \
  10.200.0.44 \
  10.200.0.45 \
  10.200.0.46
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

### Metrics Snapshot

Export a Prometheus metrics snapshot:

```bash
./monitoring/scripts/export-prometheus-snapshot.sh
```

### Analyzer

Run the analyzer locally:

```bash
python3 cloud/analyzer/analyze_validation_artifacts.py \
  --input-dir /var/lib/pfe-dashboard/outputs \
  --metrics-dir monitoring/outputs/latest \
  --output-dir cloud/analyzer/outputs \
  --build-label local-test
```

Check outputs:

```bash
cat cloud/analyzer/outputs/decision.json | python3 -m json.tool
cat cloud/analyzer/outputs/analysis-report.txt
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
ovs/snmp/env/ovs-switches.snmp.env
/etc/prometheus/snmp.yml
terraform.tfvars
terraform.tfstate
terraform.tfstate.backup
tfplan
.terraform/
```

Only safe source code, templates, scripts, examples and documentation are versioned.

## Current Principle

The production topology remains the validation target.

The OOB network remains the automation and monitoring control path.

```text
Production topology:
  VLANs, OSPF, DMZ, NAT, firewall rules and service behavior.

OOB control plane:
  SSH, Ansible, Jenkins, Prometheus, SNMP Exporter and dashboard synchronization.
```

Validation reports, metrics snapshots and analyzer decisions are generated by Jenkins, stored in S3 and visualized through the Flask multi-page dashboard.
