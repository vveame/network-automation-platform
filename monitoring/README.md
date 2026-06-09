# Monitoring Baseline

This directory contains the local Prometheus monitoring baseline for the Intelligent Network Automation Platform.

## Objective

The monitoring layer collects host, service and network-device metrics from the local GNS3/DevOps environment.

The collected metrics are used by:

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

This creates a structured monitoring baseline for future anomaly detection.

## Architecture

The monitoring stack runs on the DevOps VM and monitors the local GNS3 lab.

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
├── FRR router SNMPv3 interface metrics
└── OVS switch SNMPv3 interface metrics
```

## Source of Truth Model

The monitoring layer follows the same artifact model as validation and analyzer outputs.

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

Jenkins uploads metrics snapshots to S3 under:

```text
metrics-snapshots/<build-label>/
latest/metrics/
```

The latest snapshot is synchronized to:

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

Blackbox Exporter validates service reachability without requiring SSH access to service containers.

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

SNMP Exporter collects interface metrics from network devices using SNMPv3.

Current SNMP monitored devices:

```text
5 FRR routers
6 OVS switches
```

Current SNMP targets:

```text
core-frr-1     10.200.0.11:1161
core-frr-2     10.200.0.12:1161
dist-frr-1     10.200.0.21:1161
dist-frr-2     10.200.0.22:1161
edge-router    10.200.0.30:1161
dist-ovs-1     10.200.0.31:1161
dist-ovs-2     10.200.0.32:1161
dmz-ovs-3      10.200.0.33:1161
access-ovs-4   10.200.0.44:1161
access-ovs-5   10.200.0.45:1161
access-ovs-6   10.200.0.46:1161
```

SNMP security model:

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

## Applying the Monitoring Baseline

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

It does not overwrite the final local SNMP Exporter configuration because that file contains local SNMPv3 credentials.

## Building the Local SNMP Exporter Config

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

## Exporting a Metrics Snapshot

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
1. Generate validation reports.
2. Export Prometheus metrics snapshot.
3. Run cloud analyzer with validation and metrics inputs.
4. Upload validation, analyzer and metrics outputs to S3.
5. Sync the local dashboard cache from S3.
6. Display results in the Flask dashboard.
```

## Dashboard Integration

The Flask dashboard reads the latest metrics from:

```text
/var/lib/pfe-dashboard/metrics/latest/
```

The monitoring page visualizes:

```text
Prometheus target availability
Node memory and disk usage
Blackbox service probe results
SNMP network-device target health
SNMP per-device interface status
SNMP interface counters and errors
```

## Grafana Metrics Visualization

Grafana is integrated as the visual observability layer for the Prometheus monitoring baseline. While the Flask dashboard remains the project-level dashboard used to display validation, analyzer and snapshot results, Grafana provides a professional monitoring interface for real-time metrics exploration.

The Grafana integration is based on the same Prometheus metrics already collected by the monitoring baseline:

```text
Prometheus
    ↓
Grafana datasource
    ↓
Provisioned dashboards
    ↓
Metrics visualization for monitoring and anomaly demonstration
```

Grafana is used only for metrics visualization. Log collection with Loki/Alloy was evaluated during implementation, but it was removed from the core scope to keep the project stable and focused. Log-based analysis is kept as a future improvement, while the implemented anomaly detection direction is based on Prometheus metrics.

### Grafana Directory Structure

Grafana files are versioned under:

```text
monitoring/grafana/
├── provisioning/
│   ├── datasources/
│   │   └── prometheus.yml
│   └── dashboards/
│       └── pfe-dashboards.yml
└── dashboards/
    ├── pfe-local-monitoring-overview.json
    ├── pfe-network-devices-interfaces.json
    └── pfe-anomaly-detection-demo.json
```

The provisioning files allow Grafana to load the Prometheus datasource and dashboard JSON files automatically.

### Prometheus Datasource

Grafana uses Prometheus as its main datasource.

```text
Datasource name: Prometheus
Datasource UID: prometheus
Datasource URL: http://localhost:9090
Access mode: proxy
```

This datasource reads the metrics collected by Prometheus from:

