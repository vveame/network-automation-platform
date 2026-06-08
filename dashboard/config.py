from pathlib import Path


class Config:
    APP_NAME = "PFE Validation Dashboard"

    HOST = "0.0.0.0"
    PORT = 5050
    DEBUG = True

    DASHBOARD_DIR = Path(__file__).resolve().parent
    REPO_ROOT = DASHBOARD_DIR.parent

    # Shared local dashboard cache.
    # S3 remains the source of truth.
    # /var/lib/pfe-dashboard is only the local visualization cache.
    DASHBOARD_CACHE_DIR = Path("/var/lib/pfe-dashboard")

    ANSIBLE_DIR = REPO_ROOT / "ansible"
    ANSIBLE_OUTPUTS_DIR = DASHBOARD_CACHE_DIR / "outputs"
    ANSIBLE_GROUP_VARS_FILE = ANSIBLE_DIR / "group_vars" / "all.yml"

    PROMETHEUS_METRICS_DIR = DASHBOARD_CACHE_DIR / "metrics" / "latest"

    ANALYZER_LATEST_DIR = DASHBOARD_CACHE_DIR / "analyzer" / "latest"
    CLOUD_ANALYZER_LATEST_DECISION_FILE = ANALYZER_LATEST_DIR / "decision.json"
    CLOUD_ANALYZER_FINAL_DECISION_FILE = ANALYZER_LATEST_DIR / "final-decision.json"
    CLOUD_ANALYZER_FINAL_REPORT_FILE = ANALYZER_LATEST_DIR / "final-decision-report.txt"

    ML_LATEST_DIR = DASHBOARD_CACHE_DIR / "ml" / "latest"
    ML_DECISION_FILE = ML_LATEST_DIR / "ml-decision.json"
    ML_SCORES_FILE = ML_LATEST_DIR / "ml-scores.csv"
    ML_DATASET_FILE = DASHBOARD_CACHE_DIR / "ml" / "data" / "latest_features.csv"

    REMEDIATION_LATEST_DIR = DASHBOARD_CACHE_DIR / "remediation" / "latest"
