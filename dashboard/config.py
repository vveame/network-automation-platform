from pathlib import Path


class Config:
    APP_NAME = "PFE Validation Dashboard"
    HOST = "0.0.0.0"
    PORT = 5050
    DEBUG = True

    DASHBOARD_DIR = Path(__file__).resolve().parent
    REPO_ROOT = DASHBOARD_DIR.parent

    ANSIBLE_DIR = REPO_ROOT / "ansible"
    ANSIBLE_OUTPUTS_DIR = ANSIBLE_DIR / "outputs"
    ANSIBLE_GROUP_VARS_FILE = ANSIBLE_DIR / "group_vars" / "all.yml"
