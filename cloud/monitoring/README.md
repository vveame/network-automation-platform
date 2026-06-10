# Cloud Monitoring and AI Runtime

This directory contains the cloud-side monitoring configuration for the private AWS monitoring EC2 instance.

## Purpose

The local monitoring baseline under `monitoring/` remains available for the DevOps VM.

This directory adds the cloud monitoring layer used after validating the EdgeRouter-based WireGuard tunnel.

The private monitoring EC2 hosts:

```text
Prometheus
Grafana
Node Exporter
Blackbox Exporter
SNMP Exporter
Cloud analyzer runtime
ML anomaly detection runtime
```

## Target Architecture

```text
Local GNS3 / DevOps environment
    ↓
EdgeRouter-VPNGateway
    ↓ WireGuard
AWS EC2 tunnel gateway
    ↓
Private monitoring EC2
    ├── Prometheus
    ├── Grafana
    ├── Blackbox Exporter
    ├── SNMP Exporter
    ├── cloud/analyzer
    └── cloud/analyzer/ml
```

## Responsibilities

The cloud monitoring EC2 is responsible for:

```text
scraping local infrastructure metrics through the tunnel
visualizing metrics in Grafana
hosting the analyzer and ML runtime
preparing anomaly decisions
```

The local DevOps/Jenkins node remains responsible for:

```text
CI/CD orchestration
Ansible validation
controlled remediation execution
S3 upload and dashboard synchronization
```

Cloud AI does not directly modify routers or switches.

## Files

```text
cloud/monitoring/
├── prometheus/
│   └── prometheus.cloud.yml
├── targets/
│   ├── cloud-node-targets.yml
│   ├── cloud-blackbox-http-targets.yml
│   ├── cloud-blackbox-tcp-targets.yml
│   ├── cloud-blackbox-dns-targets.yml
│   └── cloud-snmp-targets.yml
├── blackbox/
│   └── blackbox.cloud.yml
├── grafana/
│   ├── provisioning/
│   └── dashboards/
└── scripts/
    └── install-cloud-monitoring-ai.sh
```

Deployment and validation scripts are stored under:

```text
cloud/scripts/deploy-cloud-monitoring-ai.sh
cloud/scripts/validate-cloud-monitoring-ai.sh
```

## Deployment

From the DevOps VM:

```bash
sudo ./scripts/devops/enable-edge-router-internet-underlay-nat.sh
sudo ./scripts/devops/route-cloud-via-edge-router.sh
./cloud/scripts/enable-monitoring-egress-nat-on-tunnel-gateway.sh
./cloud/scripts/deploy-cloud-monitoring-ai.sh
./cloud/scripts/validate-cloud-monitoring-ai.sh
```

## Access

Prometheus and Grafana are private. Access them through SSH port forwarding:

```bash
cd cloud/terraform/environments/dev
MON_IP="$(terraform output -raw monitoring_private_ip)"

ssh -o IdentitiesOnly=yes -o IPQoS=none \
  -i ~/.ssh/pfe-aws-tunnel \
  -L 9090:localhost:9090 \
  -L 3000:localhost:3000 \
  ec2-user@"$MON_IP"
```

## SNMP Credentials

The SNMP Exporter configuration contains real SNMPv3 credentials and must not be committed.

The deployment script copies the generated local file if it exists:

```text
/etc/prometheus/snmp.yml
```

to the private monitoring EC2 as:

```text
/etc/snmp_exporter/snmp.yml
```

## Alerting Files

Cloud monitoring includes the alerting layer from the local monitoring baseline.

Grafana alert provisioning files are copied from:

```text
monitoring/grafana/provisioning/alerting/
```

to:

```text
cloud/monitoring/grafana/provisioning/alerting/
```

During deployment, they are installed on the private monitoring EC2 under:

```text
/etc/grafana/provisioning/alerting/
```

Grafana loads these files as provisioned alerting resources.

Prometheus alert and recording rules are stored under:

```text
cloud/monitoring/prometheus/rules/
```

During deployment, they are installed on the private monitoring EC2 under:

```text
/etc/prometheus/rules/
```

The cloud Prometheus configuration loads them through:

```text
rule_files:
  - "/etc/prometheus/rules/*.yml"
  - "/etc/prometheus/rules/*.yaml"
```

This ensures that the cloud monitoring stack contains:

```text
Prometheus scrape configuration
Prometheus alert rules
Grafana dashboards
Grafana datasource provisioning
Grafana dashboard provisioning
Grafana alerting provisioning
```

## Notes

The private monitoring EC2 has no public IP address.

Internet egress for package installation is provided through the AWS EC2 tunnel gateway acting as a small NAT instance for the monitoring subnet.

The EdgeRouter-based WireGuard tunnel remains the communication path between the local lab and AWS.
