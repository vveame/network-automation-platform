# Cloud Analyzer

This directory contains the first anomaly-detection baseline for the Intelligent Network Automation Platform.

## Purpose

The analyzer combines validation reports and Prometheus monitoring metrics to produce an explainable anomaly decision.

At this stage, the analyzer is rule-based. This makes the logic transparent and easier to explain before adding future statistical or machine-learning anomaly detection.

## Current Inputs

The analyzer uses:

```text
Ansible validation reports
Prometheus scrape target health
Node Exporter memory and disk metrics
Blackbox service probe metrics
SNMPv3 network-device interface metrics
```

The SNMP metrics now include both:

```text
FRR routers
OVS switches
```

## Current Flow

```text
Local GNS3 topology
        ↓
Ansible validation
        ↓
Jenkins pipeline
        ↓
validation reports
        ↓
Prometheus metrics snapshot
        ↓
Cloud analyzer
        ↓
summary.json + decision.json + analysis-report.txt
        ↓
AWS S3 latest/analyzer/
        ↓
Flask multi-page dashboard
```

## Directory Structure

```text
cloud/analyzer/
├── analyze_validation_artifacts.py
├── parse_validation_reports.py
├── parse_prometheus_metrics.py
├── anomaly_rules.py
├── generate_summary.py
├── requirements.txt
└── README.md
```

## Components

### analyze_validation_artifacts.py

Main CLI entrypoint.

It accepts:

```text
--input-dir     validation report directory
--metrics-dir   Prometheus metrics snapshot directory
--output-dir    analyzer output directory
--build-label   build identifier
```

### parse_validation_reports.py

Parses raw validation report files.

It detects:

```text
passed reports
warning reports
failed reports
empty reports
critical patterns
warning patterns
expected blocked security behavior
```

### parse_prometheus_metrics.py

Parses exported Prometheus metric JSON files.

Current parsed metric groups:

```text
Prometheus scrape target health
Node memory/disk/system metrics
Blackbox service probes
SNMP target health
SNMP interface status
SNMP interface counters
SNMP interface errors
```

### anomaly_rules.py

Contains explainable risk scoring logic.

It calculates:

```text
validation_risk_score
metrics_risk_score
global risk_score
severity
anomaly_status
recommended_action
detection_reasons
```

### generate_summary.py

Generates analyzer output files:

```text
summary.json
decision.json
analysis-report.txt
```

## Detection Logic

The analyzer calculates two risk parts:

```text
validation risk
metrics risk
```

Then it combines them into the final risk score.

## Validation Risk

Validation risk increases when reports show:

```text
security validation failure
end-to-end validation failure
OOB management validation failure
FRR/routing validation failure
OVS/switching validation failure
DMZ validation failure
critical error patterns
warning patterns
```

Expected blocked-policy tests are handled separately.

For example, a timeout can be normal when validating that unauthorized SSH or HTTP access is blocked.

## Metrics Risk

Metrics risk increases when Prometheus data shows:

```text
Prometheus scrape targets down
Blackbox probes failed
high memory usage
high disk usage
SNMP target down
SNMP interface unexpectedly down
SNMP interface errors
```

## SNMP Risk Logic

SNMP metrics are collected from all monitored network devices.

Current SNMP scope:

```text
5 FRR routers
6 OVS switches
11 total SNMP network devices
```

Current SNMP devices:

```text
core-frr-1
core-frr-2
dist-frr-1
dist-frr-2
edge-router
dist-ovs-1
dist-ovs-2
dmz-ovs-3
access-ovs-4
access-ovs-5
access-ovs-6
```

SNMP interface status is interpreted using IF-MIB values:

```text
1 = up
2 = down
3 = testing
4 = unknown
5 = dormant
6 = notPresent
7 = lowerLayerDown
```

An interface is considered unexpectedly down when:

```text
admin_status = up
oper_status != up
interface is health-relevant
```

Ignored for unexpected-down risk:

```text
lo
vrrp*
ovs-system
```

These interfaces are still useful for visibility, but they are not treated like physical or routed link interfaces in anomaly scoring.

## Health-Relevant Interfaces

Health-relevant interfaces include:

```text
FRR physical interfaces
FRR routed interfaces
FRR VLAN subinterfaces
OVS bridge interface br0
OVS management interface mgmt0
OVS physical/container interfaces eth*
```

Ignored interfaces are excluded from risk scoring to avoid false positives.

Examples:

```text
lo:
  Loopback interface. Not treated as a network link failure.

vrrp*:
  VRRP virtual interface. Can be down on backup/standby behavior.

ovs-system:
  Internal OVS system interface. Can appear down without meaning a physical switch link failed.
```

## Severity Levels

The analyzer maps the final risk score to:

```text
0-24     low       normal
25-49    medium    anomalous
50-74    high      anomalous
75-100   critical  anomalous
```

## Example Healthy Output

```text
Global validation status: passed
Anomaly status: normal
Risk score: 0/100
Validation risk score: 0/100
Metrics risk score: 0/100
Severity: low
Recommended action: no_action

Targets up: all expected targets
Blackbox probes success: all expected probes
SNMP targets up: 11/11
SNMP targets down: 0
SNMP unexpected interface down: 0
SNMP interfaces with errors: 0
```

## Run Locally

First export a fresh metrics snapshot:

```bash
./monitoring/scripts/export-prometheus-snapshot.sh
```

Then run the analyzer:

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

## Outputs

The analyzer generates:

```text
cloud/analyzer/outputs/summary.json
cloud/analyzer/outputs/decision.json
cloud/analyzer/outputs/analysis-report.txt
```

Jenkins uploads them to S3 under:

```text
processed-summaries/<build-label>/
anomaly-results/<build-label>/
latest/analyzer/
```

## Why Rule-Based First

A full ML model needs historical metrics, repeated normal baselines and enough anomaly examples.

The current analyzer creates the first explainable anomaly baseline and prepares the project for future ML work.

Future extensions can add:

```text
historical Prometheus trend analysis
statistical thresholds
log-event correlation
machine-learning anomaly detection
automated remediation proposals
```

## Do Not Commit

Do not commit generated analyzer outputs:

```text
cloud/analyzer/outputs/
```
