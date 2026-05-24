from pathlib import Path
from datetime import datetime
from typing import List, Optional

from entity.ansible_report import AnsibleReport


class ReportRepository:
    def __init__(self, outputs_dir: Path):
        self.outputs_dir = outputs_dir

    def list_reports(self) -> List[AnsibleReport]:
        if not self.outputs_dir.exists():
            return []

        reports = []

        for path in sorted(self.outputs_dir.glob("*.txt")):
            reports.append(self._build_report_entity(path))

        return reports

    def read_report_content(self, filename: str) -> Optional[str]:
        path = self._safe_report_path(filename)

        if path is None or not path.exists() or not path.is_file():
            return None

        return path.read_text(errors="replace")

    def report_exists(self, filename: str) -> bool:
        path = self._safe_report_path(filename)
        return path is not None and path.exists() and path.is_file()

    def _build_report_entity(self, path: Path) -> AnsibleReport:
        stat = path.stat()

        return AnsibleReport(
            filename=path.name,
            content=path.read_text(errors="replace"),
            size_kb=round(stat.st_size / 1024, 2),
            updated_at=datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M:%S"),
        )

    def _safe_report_path(self, filename: str) -> Optional[Path]:
        requested = (self.outputs_dir / filename).resolve()
        base = self.outputs_dir.resolve()

        if not str(requested).startswith(str(base)):
            return None

        return requested
