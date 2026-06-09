# PFE Flask Dashboard

## 1. Role of the Dashboard

The Flask dashboard is the local visualization layer of the intelligent network automation platform.

It displays the latest state of the platform after each Jenkins pipeline execution:

```text
Validation reports
Prometheus metrics snapshot
Rule-based analyzer decision
ML anomaly detection decision
Final hybrid decision
Safe remediation plan/apply output
Infrastructure status
Service status
```

The dashboard is read-only. It does not execute remediation actions and does not modify the network.

All operational actions are performed by Jenkins and controlled scripts.

---

## 2. Source of Data

The dashboard reads synchronized runtime artifacts from:

```text
/var/lib/pfe-dashboard/
```

This folder is only a local cache.

The source of truth remains AWS S3.

```text
AWS S3 = durable artifact storage
/var/lib/pfe-dashboard = local dashboard cache
Jenkins workspace = temporary execution area
GitHub = source code only
```

---

## 3. Dashboard Cache Structure

The expected local cache structure is:

```text
/var/lib/pfe-dashboard/
├── outputs/
├── metrics/
│   └── latest/
├── analyzer/
│   └── latest/
├── ml/
│   ├── latest/
│   ├── data/
│   ├── models/
│   └── outputs/
└── remediation/
    └── latest/
```

### `outputs/`

Contains the latest Ansible validation reports.

Example files:

```text
validation-summary.txt
index.html
core-frr-1-frr.txt
edge-router-frr.txt
dmz-services.txt
security-validation.txt
end-to-end-validation.txt
```

### `metrics/latest/`

Contains the latest Prometheus snapshot exported by Jenkins.

Example files:

```text
up.json
blackbox_probe_success.json
node_cpu_usage_percent.json
snmp_up.json
snmp_if_oper_status.json
snmp_if_in_discards_rate_5m.json
```

### `analyzer/latest/`

Contains the latest rule-based and hybrid anomaly decision.

Example files:

```text
summary.json
decision.json
analysis-report.txt
final-decision.json
final-decision-report.txt
```

### `ml/latest/`

Contains the latest ML anomaly detection result.

Example files:

```text
ml-decision.json
ml-scores.csv
```

### `ml/data/`

Contains the latest ML feature dataset.

Example file:

```text
latest_features.csv
```

### `ml/models/`

Contains the persisted Isolation Forest model.

Example files:

```text
isolation_forest.joblib
feature_columns.json
training_metadata.json
```

### `remediation/latest/`

Contains the latest safe remediation output.

Example files:

```text
plan/remediation-plan.json
plan/remediation-report.txt
apply/remediation-plan.json
apply/remediation-report.txt
```

Apply files appear only when remediation is explicitly executed in apply mode.

---

## 4. Dashboard Routes

The dashboard exposes the following pages:

```text
/                 Overview
/analyzer         Rule-based analyzer and final hybrid decision
/ml               ML Isolation Forest decision
/remediation      Safe remediation plan/apply result
/monitoring       Prometheus metrics snapshot
/validation       Validation reports
/infrastructure   Infrastructure nodes
/services         Validated services
```

---

## 5. API Routes

The dashboard also exposes JSON API routes:

```text
/api/dashboard
/api/final-decision
/api/ml-decision
/api/remediation
/api/report/<filename>
/api/health
```

These routes are useful for debugging and for checking that the dashboard reads the correct synchronized files.

Example checks:

```bash
curl -s http://localhost:5050/api/final-decision | python3 -m json.tool
curl -s http://localhost:5050/api/ml-decision | python3 -m json.tool
curl -s http://localhost:5050/api/remediation | python3 -m json.tool
```

---

## 6. Rule-Based Analyzer Display

The analyzer page displays the deterministic rule-based decision.

It shows:

```text
Anomaly status
Risk score
Severity
Recommended action
Failed reports
Warning reports
Detection reasons
```

The rule-based analyzer remains the safety layer for remediation.

If the rule-based analyzer does not confirm an anomaly, the platform does not allow infrastructure-changing remediation.

---

## 7. ML Analyzer Display

The ML page displays the Isolation Forest anomaly detection result.

It shows:

```text
ML status
ML risk score
Latest prediction
Outlier ratio
Scored rows
Top unusual features
ML scores file
Feature dataset file
```

The ML model is advisory.

It can detect weak or suspicious behavior, but it cannot directly trigger infrastructure-changing remediation.

---

## 8. Final Hybrid Decision Display

The analyzer page also displays the final hybrid decision.

This decision is produced by merging:

```text
Rule-based analyzer decision
ML analyzer decision
```

The final decision includes:

```text
classification
final_status
final_severity
final_risk_score
confidence
recommended_action
remediation_allowed
remediation_mode
decision_reason
rule_anomalous
ml_anomalous
ml_suspicious
```

The final decision determines whether remediation is allowed.

---

## 9. Remediation Display

The remediation page displays the latest safe remediation output.

It shows:

```text
Mode
Selected action
Executed or not
Success or failure
Action type
Whether the action modifies infrastructure
Decision context
Report preview
```

Plan mode is safe and does not execute commands.

Apply mode appears only when the Jenkins build is explicitly launched with:

```text
REMEDIATION_MODE=apply
CONFIRM_APPLY=true
```

---

## 10. Running the Dashboard

From the repository root:

```bash
python3 dashboard/app.py
```

Open:

```text
http://10.200.0.10:5050/
```

---

## 11. Syncing Dashboard Cache from S3

The dashboard cache is synchronized from S3 using:

```bash
ARTIFACTS_BUCKET="<bucket-name>" \
AWS_REGION="eu-north-1" \
./cloud/scripts/sync-dashboard-cache-from-s3.sh
```

Jenkins also runs this sync automatically near the end of the pipeline.

---

## 12. Debugging

Check if files exist:

```bash
find /var/lib/pfe-dashboard -maxdepth 5 -type f | sort
```

Check final decision:

```bash
python3 -m json.tool /var/lib/pfe-dashboard/analyzer/latest/final-decision.json
```

Check ML decision:

```bash
python3 -m json.tool /var/lib/pfe-dashboard/ml/latest/ml-decision.json
```

Check remediation plan:

```bash
python3 -m json.tool /var/lib/pfe-dashboard/remediation/latest/plan/remediation-plan.json
```

Check dashboard API:

```bash
curl -s http://localhost:5050/api/health | python3 -m json.tool
curl -s http://localhost:5050/api/dashboard | python3 -m json.tool
```

---

## 13. Important Design Rule

Grafana and Flask do not have the same role.

```text
Grafana = live Prometheus metric evidence
Flask dashboard = latest decisions and generated reports
Jenkins = automation and remediation execution
S3 = durable source of truth
```

The Flask dashboard shows the final result of the automation chain, while Grafana helps explain the live metric behavior behind anomaly detection.