```text
Node Exporter
Blackbox Exporter
SNMP Exporter
Prometheus self-monitoring
```

### Provisioned Dashboard Folder

The dashboards are provisioned into the Grafana folder:

```text
PFE Monitoring
```

The local dashboard JSON files are copied to:

```text
/var/lib/grafana/dashboards/pfe/
```

Grafana then loads them through the dashboard provisioning configuration.

## Grafana Dashboards

Three dashboards were added to support the monitoring and anomaly-detection part of the platform.

### 1. PFE - Local Monitoring Overview

File:

```text
monitoring/grafana/dashboards/pfe-local-monitoring-overview.json
```

Purpose:

```text
Provide a global view of the local monitoring baseline.
```

This dashboard shows:

```text
Overall Prometheus target health
Number of targets down
Web/DNS service probe health
Network device reachability
Service availability over time
Service probe latency
DevOps/GNS3 memory usage
DevOps/GNS3 disk usage
SNMP device reachability
Interface error rate
```

This dashboard is used as the main observability overview. It helps verify that the local infrastructure, monitored services and network devices are available before running analyzer or remediation scenarios.

### 2. PFE - Network Devices & Interfaces

File:

```text
monitoring/grafana/dashboards/pfe-network-devices-interfaces.json
```

Purpose:

```text
Visualize the state of the simulated network infrastructure.
```

This dashboard focuses on SNMP-monitored FRR routers and OVS switches.

It shows:

```text
SNMP network device health
Number of unreachable devices
Device uptime
Interface operational status
Administratively enabled interfaces that are operationally down
Interface inbound traffic
Interface outbound traffic
Interface input/output error rate
```

A device variable is included so the user can filter the dashboard by a specific router or switch.

This dashboard is important because the project is focused on network automation, not only server monitoring. It proves that the platform monitors the simulated enterprise network through SNMPv3 metrics.

### 3. PFE - Anomaly Detection Demo

File:

```text
monitoring/grafana/dashboards/pfe-anomaly-detection-demo.json
```

Purpose:

```text
Provide visual evidence for future attack, anomaly and remediation demonstrations.
```

This dashboard does not replace the Python analyzer. Instead, it visualizes the same metric families that will be used by the analyzer.

It shows:

```text
Estimated anomaly risk score
Failed service probes
SNMP devices down
Admin-up interfaces down
Interface error rate
Anomaly risk timeline
Service failure signals
Service latency degradation
Anomaly evidence timeline
Target reachability map
Network interface error evidence
```

The estimated risk score is calculated from metric indicators such as:

```text
Prometheus targets down
Failed Web/DNS Blackbox probes
High service latency
SNMP device failures
Unexpected interface-down events
Interface error rate
High memory usage
High disk usage
```

This dashboard is designed for future demonstrations where abnormal behavior is intentionally introduced into the lab, such as:

```text
Stopping the Web service
Stopping the DNS service
Disconnecting or stopping a network device
Breaking an active interface
Creating latency or reachability degradation
Generating interface errors
```

The dashboard makes the anomaly visible before and after remediation.

## Grafana Alerting

Grafana alerting was added to complete the observability layer of the platform.

The monitoring stack is now composed of:

```text
Prometheus metrics collection
        ↓
Grafana dashboards
        ↓
Grafana alert rules
        ↓
Jenkins analyzer / ML analyzer / safe remediation workflow
```

Grafana dashboards are used to visualize live metrics, while Grafana alert rules are used to detect operational problems in real time.

The alert rules are provisioned as code from:

```text
monitoring/grafana/provisioning/alerting/pfe-alert-rules.yml
```

This follows the same Infrastructure-as-Code logic used in the rest of the platform. Alert rules are not created manually from the Grafana UI; they are stored in the repository and loaded by Grafana from the provisioning directory.

---

### Alerting Directory Structure

Grafana provisioning files are stored under:

```text
monitoring/grafana/provisioning/
├── datasources/
│   └── prometheus.yml
├── dashboards/
│   └── pfe-dashboards.yml
└── alerting/
    └── pfe-alert-rules.yml
```

The alert rules must be copied to the local Grafana provisioning path:

