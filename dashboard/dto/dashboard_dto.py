from dataclasses import dataclass, asdict
from typing import Any, Dict, List

from dto.domain_dto import DomainDTO
from dto.node_dto import NodeDTO
from dto.service_dto import ServiceDTO
from dto.cloud_analyzer_dto import CloudAnalyzerDTO


@dataclass
class DashboardDTO:
    project_name: str
    lab_environment: str
    global_status: str

    total_reports: int
    passed_reports: int
    failed_reports: int
    missing_reports: int

    oob_network: str
    devops_ip: str

    domains: List[DomainDTO]
    nodes: List[NodeDTO]
    services: List[ServiceDTO]

    cloud_analyzer: CloudAnalyzerDTO
    prometheus_metrics: Any

    final_decision: Dict[str, Any]
    ml_decision: Dict[str, Any]
    remediation: Dict[str, Any]

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)
