from dataclasses import dataclass
from typing import List

from dto.report_dto import ReportDTO


@dataclass
class DomainDTO:
    name: str
    status: str
    total: int
    passed: int
    failed: int
    missing: int
    reports: List[ReportDTO]
