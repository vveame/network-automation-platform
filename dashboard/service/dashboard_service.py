from collections import defaultdict
from typing import Any, Dict, List, Set

from dto.dashboard_dto import DashboardDTO
from dto.domain_dto import DomainDTO
from service.report_service import ReportService
from service.node_service import NodeService
from service.service_health_service import ServiceHealthService


class DashboardService:
    # Fixed-name reports produced by playbooks/roles that are not tied to a
    # specific FRR/OVS node (see ansible/playbooks/*.yml and
    # ansible/roles/*/tasks/main.yml for the "dest: ../outputs/<name>.txt"
    # entries this list mirrors). Keep this in sync if a role's output
    # filename changes.
    FIXED_EXPECTED_REPORTS = [
        "oob-management-readiness.txt",
        "end-to-end-validation.txt",
        "security-validation.txt",
        "report-artifacts-validation.txt",
        "validation-summary.txt",
        "inventory-consistency.txt",
        "dmz-services.txt",
    ]

    def __init__(
        self,
        report_repository,
        vars_repository,
        cloud_analyzer_service,
        prometheus_metrics_service,
        runtime_artifact_service,
    ):
        self.report_service = ReportService(report_repository)
        self.vars_repository = vars_repository
        self.cloud_analyzer_service = cloud_analyzer_service
        self.prometheus_metrics_service = prometheus_metrics_service
        self.runtime_artifact_service = runtime_artifact_service
        self.node_service = NodeService()
        self.service_health_service = ServiceHealthService()

    def build_dashboard(self) -> DashboardDTO:
        vars_data = self.vars_repository.load_all_vars()
        expected_filenames = self._compute_expected_report_filenames(vars_data)
        reports = self.report_service.get_all_reports(expected_filenames=expected_filenames)
        report_status_map = {report.filename: report.status for report in reports}

        domains = self._build_domains(reports)
        nodes = self.node_service.build_nodes(vars_data, report_status_map)
        services = self.service_health_service.build_services(vars_data, report_status_map)

        cloud_analyzer = self.cloud_analyzer_service.get_latest_decision()
        prometheus_metrics = self.prometheus_metrics_service.get_latest_metrics()

        final_decision = self.runtime_artifact_service.get_final_decision()
        ml_decision = self.runtime_artifact_service.get_ml_decision()
        remediation = self.runtime_artifact_service.get_remediation()

        total = len(reports)
        passed = len([report for report in reports if report.status == "passed"])
        failed = len([report for report in reports if report.status == "failed"])
        missing = len([report for report in reports if report.status == "missing"])

        oob_management = vars_data.get("oob_management", {})
        devops_server = vars_data.get("devops_server", {})

        return DashboardDTO(
            project_name=vars_data.get("project_name", "Unknown Project"),
            lab_environment=vars_data.get("lab_environment", "Unknown Environment"),
            global_status=self._global_status(failed, missing),
            total_reports=total,
            passed_reports=passed,
            failed_reports=failed,
            missing_reports=missing,
            oob_network=oob_management.get("network", "N/A"),
            devops_ip=devops_server.get(
                "oob_ip",
                oob_management.get("devops_ip", "N/A"),
            ),
            domains=domains,
            nodes=nodes,
            services=services,
            cloud_analyzer=cloud_analyzer,
            prometheus_metrics=prometheus_metrics,
            final_decision=final_decision,
            ml_decision=ml_decision,
            remediation=remediation,
        )

    def get_report_content(self, filename: str):
        return self.report_service.get_report_content(filename)

    def _compute_expected_report_filenames(self, vars_data: Dict[str, Any]) -> Set[str]:
        expected = set(self.FIXED_EXPECTED_REPORTS)

        for name in vars_data.get("expected_frr_nodes", {}):
            expected.add(f"{name}-frr.txt")

        for name in vars_data.get("expected_ovs_nodes", {}):
            expected.add(f"{name}-ovs.txt")

        return expected

    def _build_domains(self, reports) -> List[DomainDTO]:
        grouped = defaultdict(list)

        for report in reports:
            grouped[report.category].append(report)

        domains = []

        for domain_name in sorted(grouped.keys()):
            domain_reports = grouped[domain_name]
            total = len(domain_reports)
            passed = len([report for report in domain_reports if report.status == "passed"])
            failed = len([report for report in domain_reports if report.status == "failed"])
            missing = len([report for report in domain_reports if report.status == "missing"])

            domains.append(
                DomainDTO(
                    name=domain_name,
                    status=self._global_status(failed, missing),
                    total=total,
                    passed=passed,
                    failed=failed,
                    missing=missing,
                    reports=domain_reports,
                )
            )

        return domains

    def _global_status(self, failed: int, missing: int) -> str:
        if failed > 0:
            return "failed"
        if missing > 0:
            return "warning"
        return "passed"
