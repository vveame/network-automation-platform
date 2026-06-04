from pathlib import Path


class Config:
    APP_NAME = "PFE Validation Dashboard"
    HOST = "0.0.0.0"
    PORT = 5050
    DEBUG = True

    DASHBOARD_DIR = Path(__file__).resolve().parent
    REPO_ROOT = DASHBOARD_DIR.parent

    DASHBOARD_CACHE_DIR = Path("/var/lib/pfe-dashboard")

    ANSIBLE_DIR = REPO_ROOT / "ansible"
    ANSIBLE_OUTPUTS_DIR = DASHBOARD_CACHE_DIR / "outputs"
    ANSIBLE_GROUP_VARS_FILE = ANSIBLE_DIR / "group_vars" / "all.yml"

    CLOUD_ANALYZER_LATEST_DECISION_FILE = (
        DASHBOARD_CACHE_DIR / "analyzer" / "latest" / "decision.json"
    )