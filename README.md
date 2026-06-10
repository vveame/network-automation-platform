# Intelligent Network Automation Platform

This repository contains the source code, configuration files, automation scripts and documentation for an intelligent network automation platform built around a local GNS3 enterprise lab, Jenkins CI/CD automation, AWS cloud integration, Prometheus monitoring, SNMPv3 network-device metrics, anomaly analysis and a Flask dashboard.

The project is implemented as a Master PFE platform that combines:

```text
Local network simulation
DevOps automation
Cloud infrastructure
Monitoring and observability
Artifact storage
Anomaly detection
Safe remediation preparation
```

## Objective

The objective of this project is to transform a manually validated GNS3 network topology into a reproducible, automatable, observable and cloud-integrated infrastructure baseline.

The platform is designed around the following goals:

```text
Automate infrastructure validation.
Collect monitoring data from hosts, services and network devices.
Export validation and monitoring evidence.
Analyze validation reports and metrics for anomaly detection.
Store generated artifacts in AWS S3.
Visualize the latest platform state through a Flask dashboard.
Prepare a controlled hybrid link between the local lab and AWS.
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

The architecture also separates the production/data plane from the management/control plane:

```text
Production / Data Plane:
  VLANs, routing, DMZ, NAT, firewall rules and service traffic.

Management / Control Plane:
  DevOps server, SSH, Ansible, Jenkins, Prometheus, SNMP Exporter,
  dashboard synchronization and cloud integration.
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
EC2-based WireGuard tunnel gateway
Private AWS monitoring EC2 instance
Prometheus monitoring baseline
Node Exporter host metrics
Blackbox Exporter service probes
SNMPv3 monitoring for FRR routers and OVS switches
Rule-based cloud analyzer
ML anomaly detection preparation
Safe remediation preparation
Multi-page Flask dashboard
Grafana monitoring and anomaly-evidence dashboards
Grafana alert-rule preparation
```

The first EC2-based hybrid connectivity test has been validated.

Validated hybrid path:

```text
DevOps VM / local tunnel endpoint
    -> WireGuard tunnel
AWS EC2 tunnel gateway
    -> AWS private routing
Private monitoring EC2
```

Validated tests:

```text
DevOps VM -> AWS tunnel gateway: successful ping to 10.255.0.1
DevOps VM -> private monitoring EC2: successful ping to the monitoring private IP
DevOps VM -> private monitoring EC2: successful SSH login through the tunnel
```

## End-to-End Flow

The general automation flow is:

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
Cloud analyzer / ML decision layer
    ↓
AWS S3 artifact upload
    ↓
/var/lib/pfe-dashboard cache sync
    ↓
Flask multi-page dashboard
```

The hybrid cloud extension adds:

```text
Local DevOps / GNS3 side
    ↓
Local WireGuard endpoint
    ↓
AWS EC2 tunnel gateway
    ↓
Private monitoring EC2
```

## Source of Truth Model

The platform follows this artifact model:

```text
GitHub:
  Versioned source code, safe configuration templates, examples, scripts and documentation.

Jenkins workspace:
  Temporary execution and generation area.

AWS S3:
  Durable source of truth for generated validation reports, metrics snapshots,
  analyzer outputs, ML outputs and remediation results.

/var/lib/pfe-dashboard:
  Local dashboard cache synchronized from S3.
```

Generated outputs and secrets are not committed to GitHub.

Current S3 prefixes used by the platform include:

```text
latest/validation-artifacts/
latest/analyzer/
latest/metrics/
latest/ml/
latest/remediation/
validation-artifacts/
metrics-snapshots/
anomaly-results/
ml-results/
remediation-results/
```

Current local dashboard cache model:

```text
/var/lib/pfe-dashboard/
├── outputs/
├── analyzer/
│   └── latest/
├── metrics/
│   └── latest/
├── ml/
│   └── latest/
└── remediation/
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
EdgeRouter-VPNGateway node
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
Hybrid cloud routing preparation
```

## DevOps Control Node

The DevOps server is a dedicated Ubuntu VM with two network interfaces.

| Interface | Role                                        | Configuration           |
| --------- | ------------------------------------------- | ----------------------- |
| `ens33`   | Internet, package updates, GitHub, AWS APIs | DHCP through VMware NAT |
| `ens34`   | Out-of-band management network              | `10.200.0.10/24`        |

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
Local WireGuard endpoint for the first hybrid tunnel phase
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

| Node                  | OOB interface | OOB IP           |
| --------------------- | ------------- | ---------------- |
| Core-FRR-1            | `eth3`        | `10.200.0.11/24` |
| Core-FRR-2            | `eth3`        | `10.200.0.12/24` |
| Dist-FRR-1            | `eth3`        | `10.200.0.21/24` |
| Dist-FRR-2            | `eth3`        | `10.200.0.22/24` |
| EdgeRouter-VPNGateway | `eth4`        | `10.200.0.30/24` |
| Dist-OVS-1            | `eth4`        | `10.200.0.31/24` |
| Dist-OVS-2            | `eth4`        | `10.200.0.32/24` |
| DMZ-OVS-3             | `eth3`        | `10.200.0.33/24` |
| Access-OVS-4          | `eth3`        | `10.200.0.44/24` |
| Access-OVS-5          | `eth3`        | `10.200.0.45/24` |
| Access-OVS-6          | `eth4`        | `10.200.0.46/24` |

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

