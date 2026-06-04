from dataclasses import dataclass
from typing import List


@dataclass
class CloudAnalyzerDTO:
    available: bool
    anomaly_status: str
    risk_score: int
    severity: str
    recommended_action: str
    build_label: str
    failed_reports: List[str]
    warning_reports: List[str]
    source_file: str
