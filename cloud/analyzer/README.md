# Cloud Analyzer

This directory contains the first anomaly-detection baseline for the intelligent network automation platform.

## Purpose

The final project objective is to analyze monitoring metrics and logs collected from the infrastructure and use them to detect anomalies.

At this stage, the analyzer uses an explainable rule-based baseline.

It combines:

```text
Ansible validation reports
Prometheus monitoring metrics
Blackbox service probes
SNMP network interface metrics
```

This creates a structured baseline before future historical/statistical or machine-learning anomaly detection.

## Current Flow

```text
Local GNS3 topology
        ↓
Ansible validation
        ↓
Jenkins pipeline
        ↓
ansible/outputs/
        ↓
Prometheus metrics snapshot
        ↓
monitoring/outputs/latest/
        ↓
Cloud analyzer
        ↓
summary.json + decision.json + analysis-report.txt
        ↓
AWS S3 latest/analyzer/
        ↓
Flask dashboard
```

## Structure

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

It can analyze local validation artifacts and optionally include a Prometheus metrics snapshot.

### parse_validation_reports.py

Parses raw validation report files.

Responsibilities:

```text
read .txt reports
classify report category
detect critical patterns
detect warning patterns
handle expected security-block test results
mark reports as passed, warning, failed or empty
```

### parse_prometheus_metrics.py

Parses exported Prometheus metric JSON files.

Current parsed metric groups:

```text
Prometheus target health
Node memory/disk/system metrics
Blackbox service probes
SNMP target health
SNMP interface status
SNMP interface counters
SNMP interface errors
```

### anomaly_rules.py

Contains explainable anomaly scoring logic.

It calculates:

```text
validation_risk_score
metrics_risk_score
risk_score
severity
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

The analyzer uses rule-based risk scoring.

### Validation risk

Validation reports increase risk when they show:

```text
security validation failure
end-to-end validation failure
OOB management failure
FRR/routing validation failure
OVS/switching validation failure
DMZ validation failure
critical error patterns
warning patterns
```
Expected blocked-policy tests are handled separately. For example, blocked SSH or HTTP tests can produce timeouts, but those timeouts are normal when they appear in explicit blocked-policy sections.

### Metrics risk

Prometheus metrics increase risk when they show:

```text
Prometheus targets down
Blackbox probes failed
high memory usage
high disk usage
SNMP target down
SNMP interface unexpectedly down
SNMP interface errors
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

The analyzer treats an interface as unexpected down when:

```text
admin_status = up
oper_status != up
interface != lo
```

The loopback interface is parsed but ignored for unexpected-down risk.

## Why Rule-Based First

A full ML model needs historical metrics, repeated normal baselines and enough anomaly examples.

This rule-based analyzer creates the first structured anomaly baseline and prepares the project for later ML work.

Future extensions can add:

```text
historical Prometheus trend analysis
statistical thresholds
log-event correlation
ML anomaly detection
automated remediation proposals
```