### EdgeRouter-VPNGateway

The EdgeRouter-VPNGateway is the logical cloud exit point of the local architecture.

In the first validated tunnel phase, the WireGuard process runs on the DevOps VM as the local tunnel endpoint. The EdgeRouter-VPNGateway remains part of the intended path by routing AWS VPC traffic toward the local tunnel endpoint.

Target path:

```text
GNS3 local topology
    ↓
EdgeRouter-VPNGateway
    ↓
Local tunnel endpoint
    ↓
WireGuard
    ↓
AWS EC2 tunnel gateway
    ↓
Private monitoring EC2
```

This approach allows the project to validate a real hybrid communication path without requiring a public static IP address on the local lab side.

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
WireGuard peer-key based tunnel access
Public SSH limited to temporary administration/debugging only
```

For the EC2 tunnel gateway:

```text
SSH access is controlled by admin_allowed_cidr.
WireGuard UDP access is controlled by wireguard_allowed_cidr.
WireGuard can use 0.0.0.0/0 for UDP only because peer keys are still required.
Public SSH must not remain open to 0.0.0.0/0.
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

Use this when all GNS3 Docker nodes are already running. It copies configuration into running containers and immediately applies the required settings.

### Persistent-Volume Bootstrap

```bash
./gns3/scripts/bootstrap-persistent-gns3.sh
```

Use this when containers may be stopped or recreated. It writes desired files into GNS3 persistent directories so they are applied on the next container start.

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

Because the GitHub repository is public, Jenkins is not exposed directly to the Internet. A GitHub Actions self-hosted runner is installed on the DevOps VM under a limited Linux user:

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

| Mode                 | Purpose                                              |
| -------------------- | ---------------------------------------------------- |
| `AUTO`               | Default mode used by GitHub push triggers            |
| `VALIDATE_ONLY`      | Runs validation, reports and dashboard publishing    |
| `BUILD_IMAGES`       | Builds custom Docker images on the GNS3 host         |
| `PUSH_IMAGES`        | Builds and pushes custom Docker images to Docker Hub |
| `BOOTSTRAP_GNS3`     | Runs the persistent GNS3 bootstrap workflow          |
| `FULL_LOCAL_REFRESH` | Performs image refresh, bootstrap and validation     |

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
10. Run ML anomaly detection when enabled.
11. Merge rule-based and ML decisions when enabled.
12. Prepare safe remediation plan when enabled.
13. Upload validation, analyzer, ML, remediation and metrics outputs to S3.
14. Sync latest S3 outputs into /var/lib/pfe-dashboard.
15. Generate HTML summary report.
16. Archive Jenkins artifacts.
17. Update Jenkins build description with dashboard and artifact links.
```

## AWS Cloud Baseline

The project includes an AWS cloud infrastructure baseline provisioned with Terraform.

The cloud layer currently supports:

```text
VPC
public subnet
private subnet
monitoring/AI subnet
Internet Gateway
route tables
security groups
private S3 artifact bucket
optional EC2 tunnel gateway
optional private monitoring EC2
optional AI EC2 placeholder
disabled AWS Site-to-Site VPN module
```

Current cloud status:

```text
Network, security and storage baseline created.
S3 artifact bucket created.
EC2 tunnel gateway implemented and validated.
Private monitoring EC2 implemented and validated through the tunnel.
AWS managed Site-to-Site VPN remains disabled.
NAT Gateway is not used.
Cloud monitoring services are not fully installed yet.
Cloud AI services are not fully installed yet.
```

### Cloud CIDR Plan

```text
AWS VPC:            10.50.0.0/16
Public subnet:      10.50.10.0/24
Private subnet:     10.50.20.0/24
Monitoring subnet:  10.50.30.0/24
WireGuard tunnel:   10.255.0.0/30
```

### EC2-Based Hybrid Tunnel

The first hybrid tunnel phase uses:

```text
Public EC2 tunnel gateway
Private EC2 monitoring instance
WireGuard tunnel between local DevOps VM and AWS tunnel gateway
AWS private route tables toward local CIDRs
source_dest_check disabled on the tunnel gateway
iptables forwarding rules on the tunnel gateway
```

Validated tunnel IPs:

```text
AWS tunnel gateway: 10.255.0.1
Local tunnel endpoint: 10.255.0.2
```

Validated commands:

```bash
ping -c 3 10.255.0.1
ping -c 3 "$(terraform output -raw monitoring_private_ip)"
ssh -i ~/.ssh/pfe-aws-tunnel ec2-user@"$(terraform output -raw monitoring_private_ip)"
```

The monitoring EC2 remains private and is reached through the tunnel.

### S3 Artifact Bucket

The Terraform storage module creates a private S3 bucket used for generated platform artifacts.

The bucket stores:

```text
validation reports
metrics snapshots
analyzer outputs
ML datasets and decisions
remediation plans and reports
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
Grafana
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

