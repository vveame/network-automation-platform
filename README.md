# Intelligent Network Automation Platform

## 1. Purpose of the Platform

The project implements an intelligent network automation platform for a virtual enterprise-like network laboratory. The platform combines local network validation, monitoring, cloud-backed artifact storage, anomaly detection, machine learning analysis, safe remediation, and dashboard visualization.

The objective is not only to deploy a network topology, but also to automate the operational cycle around it:

```text
Validate → Monitor → Analyze → Detect → Decide → Remediate safely → Visualize
```

The platform is designed around DevOps and Cloud Computing principles. It uses Jenkins as the automation orchestrator, Prometheus and Grafana for observability, AWS S3 for durable artifact storage, Python analyzers for anomaly detection, and a Flask dashboard for final decision visualization.

---

## 2. Global Architecture

The platform is divided into several logical layers:

```text
GitHub Repository
      ↓
GitHub Actions Self-Hosted Runner
      ↓
Jenkins Automation Server
      ↓
Local GNS3 Infrastructure
      ↓
Ansible Validation
      ↓
Prometheus Monitoring Snapshot
      ↓
Rule-Based Cloud Analyzer
      ↓
ML Isolation Forest Analyzer
      ↓
Hybrid Final Decision
      ↓
Safe Remediation Runner
      ↓
AWS S3 Artifact Storage
      ↓
Flask Dashboard + Grafana Dashboards
```

Each layer has a clear role:

| Layer                   | Role                                                                                                 |
| ----------------------- | ---------------------------------------------------------------------------------------------------- |
| GitHub                  | Stores source code, Jenkinsfile, scripts, dashboard code, monitoring configuration and documentation |
| GitHub Actions Runner   | Triggers Jenkins from a public GitHub repository without exposing Jenkins to the Internet            |
| Jenkins                 | Orchestrates the full validation, monitoring, ML, S3 and remediation workflow                        |
| GNS3                    | Hosts the virtual network lab with FRRouting routers, OVS switches and service containers            |
| Ansible                 | Validates the state of routers, switches, services and network paths                                 |
| Prometheus              | Collects monitoring metrics from services, hosts and network devices                                 |
| Grafana                 | Displays live metric evidence for monitoring and anomaly explanation                                 |
| Python Analyzer         | Processes validation reports and metrics into anomaly decisions                                      |
| ML Analyzer             | Uses Isolation Forest to detect unusual metric behavior                                              |
| Safe Remediation Runner | Selects and optionally applies predefined safe actions                                               |
| AWS S3                  | Stores all generated outputs as the durable source of truth                                          |
| Flask Dashboard         | Displays the latest validation, monitoring, analyzer, ML and remediation results                     |

---

## 3. Source-of-Truth Model

The platform follows a clear data ownership model:

```text
GitHub = source code and safe configuration
Jenkins workspace = temporary execution area
AWS S3 = durable source of truth for generated artifacts
/var/lib/pfe-dashboard = local dashboard cache
Grafana = live Prometheus metric visualization
Flask dashboard = latest decision and report visualization
```

Generated reports, ML outputs, remediation reports and metric snapshots are not committed to GitHub. They are generated at runtime by Jenkins and stored in AWS S3.

The local dashboard cache is only a synchronized copy of the latest S3 outputs:

```text
/var/lib/pfe-dashboard/
├── outputs/
├── metrics/latest/
├── analyzer/latest/
├── ml/latest/
├── ml/data/
├── ml/models/
└── remediation/latest/
```

---

## 4. Jenkins Automation Pipeline

Jenkins is the central automation component of the platform.

The final Jenkins pipeline performs the following sequence:

