from typing import Iterable, List, Optional

from dto.report_dto import ReportDTO
from mapper.report_mapper import ReportMapper


class ReportService:
    def __init__(self, report_repository):
        self.report_repository = report_repository
        self.report_mapper = ReportMapper()

    def get_all_reports(self, expected_filenames: Optional[Iterable[str]] = None) -> List[ReportDTO]:
        reports = self.report_repository.list_reports(expected_filenames=expected_filenames)
        return [self.report_mapper.to_dto(report) for report in reports]

    def get_report_content(self, filename: str) -> Optional[str]:
        return self.report_repository.read_report_content(filename)

    def get_report_status_map(self, expected_filenames: Optional[Iterable[str]] = None):
        status_map = {}

        for report in self.get_all_reports(expected_filenames=expected_filenames):
            status_map[report.filename] = report.status

        return status_map
