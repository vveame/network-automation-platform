# Monitoring Baseline

This directory contains the local Prometheus monitoring baseline for the intelligent network automation platform.

## Objective

The monitoring layer collects infrastructure, service and network-device metrics from the local GNS3/DevOps environment.

The monitoring data is used by:

```text
Prometheus
        ↓
metrics snapshot export
        ↓
AWS S3 source of truth
        ↓
Flask dashboard visualization
        ↓
cloud analyzer risk scoring
```

This baseline prepares the project for future AI/ML anomaly detection by producing structured and repeatable metrics snapshots.

## Architecture

The current monitoring architecture is local because the hybrid VPN/cloud link is not yet the active scraping path.

```text
DevOps VM
├── Prometheus
├── Node Exporter
├── Blackbox Exporter
└── SNMP Exporter

GNS3 lab
├── GNS3 VM Node Exporter target
├── DMZ Web service probes
├── DMZ DNS service probes
└── EdgeRouter SNMPv3 interface metrics
```

## Source of Truth Model

The monitoring workflow follows the same source-of-truth model as validation reports and analyzer outputs.

```text
Jenkins workspace = temporary generation area
AWS S3 = durable source of truth
/var/lib/pfe-dashboard = local dashboard cache
GitHub = source code, templates and scripts only
```

Generated local metrics are stored temporarily in:

```text
monitoring/outputs/latest/
```

Jenkins uploads them to S3 under:

```text
metrics-snapshots/<build-label>/
latest/metrics/
```

Then the dashboard cache is synchronized to:

```text
/var/lib/pfe-dashboard/metrics/latest/
```

## Structure

```text
monitoring/
├── prometheus/
│   ├── prometheus.yml
│   └── targets/
│       ├── node-targets.yml
│       ├── blackbox-http-targets.yml
│       ├── blackbox-tcp-targets.yml
│       ├── blackbox-dns-targets.yml
│       └── snmp-targets.yml
├── blackbox/
│   └── blackbox.yml
├── snmp/
│   ├── README.md
│   ├── snmp-auth.local.yml.example
│   ├── snmp.yml.example
│   └── prometheus-snmp-exporter.default
└── scripts/
    ├── apply-local-prometheus-baseline.sh
    ├── build-local-snmp-exporter-config.sh
    └── export-prometheus-snapshot.sh
```

## Monitored Sources

### Prometheus self-monitoring

```text
Prometheus target health
Prometheus scrape status
```

### Node Exporter

Current host targets:

```text
devops-server
gns3-vm
```

Collected metrics include:

```text
node_uname_info
node_memory_MemAvailable_bytes
node_memory_MemTotal_bytes
node_filesystem_avail_bytes
node_filesystem_size_bytes
```

### Blackbox Exporter

Current probes:

```text
DMZ Web HTTP: http://172.16.50.10
DMZ Web TCP/80: 172.16.50.10:80
DMZ DNS TCP/53: 172.16.50.20:53
DNS query: web.pfe.local via 172.16.50.20
```

Collected metrics include:

```text
probe_success
probe_duration_seconds
probe_http_status_code
```

### SNMP Exporter

Current SNMP target:

```text
EdgeRouter-VPNGateway: 10.200.0.30:1161
```

Security:

```text
SNMPv3 authPriv
SHA authentication
AES privacy
Read-only access
UDP/1161 allowed only from DevOps OOB IP
```

Collected metrics include:

```text
up{job="snmp-network-devices"}
sysUpTime
ifAdminStatus
ifOperStatus
ifHCInOctets
ifHCOutOctets
ifInErrors
ifOutErrors
```

## Apply Monitoring Baseline

From the repository root:

```bash
./monitoring/scripts/apply-local-prometheus-baseline.sh
```

This script installs/restarts:

```text
prometheus
prometheus-node-exporter
prometheus-blackbox-exporter
prometheus-snmp-exporter
snmp tools
```

It copies versioned Prometheus/Blackbox/target files, but it does not overwrite:

```text
/etc/prometheus/snmp.yml
```

That file is generated locally because it contains SNMPv3 credentials.

## Build Local SNMP Exporter Config

Before applying SNMP monitoring for the first time:

```bash
./monitoring/scripts/build-local-snmp-exporter-config.sh
```

The generated file is:

```text
/etc/prometheus/snmp.yml
```

## Export Metrics Snapshot

From the repository root:

```bash
./monitoring/scripts/export-prometheus-snapshot.sh
```

Default output:

```text
monitoring/outputs/latest/
```

The snapshot includes:

```text
up.json
node_uname_info.json
node_memory_available_bytes.json
node_memory_total_bytes.json
node_filesystem_available_bytes.json
node_filesystem_size_bytes.json
blackbox_probe_success.json
blackbox_probe_duration_seconds.json
blackbox_http_status_code.json
snmp_up.json
snmp_sys_uptime.json
snmp_if_admin_status.json
snmp_if_oper_status.json
snmp_if_hc_in_octets.json
snmp_if_hc_out_octets.json
snmp_if_in_errors.json
snmp_if_out_errors.json
```

## Jenkins Integration

The Jenkins pipeline exports a Prometheus snapshot after validation/analyzer stages.

Expected flow:

```text
1. Generate validation reports
2. Upload validation artifacts to S3
3. Export Prometheus metrics snapshot
4. Run cloud analyzer with validation + metrics inputs
5. Upload analyzer outputs to S3
6. Upload metrics snapshot to S3
7. Sync dashboard cache from S3
```

## Dashboard Integration

The Flask dashboard reads the latest metrics from:

```text
/var/lib/pfe-dashboard/metrics/latest/
```

It visualizes:

```text
Prometheus target availability
Node memory/disk usage
Blackbox service probes
SNMP edge-router interface status
SNMP interface counters
```

## Analyzer Integration

The analyzer uses monitoring metrics as part of its rule-based risk score.

Current metrics-based risk inputs:

```text
Prometheus targets down
Blackbox probes failed
High memory usage
High disk usage
SNMP target down
SNMP interface unexpectedly down
SNMP interface errors
```

## Notes

Generated monitoring outputs are not committed to GitHub.

GitHub stores only:

```text
Prometheus configuration
Exporter target definitions
Safe examples
Automation scripts
Documentation
```
