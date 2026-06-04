from repository.report_repository import ReportRepository
from repository.ansible_vars_repository import AnsibleVarsRepository
from repository.cloud_analyzer_repository import CloudAnalyzerRepository
from service.dashboard_service import DashboardService
from service.cloud_analyzer_service import CloudAnalyzerService


def init_services(app):
    report_repository = ReportRepository(app.config["ANSIBLE_OUTPUTS_DIR"])
    vars_repository = AnsibleVarsRepository(app.config["ANSIBLE_GROUP_VARS_FILE"])

    cloud_analyzer_repository = CloudAnalyzerRepository(
        app.config["CLOUD_ANALYZER_LATEST_DECISION_FILE"]
    )
    cloud_analyzer_service = CloudAnalyzerService(cloud_analyzer_repository)

    dashboard_service = DashboardService(
        report_repository=report_repository,
        vars_repository=vars_repository,
        cloud_analyzer_service=cloud_analyzer_service,
    )

    app.extensions["dashboard_service"] = dashboard_service
    app.extensions["report_repository"] = report_repository
    app.extensions["vars_repository"] = vars_repository
    app.extensions["cloud_analyzer_service"] = cloud_analyzer_service
