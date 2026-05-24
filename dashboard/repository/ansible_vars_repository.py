from pathlib import Path
from typing import Dict, Any
import yaml


class AnsibleVarsRepository:
    def __init__(self, vars_file: Path):
        self.vars_file = vars_file

    def load_all_vars(self) -> Dict[str, Any]:
        if not self.vars_file.exists():
            return {}

        with self.vars_file.open("r", encoding="utf-8") as file:
            return yaml.safe_load(file) or {}
