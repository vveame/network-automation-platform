# Intelligent Network Automation Platform

This repository contains the source code, configuration files, automation scripts and documentation for a Master PFE intelligent network automation platform.

The platform combines:

```text
Local GNS3 enterprise network simulation
DevOps automation with Jenkins and Ansible
AWS cloud infrastructure with Terraform
Hybrid connectivity through WireGuard
Prometheus and Grafana monitoring
SNMPv3 network-device observability
S3-backed artifact storage
Rule-based and ML-assisted anomaly detection
Safe remediation preparation
Flask dashboard visualization
```

## Objective

The objective of this project is to transform a manually validated GNS3 network topology into a reproducible, automatable, observable and cloud-integrated infrastructure baseline.

The platform is designed to:

```text
Automate infrastructure validation
Collect monitoring data from hosts, services and network devices
Export validation and monitoring evidence
Analyze validation reports and metrics for anomaly detection
Store generated artifacts in AWS S3
Visualize the latest platform state through a Flask dashboard
Provide controlled hybrid connectivity between the local lab and AWS
Prepare safe remediation actions without applying unsafe automatic changes
```

## Final Validated Architecture

The current final architecture uses the GNS3 `EdgeRouter-VPNGateway` as the local hybrid-cloud boundary.

The final validated path is:

```text
Local GNS3 topology
    ↓
EdgeRouter-VPNGateway
    ↓
WireGuard tunnel
    ↓
AWS EC2 tunnel gateway
    ↓
Private AWS monitoring EC2
```

The DevOps VM no longer terminates the WireGuard tunnel and no longer provides the final tunnel underlay NAT.

The final underlay model is:

```text
EdgeRouter-VPNGateway eth3
    ↓
GNS3 NAT / internet underlay
    ↓
AWS EC2 tunnel gateway public IP UDP/51820
```

The final management model is:

```text
DevOps VM ens34
    ↓
OOB network 10.200.0.0/24
    ↓
FRR / OVS / EdgeRouter management interfaces
```

## Main Roles

### EdgeRouter-VPNGateway

The EdgeRouter is the local cloud boundary.

It provides:

```text
WireGuard tunnel endpoint
Route to AWS VPC 10.50.0.0/16 through wg0
Direct internet underlay through eth3
OOB management through eth4 / 10.200.0.30
DMZ routing and security boundary
SNMPv3 monitoring endpoint
```

Current EdgeRouter interface model:

```text
eth3  Direct WAN / GNS3 NAT / internet underlay
eth4  OOB management / 10.200.0.30
wg0   WireGuard tunnel to AWS
```

### DevOps VM

The DevOps VM is the control and automation node.

It provides:

```text
Jenkins orchestration
GitHub Actions self-hosted runner bridge
Ansible validation
Terraform and AWS CLI operations
SSH-based infrastructure administration
S3 artifact upload and dashboard cache sync
Local route to AWS private VPC through EdgeRouter
Local UI tunnel to cloud Prometheus and Grafana
```

The DevOps VM does not terminate WireGuard.

The DevOps VM keeps its own normal internet access for:

```text
GitHub
AWS APIs
Terraform
package updates
Jenkins plugins
DockerHub/API access
```

The DevOps VM reaches the AWS private VPC through EdgeRouter using:

```text
10.50.0.0/16 via 10.200.0.30 dev ens34
```

This route is installed by:

```bash
sudo ./scripts/devops/route-cloud-via-edge-router.sh
```

### AWS Cloud Layer

The AWS layer provides:

```text
VPC 10.50.0.0/16
Public tunnel gateway EC2
Private monitoring EC2
Private S3 artifact bucket
Cloud Prometheus and Grafana
Cloud analyzer and ML execution environment
Monitoring subnet egress through the tunnel gateway NAT instance
```

The monitoring EC2 remains private and is accessed through the WireGuard tunnel.

## Current CIDR Plan

```text
Local OOB network:         10.200.0.0/24
AWS VPC:                   10.50.0.0/16
AWS public subnet:          10.50.10.0/24
AWS private subnet:         10.50.20.0/24
AWS monitoring subnet:      10.50.30.0/24
WireGuard tunnel network:   10.255.0.0/30
AWS WireGuard IP:           10.255.0.1
EdgeRouter WireGuard IP:    10.255.0.2
```

## OOB IP Plan

| Node                  | OOB Interface | OOB IP         |
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

## Source of Truth Model

The platform uses the following source-of-truth model:

```text
GitHub:
  Versioned source code, safe templates, scripts and documentation

DevOps local files:
  Runtime-only local configuration and private parameters

Jenkins workspace:
  Temporary execution area

AWS S3:
  Durable artifact store for validation, metrics, analyzer, ML and remediation outputs

/var/lib/pfe-dashboard:
  Local dashboard cache synchronized from S3
```

Generated outputs and secrets are not committed.

Current S3 prefixes include:

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

## Jenkins and GitHub Actions Integration

Jenkins is the main CI/CD orchestrator.

Because the GitHub repository is public, Jenkins is not exposed to the Internet.

The automation flow is:

```text
GitHub push
    ↓
GitHub Actions self-hosted runner on DevOps
    ↓
Protected local trigger script
    ↓
Jenkins job on DevOps
    ↓
Ansible validation
    ↓
Cloud monitoring/analyzer/ML cycle
    ↓
S3 artifact upload
    ↓
Dashboard cache sync
    ↓
Safe remediation plan
```

