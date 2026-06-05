import json
from pathlib import Path
from typing import Any, Dict, Optional


class PrometheusMetricsRepository:
    def __init__(self, metrics_dir: Path):
        self.metrics_dir = metrics_dir

    def load_json_file(self, filename: str) -> Optional[Dict[str, Any]]:
        path = self.metrics_dir / filename

        if not path.exists() or not path.is_file():
            return None

        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return None

    def load_manifest(self) -> Optional[Dict[str, Any]]:
        return self.load_json_file("manifest.json")

    def load_query(self, name: str) -> Optional[Dict[str, Any]]:
        return self.load_json_file(f"{name}.json")
