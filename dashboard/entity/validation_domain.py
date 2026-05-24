from dataclasses import dataclass
from typing import List

from dto.report_dto import ReportDTO


@dataclass
class ValidationDomain:
    name: str
    reports: List[ReportDTO]
