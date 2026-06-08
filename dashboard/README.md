# Flask Validation Dashboard

The dashboard is the local visualization layer of the Intelligent Network Automation Platform.

It displays the latest state of:

```text
Validation reports
Cloud analyzer decision
Prometheus monitoring snapshot
Node Exporter host metrics
Blackbox service probes
SNMPv3 FRR router interface metrics
Infrastructure nodes
Validated services
```

## Data Source Model

The dashboard is cloud-backed.

AWS S3 is the durable source of truth for generated artifacts. The dashboard reads from a synchronized local cache:

```text
/var/lib/pfe-dashboard/
```

The dashboard does not depend on temporary Jenkins workspace files.

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

## Multi-Page Dashboard Layout

The dashboard is split into several pages for readability, transparency and easier presentation during the soutenance.

```text
/                 Overview
/analyzer         Cloud Analyzer Decision
/monitoring       Prometheus, Node Exporter, Blackbox and SNMP metrics
/validation       Validation domains and report previews
/infrastructure   FRR and OVS node table
/services         Validated services
```

## Pages

### Overview

The overview page gives a high-level summary of the platform:

```text
project name
environment
DevOps OOB IP
OOB network
global validation status
report counters
quick access buttons to each dashboard section
latest analyzer summary
latest monitoring summary
```

### Analyzer

The analyzer page displays the latest cloud analyzer decision synchronized from S3.

It shows:

```text
anomaly status
risk score
severity
recommended action
build label
failed reports
warning reports
source decision file
```

### Monitoring

The monitoring page displays the latest Prometheus metrics snapshot.

It shows:

```text
Prometheus scrape target health
Node Exporter memory/disk metrics
Blackbox HTTP/TCP/DNS probes
SNMPv3 FRR router targets
SNMP IF-MIB interface status
SNMP interface traffic counters
SNMP interface error counters
```

SNMP metrics are grouped by FRR router so the interface state of each router is easy to inspect.

### Validation

The validation page displays:

```text
validation domains
report counts by domain
report status
readable report previews
links to full raw reports
```

### Infrastructure

The infrastructure page displays the FRR and OVS nodes loaded from Ansible variables.

It includes:

```text
node name
node type
OOB interface
OOB IP
validation status
link to related report
search filter
```

### Services

The services page displays expected and validated DMZ services.

It includes:

```text
service name
IP address
port
validation method
service status
```

## Configuration

Default paths are defined in:

```text
dashboard/config.py
```

Important default paths:

```text
DASHBOARD_CACHE_DIR=/var/lib/pfe-dashboard
DASHBOARD_OUTPUTS_DIR=/var/lib/pfe-dashboard/outputs
CLOUD_ANALYZER_LATEST_DECISION_FILE=/var/lib/pfe-dashboard/analyzer/latest/decision.json
PROMETHEUS_METRICS_LATEST_DIR=/var/lib/pfe-dashboard/metrics/latest
```

These values can be overridden with environment variables if needed.

## Run Dashboard Locally

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

## Jenkins and S3 Integration

Jenkins uploads generated outputs to S3 and then synchronizes the local dashboard cache.

Current sync model:

```text
latest/validation-artifacts/ → /var/lib/pfe-dashboard/outputs/
latest/analyzer/             → /var/lib/pfe-dashboard/analyzer/latest/
latest/metrics/              → /var/lib/pfe-dashboard/metrics/latest/
```

## Notes

Generated validation reports, analyzer outputs and metrics snapshots are not committed to GitHub.

GitHub stores only:

```text
dashboard source code
templates
static files
DTOs
repositories
services
controllers
documentation
```
