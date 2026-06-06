import os
from pathlib import Path


class Config:
    APP_NAME = "PFE Validation Dashboard"
    HOST = "0.0.0.0"
    PORT = 5050
    DEBUG = True

    # Project paths
    DASHBOARD_DIR = Path(__file__).resolve().parent
    REPO_ROOT = DASHBOARD_DIR.parent

    ANSIBLE_DIR = REPO_ROOT / "ansible"
    CLOUD_ANALYZER_DIR = REPO_ROOT / "cloud" / "analyzer"
    MONITORING_DIR = REPO_ROOT / "monitoring"

    # Shared dashboard cache.
    #
    # Jenkins/sync scripts populate this folder from S3.
    # The dashboard reads from this cache, not directly from S3.
    DASHBOARD_CACHE_DIR = Path(
        os.getenv("DASHBOARD_CACHE_DIR", "/var/lib/pfe-dashboard")
    )

    # Validation report cache:
    # /var/lib/pfe-dashboard/outputs
    ANSIBLE_OUTPUTS_DIR = Path(
        os.getenv(
            "DASHBOARD_OUTPUTS_DIR",
            DASHBOARD_CACHE_DIR / "outputs",
        )
    )

    # Ansible inventory/group vars remain versioned in the repo.
    ANSIBLE_GROUP_VARS_FILE = Path(
        os.getenv(
            "ANSIBLE_GROUP_VARS_FILE",
            ANSIBLE_DIR / "group_vars" / "all.yml",
        )
    )

    # Cloud analyzer cache:
    # /var/lib/pfe-dashboard/analyzer/latest/decision.json
    CLOUD_ANALYZER_LATEST_DECISION_FILE = Path(
        os.getenv(
            "CLOUD_ANALYZER_LATEST_DECISION_FILE",
            DASHBOARD_CACHE_DIR / "analyzer" / "latest" / "decision.json",
        )
    )

    # Prometheus metrics cache:
    # /var/lib/pfe-dashboard/metrics/latest
    PROMETHEUS_METRICS_LATEST_DIR = Path(
        os.getenv(
            "DASHBOARD_METRICS_DIR",
            DASHBOARD_CACHE_DIR / "metrics" / "latest",
        )
    )

    # Backward-compatible alias in case older code still uses this key.
    PROMETHEUS_METRICS_DIR = PROMETHEUS_METRICS_LATEST_DIR
