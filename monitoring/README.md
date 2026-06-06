# Monitoring Baseline

This directory contains the first Prometheus monitoring baseline for the intelligent network automation platform.

## Objective

The final monitoring architecture is based on:

```text
Infrastructure metrics and logs
        ↓
Prometheus / exporters
        ↓
AI anomaly detection
        ↓
Dashboard and remediation workflow
```

At this stage, the AWS VPN is still disabled, so cloud-side services cannot directly scrape private GNS3 targets.

For this reason, the first monitoring baseline is local. Prometheus runs in the local DevOps environment, exports metrics snapshots, and Jenkins uploads those snapshots to AWS S3.

## Current Architecture

```text
DevOps VM
        ↓
Prometheus
        ↓
Node Exporter
        ↓
monitoring/outputs/latest/
        ↓
AWS S3
        ↓
latest/metrics/
        ↓
/var/lib/pfe-dashboard/metrics/latest/
        ↓
Flask dashboard / future analyzer
```

## Source of Truth Model

The monitoring workflow follows the same model as validation and analyzer outputs:

```text
Jenkins workspace = temporary generation area
S3 = source of truth
/var/lib/pfe-dashboard = local dashboard cache
GitHub = source code only
```

Metrics are generated temporarily in:

```text
monitoring/outputs/latest/
```

They are uploaded to S3 under:

```text
metrics-snapshots/<jenkins-job-name>-<build-number>/
latest/metrics/
```

Then the latest metrics are restored from S3 into:

```text
/var/lib/pfe-dashboard/metrics/latest/
```

## Structure

```text
monitoring/
├── prometheus/
│   ├── prometheus.yml
│   └── targets/
│       └── node-targets.yml
├── exporters/
│   └── README.md
└── scripts/
    ├── apply-local-prometheus-baseline.sh
    └── export-prometheus-snapshot.sh
```

## Current Scope

The current baseline monitors:

* Prometheus server health
* DevOps VM Linux metrics through Node Exporter

The exported snapshot currently includes:

* target up/down state
* node system information
* available memory
* total memory
* available root filesystem space
* total root filesystem size

## Apply Local Monitoring Baseline

From the repository root:

```bash
./monitoring/scripts/apply-local-prometheus-baseline.sh
```

Prometheus UI:

```text
http://localhost:9090
```

Node Exporter endpoint:

```text
http://localhost:9100/metrics
```

## Export Metrics Snapshot

From the repository root:

```bash
./monitoring/scripts/export-prometheus-snapshot.sh
```

Default temporary output:

```text
monitoring/outputs/latest/
```

This directory is generated and must not be committed to GitHub.

## Jenkins Integration

Jenkins exports the Prometheus snapshot after the validation and analyzer stages.

Correct Jenkins flow:

```text
1. Generate validation reports
2. Upload validation artifacts to S3
3. Run cloud analyzer
4. Upload analyzer results to S3
5. Export Prometheus metrics snapshot
6. Upload metrics snapshot to S3
7. Sync dashboard cache from S3
```

The dashboard cache sync stage restores:

```text
latest/validation-artifacts/ → /var/lib/pfe-dashboard/outputs/
latest/analyzer/             → /var/lib/pfe-dashboard/analyzer/latest/
latest/metrics/              → /var/lib/pfe-dashboard/metrics/latest/
```

## Integration with Cloud Analyzer

Prometheus metrics are now consumed by the cloud analyzer.

The metrics snapshot is generated in:

```text
monitoring/outputs/latest/
```

Then Jenkins uploads it to:

```text
metrics-snapshots/<build>/
latest/metrics/
```

The analyzer reads the local generated metrics snapshot before producing the final anomaly decision.

This means Prometheus is no longer only visualized in the dashboard. It is now part of the anomaly scoring process.

## Future Extensions

Future monitoring work will add:

* GNS3 VM Node Exporter target
* SNMP Exporter for network equipment
* Blackbox Exporter for HTTP/DNS/ICMP checks
* Grafana dashboards
* analyzer rules based on Prometheus metrics
* ML anomaly detection after enough historical data is collected

## Dashboard Visualization

The Flask dashboard reads the latest metrics snapshot from:

```text
/var/lib/pfe-dashboard/metrics/latest/
```

This directory is not generated directly by Prometheus.

It is restored from S3 using:

```text
cloud/scripts/sync-dashboard-cache-from-s3.sh
```

Flow:

```text
Prometheus HTTP API
        ↓
monitoring/outputs/latest/
        ↓
S3 metrics-snapshots/<build>/
S3 latest/metrics/
        ↓
/var/lib/pfe-dashboard/metrics/latest/
        ↓
Flask dashboard
```

The dashboard currently visualizes:

* target availability
* memory usage
* disk usage
* system information
* snapshot timestamp

This connects the monitoring baseline to the same S3-backed dashboard model used by validation reports and analyzer outputs.

## GNS3 VM Metrics Target

The monitoring baseline can also scrape the GNS3 VM host through Node Exporter.

Prometheus target example:

```text
192.168.248.131:9100
```

This monitors the GNS3 VM host resource usage, including CPU/memory/disk metrics exposed by Node Exporter.

It does not directly monitor every FRR/OVS container inside the GNS3 topology. Those can be added later using SNMP Exporter, Blackbox Exporter, or custom exporters.

## Notes

This monitoring baseline does not replace the validation-artifact analyzer.

It complements it by introducing real metrics into the same S3-backed source-of-truth workflow.
