# ML Anomaly Detection Layer

This folder contains the machine-learning anomaly detection layer for the PFE network automation platform.

The ML layer extends the existing rule-based analyzer. It does **not** replace it.

The goal is to use historical Prometheus metrics to detect abnormal infrastructure behavior, then merge the ML result with the deterministic rule-based analyzer decision.

## Purpose

The platform already collects metrics from the local GNS3/DevOps environment using Prometheus.

The ML layer transforms those metrics into a tabular dataset and trains an unsupervised anomaly detection model.

Current model:

```text
Isolation Forest
```

The model is used to detect unusual behavior in infrastructure metrics such as:

```text
Service probe failures
Service latency degradation
SNMP device failures
Unexpected interface-down events
Interface error/discard rates
Host CPU, memory and disk saturation
Network traffic changes
```

## Design Principle

The rule-based analyzer remains the deterministic safety layer.

The ML model is advisory.

```text
Rule-based analyzer = explainable deterministic decision
ML Isolation Forest = statistical anomaly signal
Decision merger = final controlled decision
```

Automated remediation is allowed only when the rule-based analyzer confirms an explainable anomaly.

ML-only anomalies require review.

## Architecture

```text
Prometheus
    ↓
Historical metrics collector
    ↓
Feature dataset builder
    ↓
Isolation Forest model
    ↓
ML decision
    ↓
Rule-based + ML decision merger
    ↓
Final decision
```

Full flow:

```text
Prometheus query_range
    ↓
cloud/analyzer/ml/data/raw/
    ↓
cloud/analyzer/ml/data/features/latest_features.csv
    ↓
cloud/analyzer/ml/models/isolation_forest.joblib
    ↓
cloud/analyzer/ml/outputs/ml-decision.json
    ↓
cloud/analyzer/outputs/final-decision.json
```

## Directory Structure

```text
cloud/analyzer/ml/
├── README.md
├── requirements.txt
├── features.json
├── collect_prometheus_window.py
├── build_feature_dataset.py
├── train_isolation_forest.py
├── predict_anomaly.py
├── merge_ml_decision.py
├── data/
│   ├── raw/
│   └── features/
├── models/
└── outputs/
```

## Files

### `features.json`

Defines the Prometheus queries used to generate ML features.

The feature scope mirrors the metrics already collected by the monitoring baseline and S3 metrics snapshot export.

Feature groups include:

```text
Prometheus target health
Blackbox Web/DNS probe success
Blackbox Web/DNS probe latency
Node Exporter CPU/load/memory/disk metrics
SNMP device reachability
SNMP interface status
SNMP traffic rates
SNMP error/discard rates
SNMP capacity/context features
```

### `collect_prometheus_window.py`

Collects historical Prometheus metric windows using Prometheus `query_range`.

It creates raw JSON files under:

```text
cloud/analyzer/ml/data/raw/latest/
```

### `build_feature_dataset.py`

Converts the raw Prometheus JSON files into a CSV dataset.

Output:

```text
cloud/analyzer/ml/data/features/latest_features.csv
```

Each row represents one timestamp.

Each column represents one ML feature.

### `train_isolation_forest.py`

Trains an Isolation Forest model from the feature dataset.

Generated files:

```text
cloud/analyzer/ml/models/isolation_forest.joblib
cloud/analyzer/ml/models/feature_columns.json
cloud/analyzer/ml/models/training_metadata.json
cloud/analyzer/ml/outputs/training_scores.csv
```

### `predict_anomaly.py`

Scores a feature dataset using the trained Isolation Forest model.

Generated files:

```text
cloud/analyzer/ml/outputs/ml-decision.json
cloud/analyzer/ml/outputs/ml-scores.csv
```

### `merge_ml_decision.py`

Merges the rule-based analyzer decision with the ML decision.

Inputs:

```text
cloud/analyzer/outputs/decision.json
cloud/analyzer/ml/outputs/ml-decision.json
```

Outputs:

```text
cloud/analyzer/outputs/final-decision.json
cloud/analyzer/outputs/final-decision-report.txt
```

## Environment Setup

Ubuntu 24.04 protects the system Python environment, so Python dependencies should be installed inside a virtual environment.

From the repository root:

```bash
cd ~/pfe-repo

sudo apt-get install -y python3-venv python3-full

python3 -m venv .venv
source .venv/bin/activate

python -m pip install --upgrade pip
python -m pip install -r cloud/analyzer/ml/requirements.txt
```

Verify dependencies:

```bash
python -c "import pandas, numpy, sklearn, joblib; print('ML dependencies OK')"
```

Expected Python path:

```text
/home/wiam/pfe-repo/.venv/bin/python
```

## Requirements

```text
pandas
numpy
scikit-learn
joblib
```

These are stored in:

```text
cloud/analyzer/ml/requirements.txt
```

## Step 1: Collect Historical Prometheus Data

Make sure Prometheus is running:

```bash
curl -fsS http://localhost:9090/-/ready && echo "Prometheus ready"
```

Collect the last 60 minutes of metrics:

```bash
python cloud/analyzer/ml/collect_prometheus_window.py \
  --prometheus-url http://localhost:9090 \
  --duration-minutes 60 \
  --step 60s
```

This creates raw Prometheus JSON files under:

```text
cloud/analyzer/ml/data/raw/latest/
```

Check the output:

```bash
ls -lh cloud/analyzer/ml/data/raw/latest | head

cat cloud/analyzer/ml/data/raw/latest/manifest.json | python3 -m json.tool | head -n 80
```

## Step 2: Build the Feature Dataset

Build the CSV dataset:

```bash
python cloud/analyzer/ml/build_feature_dataset.py
```

Output:

```text
cloud/analyzer/ml/data/features/latest_features.csv
```

Preview the dataset:

```bash
head -n 5 cloud/analyzer/ml/data/features/latest_features.csv
wc -l cloud/analyzer/ml/data/features/latest_features.csv
```

For a 60-minute window with a 60-second step, the expected result is around:

```text
61 lines = 1 header + around 60 metric rows
```

## Step 3: Validate Dataset Quality

Run:

```bash
python3 - <<'PY'
import csv
from pathlib import Path

path = Path("cloud/analyzer/ml/data/features/latest_features.csv")

with path.open() as f:
    reader = csv.DictReader(f)
    rows = list(reader)

print("Rows:", len(rows))
print("Features:", len(reader.fieldnames) - 1)
print("Columns:")
for col in reader.fieldnames:
    print(" -", col)

if rows:
    print("\nFirst row:")
    print(rows[0])

    print("\nLast row:")
    print(rows[-1])
PY
```

A healthy baseline should generally show:

```text
service_probe_success_ratio ≈ 1
service_probe_failures = 0
snmp_devices_down = 0
admin_up_interfaces_down = 0
interface_error_rate = 0 or very low
memory/disk values within normal range
```

## Step 4: Train the Isolation Forest Model

Train the model using the latest feature dataset:

```bash
python cloud/analyzer/ml/train_isolation_forest.py \
  --input-csv cloud/analyzer/ml/data/features/latest_features.csv \
  --contamination 0.05
```

The `contamination` value represents the expected ratio of anomalies in the training data.

For the first test:

```text
0.05 = around 5% of rows may be treated as outliers
```

Generated files:

```text
cloud/analyzer/ml/models/isolation_forest.joblib
cloud/analyzer/ml/models/feature_columns.json
cloud/analyzer/ml/models/training_metadata.json
cloud/analyzer/ml/outputs/training_scores.csv
```

Check the metadata:

```bash
cat cloud/analyzer/ml/models/training_metadata.json | python3 -m json.tool | head -n 80
```

Check training scores:

```bash
head -n 10 cloud/analyzer/ml/outputs/training_scores.csv
```

## Step 5: Predict ML Anomaly Status

Run prediction:

```bash
python cloud/analyzer/ml/predict_anomaly.py \
  --input-csv cloud/analyzer/ml/data/features/latest_features.csv
```

Generated files:

```text
cloud/analyzer/ml/outputs/ml-decision.json
cloud/analyzer/ml/outputs/ml-scores.csv
```

View the ML decision:

```bash
cat cloud/analyzer/ml/outputs/ml-decision.json | python3 -m json.tool
```

View the latest scores:

```bash
tail -n 10 cloud/analyzer/ml/outputs/ml-scores.csv
```

Example healthy output:

```json
{
  "engine": "ml_isolation_forest",
  "ml_available": true,
  "ml_status": "normal",
  "severity": "low",
  "ml_risk_score": 0,
  "latest_prediction": 1,
  "recommended_action": "no_action"
}
```

Isolation Forest prediction meaning:

```text
1  = normal / inlier
-1 = anomalous / outlier
```

## Step 6: Run the Rule-Based Analyzer

Before merging decisions, generate the current rule-based decision.

First export a Prometheus snapshot:

```bash
./monitoring/scripts/export-prometheus-snapshot.sh
```

Then run the existing analyzer:

```bash
python cloud/analyzer/analyze_validation_artifacts.py \
  --input-dir /var/lib/pfe-dashboard/outputs \
  --metrics-dir monitoring/outputs/latest \
  --output-dir cloud/analyzer/outputs \
  --build-label local-ml-merge-test
```