Future cloud monitoring step:

```text
Deploy Prometheus and Grafana on the private monitoring EC2.
Scrape selected local exporters through the WireGuard tunnel.
Keep local remediation execution controlled by Jenkins/Ansible.
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

| Device       | Target             | Device type |
| ------------ | ------------------ | ----------- |
| core-frr-1   | `10.200.0.11:1161` | FRR router  |
| core-frr-2   | `10.200.0.12:1161` | FRR router  |
| dist-frr-1   | `10.200.0.21:1161` | FRR router  |
| dist-frr-2   | `10.200.0.22:1161` | FRR router  |
| edge-router  | `10.200.0.30:1161` | FRR router  |
| dist-ovs-1   | `10.200.0.31:1161` | OVS switch  |
| dist-ovs-2   | `10.200.0.32:1161` | OVS switch  |
| dmz-ovs-3    | `10.200.0.33:1161` | OVS switch  |
| access-ovs-4 | `10.200.0.44:1161` | OVS switch  |
| access-ovs-5 | `10.200.0.45:1161` | OVS switch  |
| access-ovs-6 | `10.200.0.46:1161` | OVS switch  |

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
interface discard counters
```

Special/internal interfaces are displayed for visibility but ignored in anomaly scoring:

```text
lo
vrrp*
ovs-system
```

## Analyzer and Detection Layer

The analyzer combines validation reports with monitoring metrics.

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
SNMP interface errors/discards
```

The current analyzer is rule-based and explainable. It prepares the project for statistical and machine-learning anomaly detection.

## ML and Safe Remediation Preparation

The ML layer uses exported Prometheus metrics as features for anomaly detection.

The ML decision is treated as an advisory signal. It does not directly apply remediation by itself.

The safe remediation model follows this principle:

```text
Grafana alert = live symptom
Rule-based analyzer = deterministic evidence
ML layer = statistical suspicion
Final decision = safety validation
Jenkins/Ansible = controlled remediation execution
```

Automatic remediation must remain controlled and must not be triggered directly by a raw monitoring spike.

## Multi-Page Flask Dashboard

The Flask dashboard visualizes the latest S3-backed validation, analyzer, ML, remediation and monitoring data.

Current routes include:

| Route             | Purpose                                              |
| ----------------- | ---------------------------------------------------- |
| `/`               | Overview                                             |
| `/analyzer`       | Cloud Analyzer Decision                              |
| `/ml`             | ML anomaly decision                                  |
| `/remediation`    | Safe remediation status                              |
| `/monitoring`     | Prometheus, Node Exporter, Blackbox and SNMP metrics |
| `/validation`     | Validation domains and report previews               |
| `/infrastructure` | FRR and OVS node table                               |
| `/services`       | Validated services                                   |

The dashboard displays:

```text
global validation status
cloud analyzer decision
risk score and recommended action
ML anomaly signal
safe remediation status
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
│   ├── scripts/
│   ├── terraform/
│   └── tunnel/
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
│   ├── grafana/
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
terraform fmt -recursive ../..
terraform validate
terraform plan
```

To apply the cloud baseline or enabled tunnel resources:

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

To inspect deployed identifiers:

```bash
terraform output
```

### WireGuard Tunnel Validation

From the DevOps VM:

```bash
sudo wg show
ping -c 3 10.255.0.1

cd cloud/terraform/environments/dev
ping -c 3 "$(terraform output -raw monitoring_private_ip)"
ssh -i ~/.ssh/pfe-aws-tunnel ec2-user@"$(terraform output -raw monitoring_private_ip)"
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
cloud/analyzer/ml/data/
cloud/analyzer/ml/models/
cloud/analyzer/ml/outputs/
monitoring/snmp/snmp-auth.local.yml
frr/snmp/env/frr-routers.snmp.env
ovs/snmp/env/ovs-switches.snmp.env
/etc/prometheus/snmp.yml
terraform.tfvars
terraform.tfstate
terraform.tfstate.backup
tfplan
*.tfplan
.terraform/
private SSH keys
WireGuard private keys
real wg0.conf files
AWS credentials
GitHub tokens
```

Safe files to commit:

```text
source code
Terraform modules
safe examples
README files
template files
.tftpl user-data templates without secrets
.example files
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

Hybrid cloud extension:
  EC2 WireGuard tunnel gateway, private monitoring EC2 and AWS S3 artifact storage.
```

Validation reports, metrics snapshots, analyzer decisions, ML outputs and remediation plans are generated by Jenkins, stored in S3 and visualized through the Flask dashboard.

The first EC2-based tunnel is validated. The next implementation step is to integrate the GNS3 EdgeRouter-VPNGateway route toward the local WireGuard endpoint and then deploy cloud-side monitoring services on the private monitoring EC2.