The local Jenkins trigger reads non-versioned runtime parameters from:

```text
/etc/pfe/jenkins-hybrid.env
```

This file is root-owned and must not be committed.

Required local values include:

```text
GNS3_HOST
S3_ARTIFACTS_BUCKET
AWS_MONITORING_HOST
AWS_MONITORING_USER
CLOUD_AWS_REGION
CLOUD_PROMETHEUS_URL
ML_FEATURES_FILE
EDGE_UNDERLAY_MODE
```

## Jenkins Pipeline Modes

| Mode               | Purpose                                            |
| ------------------ | -------------------------------------------------- |
| AUTO               | Default mode used by GitHub push triggers          |
| VALIDATE_ONLY      | Runs validation and reporting                      |
| BUILD_IMAGES       | Builds custom Docker images on the GNS3 host       |
| PUSH_IMAGES        | Builds and pushes images to Docker Hub             |
| BOOTSTRAP_GNS3     | Applies persistent GNS3 node configuration         |
| FULL_LOCAL_REFRESH | Image refresh, persistent bootstrap and validation |

Topology-changing operations require:

```text
CONFIRM_APPLY=true
```

## Hybrid Restore

After GNS3 restart or container recreation, run from the DevOps VM:

```bash
cd ~/pfe-repo
./scripts/devops/restore-full-hybrid-tunnel.sh
```

This script performs:

```text
Refresh GNS3 SSH known_hosts
Validate EdgeRouter eth3 direct internet underlay
Install DevOps route to AWS VPC through EdgeRouter
Ensure EdgeRouter WireGuard is running
Reapply cloud monitoring access to OOB nodes
Repair AWS monitoring EC2 egress NAT
Validate EdgeRouter-to-AWS tunnel reachability
Open local Prometheus/Grafana UI tunnel
```

## Prometheus and Grafana Access

Prometheus and Grafana run on the private AWS monitoring EC2.

The DevOps VM opens local tunnels:

```text
Prometheus: http://127.0.0.1:19090
Grafana:    http://127.0.0.1:13000
```

From Windows, forward the DevOps ports:

```powershell
ssh -N `
  -L 19090:127.0.0.1:19090 `
  -L 13000:127.0.0.1:13000 `
  wiam@DEVOPS_VM_IP
```

Then open on Windows:

```text
http://127.0.0.1:19090
http://127.0.0.1:13000
```

## Grafana Dashboards

Cloud Grafana should provision only the cloud dashboards:

```text
PFE - Cloud Monitoring Overview
PFE - Cloud Network Devices & Interfaces
PFE - Cloud Anomaly Detection
```

Local dashboards remain under:

```text
monitoring/grafana/dashboards/
```

Cloud dashboards are versioned under:

```text
cloud/monitoring/grafana/dashboards/
```

## Monitoring and Anomaly Detection

The cloud monitoring stack uses:

```text
Prometheus
Grafana
Node Exporter
Blackbox Exporter
SNMP Exporter
Rule-based analyzer
ML anomaly detection
```

Current cloud Prometheus jobs include:

```text
cloud-node-exporter
local-node-exporter-through-tunnel
cloud-prometheus-self
cloud-blackbox-http-through-tunnel
cloud-blackbox-tcp-through-tunnel
cloud-blackbox-dns-through-tunnel
cloud-snmp-network-devices-through-tunnel
```

Cloud labels use:

```text
node
service
```

The ML feature file for cloud mode is:

```text
cloud/analyzer/ml/features.cloud.json
```

## Repository Structure

```text
ansible/                 Ansible inventory, playbooks, roles and validation logic
ci-cd/                   GitHub runner and Jenkins bridge documentation/examples
cloud/                   AWS Terraform, cloud analyzer, ML and cloud monitoring
dashboard/               Flask dashboard application
docker/                  Custom container images for FRR, OVS, web and DNS
frr/                     FRR router env, interfaces, routing, SNMP and WireGuard templates
gns3/                    GNS3 persistent bootstrap and node documentation
hosts/                   Host and service definitions
management/              OOB and management helpers
monitoring/              Local Prometheus/Grafana/SNMP/Blackbox configuration
ovs/                     OVS bridge, VLAN and SNMP configuration
scripts/devops/          DevOps-side runtime and repair scripts
security/                Versioned firewall/security scripts for managed nodes
tests/                   Validation helpers
secrets/                 Local-only secrets directory; real secrets are not committed
```

## Generated Files Policy

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
frr/wireguard/edge-underlay.env
frr/wireguard/edge-router-wg0.conf
secrets/edge-router-wg0.conf.secret
terraform.tfvars
terraform.tfstate
terraform.tfstate.backup
tfplan
*.tfplan
.terraform/
private SSH keys
WireGuard private keys
AWS credentials
GitHub tokens
Jenkinsfile.before-*.local
```

Safe files to commit:

```text
Source code
Terraform modules
Safe templates
.example files
README files
Dashboard JSON files without secrets
Jenkinsfile
Automation scripts without secrets
```

## Current Principle

The production topology remains the validation target.

The OOB network remains the automation and monitoring control plane.

The final hybrid cloud extension is:

```text
EdgeRouter direct NAT underlay on eth3
EdgeRouter WireGuard tunnel endpoint on wg0
AWS EC2 tunnel gateway
Private AWS monitoring EC2
S3-backed analyzer, ML and remediation artifacts
DevOps-controlled Jenkins/Ansible remediation
```