Check the rule-based decision:

```bash
cat cloud/analyzer/outputs/decision.json | python3 -m json.tool
```

## Step 7: Merge Rule-Based and ML Decisions

Run:

```bash
python cloud/analyzer/ml/merge_ml_decision.py \
  --rule-decision cloud/analyzer/outputs/decision.json \
  --ml-decision cloud/analyzer/ml/outputs/ml-decision.json \
  --output-dir cloud/analyzer/outputs
```

Generated files:

```text
cloud/analyzer/outputs/final-decision.json
cloud/analyzer/outputs/final-decision-report.txt
```

View the final decision:

```bash
cat cloud/analyzer/outputs/final-decision.json | python3 -m json.tool
```

View the final text report:

```bash
cat cloud/analyzer/outputs/final-decision-report.txt
```

Example healthy result:

```text
Classification: normal
Status: normal
Severity: low
Risk score: 8/100
Recommended action: no_action
Remediation allowed: False
```

## Decision Merge Logic

The final merger combines the deterministic rule-based result and the ML result.

```text
Rule normal + ML normal        → normal
Rule anomalous + ML normal     → rule_based_anomaly
Rule normal + ML anomalous     → ml_only_anomaly
Rule anomalous + ML anomalous  → confirmed_anomaly
Rule normal + ML suspicious    → ml_suspicious_signal
```

## Safety Policy

The ML model is advisory.

```text
ML-only anomaly = review required
Rule-based anomaly = explainable anomaly
Rule + ML anomaly = confirmed anomaly
```

Automated remediation is allowed only when the rule-based analyzer confirms the anomaly.

This prevents the platform from allowing a statistical ML signal alone to modify infrastructure.

## Complete Local ML Workflow

From the repository root:

```bash
cd ~/pfe-repo
source .venv/bin/activate

python cloud/analyzer/ml/collect_prometheus_window.py \
  --prometheus-url http://localhost:9090 \
  --duration-minutes 60 \
  --step 60s

python cloud/analyzer/ml/build_feature_dataset.py

python cloud/analyzer/ml/predict_anomaly.py \
  --input-csv cloud/analyzer/ml/data/features/latest_features.csv

./monitoring/scripts/export-prometheus-snapshot.sh

python cloud/analyzer/analyze_validation_artifacts.py \
  --input-dir /var/lib/pfe-dashboard/outputs \
  --metrics-dir monitoring/outputs/latest \
  --output-dir cloud/analyzer/outputs \
  --build-label local-ml-merge-test

python cloud/analyzer/ml/merge_ml_decision.py \
  --rule-decision cloud/analyzer/outputs/decision.json \
  --ml-decision cloud/analyzer/ml/outputs/ml-decision.json \
  --output-dir cloud/analyzer/outputs
```

Check final output:

```bash
cat cloud/analyzer/outputs/final-decision.json | python3 -m json.tool
cat cloud/analyzer/outputs/final-decision-report.txt
```

## Named Baseline Collection

For training a cleaner normal baseline, collect a named dataset:

```bash
RUN_ID="normal-baseline-$(date +%Y%m%d-%H%M%S)"

python cloud/analyzer/ml/collect_prometheus_window.py \
  --prometheus-url http://localhost:9090 \
  --duration-minutes 120 \
  --step 60s \
  --output-dir "cloud/analyzer/ml/data/raw/$RUN_ID"

python cloud/analyzer/ml/build_feature_dataset.py \
  --raw-dir "cloud/analyzer/ml/data/raw/$RUN_ID" \
  --output-csv "cloud/analyzer/ml/data/features/${RUN_ID}.csv"

echo "Created dataset: cloud/analyzer/ml/data/features/${RUN_ID}.csv"
```

Train using that baseline:

```bash
python cloud/analyzer/ml/train_isolation_forest.py \
  --input-csv "cloud/analyzer/ml/data/features/${RUN_ID}.csv" \
  --contamination 0.05
```

## Recommended Training Data

For a first smoke test:

```text
30–60 minutes of healthy metrics
```

For a better baseline:

```text
2–4 hours of healthy metrics
```

For the best result:

```text
Multiple normal sessions collected under different normal lab conditions
```

The training dataset should represent mostly healthy infrastructure behavior.

## Generated Outputs

### ML decision

```text
cloud/analyzer/ml/outputs/ml-decision.json
```

Contains:

```text
ml_status
severity
ml_risk_score
latest_prediction
latest_decision_score
latest_sample_score
outlier_ratio
top_unusual_features
recommended_action
```

