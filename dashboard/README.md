# Flask Validation Dashboard

This dashboard provides a visual view of the latest infrastructure validation, analyzer and monitoring state.

## Purpose

The dashboard is the local visualization layer of the intelligent network automation platform.

It displays:

```text
Validation reports
Cloud analyzer decision
Prometheus metrics snapshot
Node metrics
Blackbox service probes
SNMP network interface metrics
```

## Data Source Model

The dashboard is cloud-backed.

AWS S3 is the durable source of truth for generated artifacts. The dashboard reads from a local synchronized cache:

```text
/var/lib/pfe-dashboard/
```

This avoids depending on temporary Jenkins workspace files or generated files inside the Git repository.

## Local Cache Structure

```text
/var/lib/pfe-dashboard/
├── outputs/
│   ├── validation-summary.txt
│   ├── security-validation.txt
│   ├── dmz-services.txt
│   └── other validation reports
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

## Dashboard Features

The dashboard displays:

```text
Global validation status
Validation report totals
Validation domains
Infrastructure node status
Validated DMZ services
Readable report previews
Latest cloud analyzer decision
Prometheus target health
Per-node memory/disk metrics
Blackbox service probe results
SNMP edge-router interface status and counters
```

## Cloud Analyzer Decision

The dashboard reads the latest analyzer decision from:

```text
/var/lib/pfe-dashboard/analyzer/latest/decision.json
```

Displayed fields:

```text
anomaly status
risk score
severity
recommended action
build label
failed reports
warning reports
```

## Prometheus Metrics Visualization

The dashboard reads the latest Prometheus metrics snapshot from:

```text
/var/lib/pfe-dashboard/metrics/latest/
```

Displayed metrics include:

```text
targets up/down
memory usage
disk usage
system information
snapshot timestamp
per-node metrics
Blackbox probe results
SNMP interface status
SNMP interface counters
```

## SNMP Visualization

The SNMP section displays interface metrics from the edge-router collected through:

```text
SNMPv3
SNMP Exporter
Prometheus
metrics snapshot export
S3-backed dashboard cache
```

Displayed SNMP fields:

```text
node name
interface name
interface index
admin status
operational status
input octets
output octets
input/output errors
```

## Running the Dashboard on Ubuntu

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