```text
01  Clean Jenkins workspace
02  Checkout repository
03  Set runtime build paths
04  Show execution environment
05  Detect changed areas
06  Safety guard for GNS3 apply modes
07  Safety guard for GNS3 host requirement
08  Safety guard for safe remediation apply mode
09  Prepare shared dashboard and ML folders
10  Prepare Ansible output directory
11  Check GNS3 host access
12  Sync repository on GNS3 host
13  Build Docker images on GNS3 host
14  Push Docker images to Docker Hub
15  Check GNS3 host and node status
16  Bootstrap GNS3 persistent node configurations
17  Ansible inventory check
18  Ansible syntax check
19  Run local topology validation gate
20  Generate HTML summary report
21  Validate generated dashboard reports
22  Upload validation artifacts to AWS S3
23  Apply Prometheus target configuration
24  Export Prometheus metrics snapshot
25  Upload Prometheus metrics snapshot to AWS S3
26  Run rule-based cloud analyzer
27  Upload rule-based analyzer results to AWS S3
28  Prepare ML runtime
29  Collect historical Prometheus metrics for ML
30  Build ML feature dataset
31  Train or reuse Isolation Forest model
32  Run ML anomaly prediction
33  Upload ML dataset, model and decision to AWS S3
34  Merge rule-based and ML decisions
35  Upload final hybrid decision to AWS S3
36  Run safe remediation plan
37  Apply safe remediation, only if explicitly confirmed
38  Upload remediation results to AWS S3
39  Sync dashboard cache from AWS S3
40  Show generated reports
41  Set Jenkins build description
```

This pipeline provides a full operational workflow, from infrastructure validation to anomaly detection and controlled remediation.

---

## 5. Validation Layer

The validation layer is based on Ansible.

Ansible validates the local GNS3 infrastructure by checking:

* FRRouting router configuration and state
* OVS switch configuration and state
* DMZ services
* End-to-end connectivity
* Security validation
* Inventory consistency
* OOB management readiness

The generated validation reports are stored locally during the Jenkins build under:

```text
ansible/outputs/
```

Then Jenkins uploads them to AWS S3:

```text
validation-artifacts/<build-label>/
latest/validation-artifacts/
```

These reports are also synchronized to:

```text
/var/lib/pfe-dashboard/outputs/
```

The Flask dashboard reads this folder to display validation status and report previews.

---

## 6. Monitoring Layer

The monitoring layer is based on Prometheus, Node Exporter, Blackbox Exporter and SNMP Exporter.

Prometheus collects metrics from:

* DevOps host
* Web service
* DNS service
* FRRouting routers
* OVS switches
* SNMP-monitored network interfaces

The platform uses these metrics for two purposes:

1. Live visualization in Grafana.
2. Runtime analysis by the anomaly detection system.

Jenkins exports a Prometheus snapshot during each pipeline run and stores it locally under:

```text
monitoring/outputs/latest/
```

Then it uploads the snapshot to AWS S3:

```text
metrics-snapshots/<build-label>/
latest/metrics/
```

The latest metrics are synchronized to:

```text
/var/lib/pfe-dashboard/metrics/latest/
```

---

## 7. Grafana Dashboards

Grafana is used to visualize live monitoring evidence.

The Grafana dashboards are provisioned from:

```text
monitoring/grafana/dashboards/
```

The main dashboards are:

```text
PFE - Local Monitoring Overview
PFE - Network Devices & Interfaces
PFE - Anomaly Detection & Evidence
```

The anomaly detection dashboard does not read Jenkins JSON files directly. Instead, it visualizes live Prometheus metrics that explain why the anomaly detection system may react.

It shows:

* Estimated anomaly risk
* ML-style metric signal proxy
* Failed HTTP/TCP/DNS probes
* SNMP devices down
* Admin-up interfaces that are operationally down
* Interface error and discard rates
* CPU, memory and disk pressure
* Network traffic evolution
* Service latency degradation
* Target reachability

Grafana is used for metric evidence, while the Flask dashboard is used for final analyzer, ML and remediation decisions.

---

## 8. Rule-Based Analyzer

The rule-based analyzer is the deterministic anomaly detection layer.

It consumes:

```text
ansible/outputs/
monitoring/outputs/latest/
```

and produces:

```text
summary.json
decision.json
analysis-report.txt
```

The rule-based analyzer checks explainable conditions such as:

* Failed validation reports
* Missing reports
* Unreachable Prometheus targets
* Failed Blackbox probes
* SNMP devices down
* Interfaces operationally down while administratively enabled
* Interface errors or discards
* Host CPU, memory or disk saturation

The output is stored in:

```text
cloud/analyzer/outputs/<build-label>/
```

Then uploaded to:

```text
processed-summaries/<build-label>/
anomaly-results/<build-label>/
latest/analyzer/
```

The rule-based analyzer remains the safety reference for remediation. If it does not confirm an anomaly, the platform does not allow infrastructure-changing remediation.

---

## 9. ML Anomaly Detection Layer

The ML layer extends the rule-based analyzer with statistical anomaly detection.

The ML model used is:

```text
Isolation Forest
```

It is an unsupervised model, which means it can detect unusual behavior without requiring labeled attack data.

The ML pipeline performs the following steps:

```text
Prometheus query_range
      ↓
Raw historical metric windows
      ↓
Feature dataset CSV
      ↓
Isolation Forest model
      ↓
ML decision
```

The ML collector reads historical Prometheus metrics and writes raw metric files under:

```text
cloud/analyzer/ml/data/raw/latest/
```

The feature builder creates:

```text
cloud/analyzer/ml/data/features/latest_features.csv
```

The model is stored persistently under:

```text
/var/lib/pfe-dashboard/ml/models/
```

Important model files:

```text
isolation_forest.joblib
feature_columns.json
training_metadata.json
```

The ML decision output is stored under:

```text
cloud/analyzer/ml/outputs/
```

Typical ML output files:

```text
ml-decision.json
ml-scores.csv
```

Jenkins uploads ML artifacts to S3:

```text
ml-datasets/<build-label>/
ml-results/<build-label>/
ml-models/latest/
latest/ml-dataset/
latest/ml/
```

The ML layer is advisory. It can detect weak or suspicious signals, but it cannot directly trigger infrastructure-changing remediation.

---

## 10. Hybrid Final Decision

After the rule-based analyzer and ML analyzer finish, Jenkins runs the decision merger.

The merger consumes:

```text
cloud/analyzer/outputs/<build-label>/decision.json
cloud/analyzer/ml/outputs/ml-decision.json
```

and produces:

```text
final-decision.json
final-decision-report.txt
```

The final decision includes:

* Classification
* Final status
* Final severity
* Final risk score
* Confidence
* Recommended action
* Whether the rule analyzer detected an anomaly
* Whether ML detected an anomaly
* Whether ML produced only a suspicious signal
* Whether remediation is allowed
* The reason for the decision

The safety policy is:

```text
Rule normal + ML weak signal = human review
Rule anomaly only = explainable anomaly
Rule anomaly + ML anomaly = strongest confirmed case
ML-only anomaly = advisory, no automatic infrastructure change
```

This design avoids blindly trusting the ML model.

---

## 11. Safe Remediation Layer

The remediation layer consumes the final hybrid decision.

It reads:

```text
cloud/analyzer/outputs/<build-label>/final-decision.json
```

and produces:

```text
remediation-plan.json
remediation-report.txt
```

The remediation system is controlled by an allowlist:

```text
cloud/analyzer/remediation/safe_actions.json
```

The runner is:

```text
cloud/analyzer/remediation/run_safe_remediation.py
```

Supported modes:

```text
plan
apply
```

Plan mode is the default. It does not execute commands. It only explains what action would be selected.

Apply mode requires explicit confirmation:

```text
REMEDIATION_MODE=apply
CONFIRM_APPLY=true
```

Infrastructure-changing actions are only allowed if:

```text
remediation_allowed = true
```

The remediation layer supports safe actions such as:

```text
no_action
collect_host_diagnostics
collect_network_diagnostics
refresh_monitoring_snapshot
run_validation_gate
restart_dmz_web
restart_dmz_dns
restart_dmz_services
```

Diagnostic actions do not modify infrastructure. Restart actions are restricted and only applied when the final decision allows remediation.

Jenkins uploads remediation outputs to:

```text
remediation-results/<build-label>/
anomaly-results/<build-label>/remediation/
latest/remediation/
```