```text
/etc/grafana/provisioning/alerting/
```

Example:

```bash
sudo mkdir -p /etc/grafana/provisioning/alerting

sudo cp monitoring/grafana/provisioning/alerting/pfe-alert-rules.yml \
  /etc/grafana/provisioning/alerting/pfe-alert-rules.yml

sudo systemctl restart grafana-server
```

After restart, the rules are visible in Grafana under:

```text
Alerting → Alert rules → PFE Monitoring
```

Provisioned rules are managed from files. If a rule needs to be modified, the YAML file should be updated and Grafana should be restarted or reloaded.

---

### Provisioned Alert Rules

The current Grafana alert group is:

```text
PFE - Network Anomaly Alerts
```

It contains the following rules:

| Alert rule                                    | Purpose                                                                     | Severity | Suggested action            |
| --------------------------------------------- | --------------------------------------------------------------------------- | -------- | --------------------------- |
| `PFE - Service Probe Failed`                  | Detects failed HTTP/TCP/DNS Blackbox probes                                 | Critical | Check DMZ Web/DNS services  |
| `PFE - SNMP Device Down`                      | Detects unreachable SNMP-monitored routers/switches                         | Critical | Collect network diagnostics |
| `PFE - Admin-Up Interface Operationally Down` | Detects interfaces that are administratively enabled but operationally down | Warning  | Run validation gate         |
| `PFE - Interface Errors or Discards Detected` | Detects increasing SNMP interface errors or discards                        | Warning  | Collect network diagnostics |
| `PFE - Host High CPU Usage`                   | Detects high CPU usage on monitored hosts                                   | Warning  | Collect host diagnostics    |
| `PFE - Estimated Anomaly Risk High`           | Detects a high Prometheus-based anomaly risk score                          | Warning  | Review anomaly decision     |

These rules are based on the same Prometheus metrics used by the Grafana dashboards and the anomaly detection pipeline.

---

### Alert Metrics

The alert rules use metrics from:

```text
Blackbox Exporter
Node Exporter
SNMP Exporter
Prometheus target health
```

Important metrics include:

```text
probe_success
probe_duration_seconds
up
ifAdminStatus
ifOperStatus
ifInErrors
ifOutErrors
ifInDiscards
ifOutDiscards
node_cpu_seconds_total
```

These metrics allow Grafana to detect service failures, unreachable network devices, interface problems and host resource pressure.

---

### Alerting Role in the Platform

Grafana alerts are not responsible for applying remediation directly.

The role separation is:

```text
Prometheus = collects metrics
Grafana = visualizes metrics and raises live alerts
Jenkins analyzer = processes validation reports and metric snapshots
ML analyzer = detects unusual metric behavior
Final decision merger = combines rule-based and ML results
Safe remediation runner = plans or applies allowlisted actions
```

This means Grafana is used for live operational alerting, while Jenkins remains the controlled remediation orchestrator.

This separation is important for safety. Grafana can detect that a problem exists, but remediation is still controlled by Jenkins parameters, final analyzer decisions and explicit confirmation.

---

### Alert States

Grafana alert rules can move through these states:

```text
Normal
Pending
Firing
No data
Error
```

Typical behavior:

```text
Healthy service      → Normal
Temporary issue      → Pending
Confirmed issue      → Firing
Missing metric data  → No data or OK depending on rule configuration
Query problem        → Error
```

For this project, most rules use:

```text
noDataState: OK
execErrState: Error
```

This avoids false alerts when optional metrics are temporarily missing, while still exposing real query errors.

---

### Testing Alerts

To test a service alert, temporarily stop a monitored DMZ service and wait for the rule duration.

Example scenario:

```text
Stop DMZ Web service
        ↓
Blackbox HTTP/TCP probe fails
        ↓
PFE - Service Probe Failed becomes Pending
        ↓
After the configured duration, it becomes Firing
```

Then restore the service and verify that the alert returns to Normal.

To test network-device alerts, stop or isolate an SNMP-monitored device and check:

```text
PFE - SNMP Device Down
PFE - Admin-Up Interface Operationally Down
```

To test host alerts, generate temporary CPU load on a monitored host and check:

