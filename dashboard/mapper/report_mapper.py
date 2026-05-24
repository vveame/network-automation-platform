from dto.report_dto import ReportDTO
from entity.ansible_report import AnsibleReport
from service.report_parser_service import ReportParserService


class ReportMapper:
    def __init__(self):
        self.parser = ReportParserService()

    def to_dto(self, report: AnsibleReport) -> ReportDTO:
        return ReportDTO(
            filename=report.filename,
            title=self.parser.title_from_filename(report.filename),
            category=self.parser.detect_category(report.filename),
            status=self.parser.detect_status(report.content),
            summary=self.parser.extract_summary(report.content),
            size_kb=report.size_kb,
            updated_at=report.updated_at,
        )
