from pathlib import Path
from datetime import datetime
from typing import Iterable, List, Optional

from entity.ansible_report import AnsibleReport


class ReportRepository:
    def __init__(self, outputs_dir: Path):
        self.outputs_dir = outputs_dir

    def list_reports(self, expected_filenames: Optional[Iterable[str]] = None) -> List[AnsibleReport]:
        found = {}

        if self.outputs_dir.exists():
            for path in self.outputs_dir.glob("*.txt"):
                found[path.name] = path

        reports = [self._build_report_entity(path) for path in sorted(found.values())]

        # Some report files are expected to exist (fixed validation reports, or
        # one per FRR/OVS node) but may be absent because a run failed before
        # producing them, or because a sync with --delete removed a stale copy
        # after a previous run. Without this, such files simply disappear from
        # the dashboard instead of being flagged as "missing".
        if expected_filenames:
            missing_filenames = sorted(set(expected_filenames) - set(found.keys()))
            for filename in missing_filenames:
                reports.append(self._build_missing_report_entity(filename))

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

    def _build_missing_report_entity(self, filename: str) -> AnsibleReport:
        # Empty content deliberately reuses ReportParserService.detect_status(),
        # which already maps blank content to the "missing" status.
        return AnsibleReport(
            filename=filename,
            content="",
            size_kb=0.0,
            updated_at="Not generated",
        )

    def _safe_report_path(self, filename: str) -> Optional[Path]:
        requested = (self.outputs_dir / filename).resolve()
        base = self.outputs_dir.resolve()

        if not str(requested).startswith(str(base)):
            return None

        return requested
