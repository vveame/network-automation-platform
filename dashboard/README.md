# Flask Validation Dashboard

This dashboard provides a visual view of the latest infrastructure validation state.

## Purpose

The dashboard displays the current state of the local GNS3/on-premises infrastructure validation and the latest cloud analyzer decision.

It is part of the intelligent network automation platform and provides a readable interface for Jenkins/Ansible validation outputs.

## Data Source Model

The dashboard is cloud-backed.

AWS S3 is the source of truth for generated validation and analyzer outputs.

The dashboard reads from a local synchronized cache:

```text
/var/lib/pfe-dashboard/
```

This avoids depending on temporary Jenkins workspace files or generated outputs inside the Git repository.

## Local Cache Structure

```text
/var/lib/pfe-dashboard/
├── outputs/
│   ├── validation-summary.txt
│   ├── security-validation.txt
│   ├── dmz-services.txt
│   └── other validation reports
└── analyzer/
    └── latest/
        ├── decision.json
        ├── summary.json
        └── analysis-report.txt
```

## Dashboard Features

The dashboard displays:

* global validation status
* validation report totals
* validation domains
* infrastructure node status
* validated DMZ services
* readable report previews
* latest cloud analyzer decision

## Cloud Analyzer Decision

The dashboard reads the latest anomaly decision from:

```text
/var/lib/pfe-dashboard/analyzer/latest/decision.json
```

The analyzer decision includes:

* anomaly status
* risk score
* severity
* recommended action
* build label
* failed reports
* warning reports

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
http://<devops-vm-ip>:5050
```

## Syncing Dashboard Cache from S3

The cache can be synchronized through Jenkins. It runs this synchronization automatically after uploading validation artifacts and analyzer outputs to S3.

## Notes

Generated validation reports are not committed to GitHub.

The GitHub repository stores the dashboard code only.

AWS S3 stores the durable generated outputs, while /var/lib/pfe-dashboard/ acts as a local dashboard cache.