### ML scores

```text
cloud/analyzer/ml/outputs/ml-scores.csv
```

Contains one score per timestamp.

### Final decision

```text
cloud/analyzer/outputs/final-decision.json
```

Contains the merged rule-based and ML decision.

### Final report

```text
cloud/analyzer/outputs/final-decision-report.txt
```

Human-readable report for validation, Jenkins archiving and dashboard display.

## Git Tracking Policy

Generated data, models and outputs should not be committed.

Do not commit:

```text
cloud/analyzer/ml/data/raw/
cloud/analyzer/ml/data/features/
cloud/analyzer/ml/models/
cloud/analyzer/ml/outputs/
cloud/analyzer/outputs/
.venv/
```

Commit only:

```text
cloud/analyzer/ml/README.md
cloud/analyzer/ml/requirements.txt
cloud/analyzer/ml/features.json
cloud/analyzer/ml/collect_prometheus_window.py
cloud/analyzer/ml/build_feature_dataset.py
cloud/analyzer/ml/train_isolation_forest.py
cloud/analyzer/ml/predict_anomaly.py
cloud/analyzer/ml/merge_ml_decision.py
```

Recommended `.gitignore` entries:

```text
.venv/

# ML anomaly detection generated data
cloud/analyzer/ml/data/raw/*
cloud/analyzer/ml/data/features/*
cloud/analyzer/ml/models/*
cloud/analyzer/ml/outputs/*
!cloud/analyzer/ml/data/.gitkeep
!cloud/analyzer/ml/models/.gitkeep
!cloud/analyzer/ml/outputs/.gitkeep

# Analyzer generated outputs
cloud/analyzer/outputs/*
```

## Troubleshooting

### Ubuntu externally-managed Python error

If pip shows:

```text
error: externally-managed-environment
```

Use a virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r cloud/analyzer/ml/requirements.txt
```

Do not use `--break-system-packages`.

### Empty dataset

If `latest_features.csv` is empty, check Prometheus:

```bash
curl -fsS http://localhost:9090/-/ready
curl -s 'http://localhost:9090/api/v1/query?query=up' | python3 -m json.tool | head -n 60
```

Also check that the selected time window has data:

```bash
python cloud/analyzer/ml/collect_prometheus_window.py \
  --prometheus-url http://localhost:9090 \
  --duration-minutes 15 \
  --step 60s
```

### Missing SNMP interface features

Check SNMP labels:

```bash
curl -s 'http://localhost:9090/api/v1/query?query=ifOperStatus%7Bjob%3D%22snmp-network-devices%22%7D' \
  | python3 -m json.tool | head -n 80
```

If the label is `ifName` instead of `ifDescr`, update `features.json` filters accordingly.

### Unrealistic interface utilization

If `estimated_max_interface_utilization_percent` is extremely high, the likely cause is a mismatch between traffic counters and interface speed values.

This does not block the pipeline, but the feature can be reviewed, fixed or excluded later if it affects the model.

### ML result is normal on training data

This is expected when predicting on the same healthy data used for training.

Some rows may still be marked as outliers because Isolation Forest uses the configured contamination ratio.

Example:

```text
contamination = 0.05
61 rows
≈ 3 rows may be treated as outliers
```

## Future Jenkins Integration

The future Jenkins flow should include these stages:

```text
Collect Prometheus historical window
Build ML feature dataset
Run ML anomaly prediction
Run rule-based analyzer
Merge rule + ML decision
Archive final-decision.json and final-decision-report.txt
Optionally trigger controlled remediation
```

The Jenkins pipeline should consume:

```text
cloud/analyzer/outputs/final-decision.json
```

and only trigger remediation when:

```text
remediation_allowed = true
```

## Future Attack/Anomaly Demonstrations

The ML layer can be tested with controlled scenarios:

```text
Stop Web container
Stop DNS container
Break or stop an SNMP target
Disable an active interface
Generate latency degradation
Generate traffic or interface errors
Increase host resource usage
```

Expected demonstration flow:

```text
Grafana shows metric change
ML anomaly score changes
Rule-based analyzer detects explainable issue
Final decision merges both results
Jenkins can prepare or trigger controlled remediation
```

## Current Status

Implemented:

```text
Historical Prometheus metric collection
Feature dataset generation
Isolation Forest model training
ML anomaly prediction
Rule-based + ML decision merger
Final decision JSON/report generation
```

Validated healthy result:

```text
Classification: normal
Final status: normal
Final risk score: 8/100
Recommended action: no_action
Remediation allowed: False
```