The latest remediation output is synchronized to:

```text
/var/lib/pfe-dashboard/remediation/latest/
```

---

## 12. AWS S3 Artifact Structure

AWS S3 is the durable source of truth for generated platform outputs.

The bucket stores both historical archives and latest dashboard-ready files.

Historical folders:

```text
validation-artifacts/<build-label>/
metrics-snapshots/<build-label>/
processed-summaries/<build-label>/
anomaly-results/<build-label>/
ml-datasets/<build-label>/
ml-results/<build-label>/
remediation-results/<build-label>/
```

Latest folders:

```text
latest/validation-artifacts/
latest/metrics/
latest/analyzer/
latest/ml/
latest/ml-dataset/
latest/remediation/
```

The difference is:

```text
<folder>/<build-label>/ = historical archive for one Jenkins build
latest/<folder>/        = latest state used by the dashboard
```

This allows both traceability and real-time visualization.

---

## 13. Flask Dashboard

The Flask dashboard is the local web interface used to present the latest platform state.

It reads from:

```text
/var/lib/pfe-dashboard/
```

The dashboard displays:

* Validation report status
* Rule-based analyzer decision
* Prometheus monitoring snapshot summary
* ML anomaly decision
* Final hybrid decision
* Safe remediation plan/apply output
* Infrastructure nodes
* Validated services

Recommended dashboard routes:

```text
/                 Overview
/analyzer         Rule analyzer and final hybrid decision
/ml               ML Isolation Forest decision
/remediation      Safe remediation plan/apply output
/monitoring       Prometheus metrics snapshot
/validation       Validation reports
/infrastructure   FRR and OVS infrastructure nodes
/services         Validated services
```

The dashboard is a visualization layer only. It does not configure the network and does not execute remediation commands. All actions are executed through Jenkins and controlled scripts.

---

## 14. Example Build Result

An example Jenkins build produced the following result:

```text
Rule analyzer:
  status = normal
  risk_score = 8/100
  severity = low
  recommended_action = no_action

ML analyzer:
  status = weak_signal
  risk_score = 49/100
  severity = low
  prediction = normal latest sample, but suspicious window

Final decision:
  classification = ml_suspicious_signal
  final_status = anomalous
  final_severity = medium
  final_risk_score = 49/100
  confidence = low
  remediation_allowed = false
  remediation_mode = human_review_required
```

Interpretation:

The infrastructure was not considered broken by the deterministic analyzer. The ML model detected unusual behavior compared to its learned baseline, mainly around CPU and traffic metrics. Because the anomaly was ML-only and not confirmed by the rule-based analyzer, the platform blocked automatic infrastructure remediation and required human review.

The remediation runner selected:

```text
collect_host_diagnostics
```

but only in plan mode. No commands were executed.

This behavior proves the safety design of the platform.

---

## 15. Human Review Scenario

When the platform produces an ML-only suspicious signal, a human operator should not immediately restart services or modify the network.

The review process is:

```text
1. Open final-decision.json
2. Check whether rule_anomalous is true or false
3. Check ML suspicious features
4. Review Grafana metric evidence
5. Run diagnostic remediation in plan/apply mode if needed
6. Decide whether the signal is normal activity or a real issue
7. Approve a predefined safe action only if the issue is confirmed
```

If the signal is caused by normal Jenkins activity, S3 upload, ML training, or temporary load, the operator closes the event as:

```text
No corrective action
Monitor next window
```

If a real service or network issue is confirmed, the operator can approve a safe predefined remediation action through Jenkins.

---

## 16. Security and Safety Controls

The platform includes several safety controls:

* Jenkins is not exposed directly to the Internet.
* GitHub Actions self-hosted runner only triggers Jenkins locally.
* Jenkins uses credentials instead of hardcoded secrets.
* Docker builds are delegated to the GNS3 host through SSH.
* S3 bucket name and AWS credentials are passed through Jenkins parameters/credentials.
* ML cannot execute arbitrary commands.
* Remediation actions are allowlisted.
* Apply mode requires explicit confirmation.
* Infrastructure-changing remediation requires rule-based confirmation.
* Generated outputs are stored in S3, not committed to GitHub.
* The dashboard is read-only.

