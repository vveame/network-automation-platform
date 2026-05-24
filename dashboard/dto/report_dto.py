from dataclasses import dataclass


@dataclass
class ReportDTO:
    filename: str
    title: str
    category: str
    status: str
    summary: str
    size_kb: float
    updated_at: str
