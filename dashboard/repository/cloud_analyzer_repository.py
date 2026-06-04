import json
from pathlib import Path
from typing import Optional, Dict, Any


class CloudAnalyzerRepository:
    def __init__(self, latest_decision_file: Path):
        self.latest_decision_file = latest_decision_file

    def load_latest_decision(self) -> Optional[Dict[str, Any]]:
        if not self.latest_decision_file.exists() or not self.latest_decision_file.is_file():
            return None

        try:
            return json.loads(self.latest_decision_file.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return None