```text
PFE - Host High CPU Usage
```

---

### Checking Alert Rules

After copying the provisioning file and restarting Grafana, check the service status:

```bash
sudo systemctl status grafana-server --no-pager
```

Check Grafana logs if rules do not appear:

```bash
sudo journalctl -u grafana-server -n 100 --no-pager
```

Open Grafana:

```text
http://10.200.0.10:3000
```

Then go to:

```text
Alerting → Alert rules → PFE Monitoring
```

---

### Important Notes

Grafana alerting is part of the observability layer, not the remediation layer.

The final remediation decision is still produced by the analyzer pipeline:

```text
Validation reports
        ↓
Prometheus snapshot
        ↓
Rule-based analyzer
        ↓
ML analyzer
        ↓
Hybrid final decision
        ↓
Safe remediation runner
```

Grafana alerts support the operator by showing live problems quickly, while the Jenkins pipeline produces auditable decisions, S3 artifacts and controlled remediation outputs.

## Metrics-Based Anomaly Detection Direction

The project now focuses on metrics-based anomaly detection instead of log-based detection.

The implemented monitoring baseline provides enough structured time-series data to detect several important anomaly scenarios:

```text
Service unavailability
Service latency degradation
Device reachability failure
Interface operational failure
Interface error increase
Host memory saturation
Host disk saturation
```

This approach is suitable for the scope of the project because the objective is not forensic log analysis. The objective is to detect abnormal infrastructure behavior and prepare automated remediation actions.

The final anomaly detection flow is:

```text
Prometheus metrics
    ↓
Metrics snapshot export
    ↓
Python analyzer
    ↓
Risk score and anomaly classification
    ↓
Jenkins remediation pipeline
    ↓
Dashboard/report update
```

Logs are kept as a perspective for future improvement. They can later be added to improve root-cause analysis, but they are not required for the core anomaly detection and remediation demonstration.

## Updated Monitoring Scope

The current monitoring scope includes:

```text
1. Host monitoring
   - DevOps server
   - GNS3 VM
   - Memory usage
   - Disk usage
   - Host availability

2. Service monitoring
   - DMZ Web HTTP probe
   - DMZ Web TCP/80 probe
   - DMZ DNS TCP/53 probe
   - DNS query probe
   - Probe success
   - Probe duration
   - HTTP status code

3. Network device monitoring
   - FRR routers
   - OVS switches
   - SNMPv3 reachability
   - Device uptime
   - Interface admin status
   - Interface operational status
   - Interface traffic counters
   - Interface error counters

4. Visualization
   - Grafana overview dashboard
   - Grafana network devices and interfaces dashboard
   - Grafana anomaly detection demo dashboard

5. Analyzer preparation
   - Metrics exported as snapshots
   - Risk indicators prepared from Prometheus metrics
   - Future remediation actions triggered from analyzer output
```

## Applying Grafana Files

After adding or updating Grafana dashboard JSON files, copy them to the Grafana dashboard provisioning directory:

```bash
sudo mkdir -p /var/lib/grafana/dashboards/pfe

sudo cp monitoring/grafana/dashboards/*.json /var/lib/grafana/dashboards/pfe/

sudo chown -R grafana:grafana /var/lib/grafana/dashboards/pfe

sudo systemctl restart grafana-server
```

The dashboards can then be accessed from:

```text
Grafana → Dashboards → PFE Monitoring
```

## Notes

Grafana dashboards are stored as JSON files in GitHub so they can be versioned, reused and restored easily.

Generated runtime data is not committed. GitHub only stores:

```text
Prometheus configuration
Blackbox configuration
SNMP templates and safe examples
Grafana provisioning files
Grafana dashboard JSON files
Scripts
Documentation
```

The monitoring implementation therefore remains reproducible while keeping local credentials, generated snapshots and runtime outputs outside the repository.

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

Special interfaces may be displayed for visibility but ignored in anomaly scoring:

```text
lo
vrrp*
ovs-system
```

## Notes

Do not commit:

```text
monitoring/snmp/snmp-auth.local.yml
monitoring/outputs/
```

GitHub stores only safe versioned files, templates, scripts and documentation.