These controls make the project closer to an enterprise automation workflow while remaining safe for a student lab.

---

## 17. Git Tracking Policy

GitHub should contain:

```text
Jenkinsfile
Ansible playbooks
Monitoring configuration
Grafana dashboard JSON files
Cloud analyzer scripts
ML analyzer scripts
Safe remediation scripts
Flask dashboard source code
Documentation
Example configuration files
```

GitHub should not contain:

```text
AWS credentials
SSH private keys
.env files
Terraform state files
Generated Ansible reports
Generated Prometheus snapshots
Generated ML datasets
Generated ML models
Generated analyzer outputs
Generated remediation outputs
```

Recommended generated-output locations:

```text
AWS S3                       = durable artifact storage
/var/lib/pfe-dashboard       = latest dashboard cache
Jenkins workspace            = temporary execution area
```

---

## 18. Repository Cleanup Checklist

Before closing this phase, verify that the following files are committed:

```text
Jenkinsfile

cloud/analyzer/ml/README.md
cloud/analyzer/ml/features.json
cloud/analyzer/ml/collect_prometheus_window.py
cloud/analyzer/ml/build_feature_dataset.py
cloud/analyzer/ml/train_isolation_forest.py
cloud/analyzer/ml/predict_anomaly.py
cloud/analyzer/ml/merge_ml_decision.py
cloud/analyzer/ml/requirements.txt

cloud/analyzer/remediation/README.md
cloud/analyzer/remediation/safe_actions.json
cloud/analyzer/remediation/run_safe_remediation.py

cloud/scripts/sync-dashboard-cache-from-s3.sh
cloud/scripts/upload-prometheus-snapshot-s3.sh
cloud/scripts/upload-validation-artifacts-s3.sh

dashboard/config.py
dashboard/extensions.py
dashboard/dto/dashboard_dto.py
dashboard/service/dashboard_service.py
dashboard/service/runtime_artifact_service.py
dashboard/web/dashboard_controller.py
dashboard/web/api_controller.py
dashboard/templates/base.html
dashboard/templates/pages/overview.html
dashboard/templates/pages/analyzer.html
dashboard/templates/pages/ml.html
dashboard/templates/pages/remediation.html
dashboard/templates/pages/monitoring.html
dashboard/templates/pages/validation.html
dashboard/templates/pages/infrastructure.html
dashboard/templates/pages/services.html
dashboard/static/style.css
dashboard/README.md

monitoring/grafana/dashboards/pfe-anomaly-detection-demo.json
monitoring/grafana/dashboards/pfe-local-monitoring-overview.json
monitoring/grafana/dashboards/pfe-network-devices-interfaces.json
monitoring/grafana/provisioning/dashboards/pfe-dashboards.yml
monitoring/grafana/provisioning/datasources/prometheus.yml
```

Files that especially need to be checked because they were added late:

```text
dashboard/templates/pages/ml.html
dashboard/templates/pages/remediation.html
dashboard/README.md
cloud/scripts/README.md
monitoring/grafana/dashboards/pfe-anomaly-detection-demo.json
```

---

## 19. Final Summary

The final platform demonstrates a complete DevOps, Cloud and AI-based network automation workflow.

It validates the local GNS3 topology using Ansible, exports Prometheus monitoring evidence, stores generated artifacts in AWS S3, applies a rule-based anomaly analyzer, extends detection with an Isolation Forest ML model, merges both decisions into a controlled final decision, and prepares safe remediation actions through Jenkins.

The project remains safe because remediation is not blindly automated. ML is treated as an advisory signal, while the rule-based analyzer remains the deterministic safety layer. Infrastructure-changing actions require both an explainable anomaly and explicit confirmation.

This makes the platform suitable for a master-level PFE because it combines:

```text
Network virtualization
DevOps automation
Cloud artifact storage
Monitoring and observability
Machine-learning anomaly detection
Controlled remediation
Dashboard visualization
Security and safety controls
```
