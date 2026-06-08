# Monitoring Baseline

This directory contains the local Prometheus monitoring baseline for the Intelligent Network Automation Platform.

## Objective

The monitoring layer collects host, service and network-device metrics from the local GNS3/DevOps environment.

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

This creates a structured metrics baseline for future anomaly detection.

## Architecture

The current monitoring architecture runs on the DevOps VM and monitors the local GNS3 lab.

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
└── FRR router SNMPv3 interface metrics
```

## Source of Truth Model

The project follows the same artifact model for validation, analyzer and monitoring outputs.

```text
Jenkins workspace = temporary generation area
AWS S3 = durable source of truth
/var/lib/pfe-dashboard = local dashboard cache
GitHub = source code, templates, safe examples and scripts only
```

Generated monitoring snapshots are temporary in:

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

## Directory Structure

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

### Prometheus Self-Monitoring

Prometheus monitors its own scrape health through the `up` metric.

### Node Exporter

Current host targets:

```text
devops-server
gns3-vm
```

Collected host metrics include:

```text
node_uname_info
node_memory_MemAvailable_bytes
node_memory_MemTotal_bytes
node_filesystem_avail_bytes
node_filesystem_size_bytes
```

### Blackbox Exporter

Current probes include:

```text
DMZ Web HTTP probe
DMZ Web TCP/80 probe
DMZ DNS TCP/53 probe
DNS query probe
```

Collected probe metrics include:

```text
probe_success
probe_duration_seconds
probe_http_status_code
```

### SNMP Exporter

SNMP Exporter is used to collect interface metrics from all FRR routers.

Current SNMP targets:

```text
core-frr-1    10.200.0.11:1161
core-frr-2    10.200.0.12:1161
dist-frr-1    10.200.0.21:1161
dist-frr-2    10.200.0.22:1161
edge-router   10.200.0.30:1161
```

Security model:

```text
SNMP version: SNMPv3
Security level: authPriv
Authentication: SHA
Privacy/encryption: AES
Access type: read-only
SNMP port: UDP/1161
Allowed source: DevOps OOB IP 10.200.0.10
```

Collected SNMP metrics include:

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

This script installs and configures:

```text
prometheus
prometheus-node-exporter
prometheus-blackbox-exporter
prometheus-snmp-exporter
snmp tools
```

It copies versioned Prometheus, Blackbox and target files into `/etc/prometheus`.

It does not blindly overwrite the local SNMP Exporter secrets. The final SNMP Exporter config is generated locally because it contains SNMPv3 credentials.

## Build Local SNMP Exporter Config

First create the local SNMP auth file:

```bash
cp monitoring/snmp/snmp-auth.local.yml.example monitoring/snmp/snmp-auth.local.yml
nano monitoring/snmp/snmp-auth.local.yml
```

Then generate the local SNMP Exporter config:

```bash
./monitoring/scripts/build-local-snmp-exporter-config.sh
```

This creates:

```text
/etc/prometheus/snmp.yml
```

That file contains real SNMPv3 credentials and must not be committed.

## Export Metrics Snapshot

From the repository root:

```bash
./monitoring/scripts/export-prometheus-snapshot.sh
```

Default output:

```text
monitoring/outputs/latest/
```

Exported files include:

```text
manifest.json
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

The Jenkins pipeline uses this monitoring baseline after local validation.

Expected flow:

```text
1. Generate validation reports
2. Export Prometheus metrics snapshot
3. Run cloud analyzer with validation + metrics inputs
4. Upload validation, analyzer and metrics outputs to S3
5. Sync the local dashboard cache from S3
6. Display results in the Flask dashboard
```

## Dashboard Integration

The Flask dashboard reads the latest metrics from:

```text
/var/lib/pfe-dashboard/metrics/latest/
```

The monitoring page visualizes:

```text
Prometheus target availability
Node memory/disk usage
Blackbox service probe results
SNMP FRR router target health
SNMP per-router interface status
SNMP interface counters and errors
```

## Analyzer Integration

The analyzer uses monitoring metrics as part of its rule-based risk score.

Current metrics-based risk inputs:

```text
Prometheus targets down
Blackbox probes failed
high memory usage
high disk usage
SNMP target down
SNMP interface unexpectedly down
SNMP interface errors
```

Loopback and VRRP virtual interfaces may be displayed in the dashboard for visibility, but they are not treated like physical or routed interfaces for anomaly scoring.

## Notes

Do not commit:

```text
monitoring/snmp/snmp-auth.local.yml
monitoring/outputs/
```

GitHub stores only safe versioned files, templates, scripts and documentation.
