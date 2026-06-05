from repository.report_repository import ReportRepository
from repository.ansible_vars_repository import AnsibleVarsRepository
from repository.cloud_analyzer_repository import CloudAnalyzerRepository
from repository.prometheus_metrics_repository import PrometheusMetricsRepository
from service.dashboard_service import DashboardService
from service.cloud_analyzer_service import CloudAnalyzerService
from service.prometheus_metrics_service import PrometheusMetricsService


def init_services(app):
    report_repository = ReportRepository(app.config["ANSIBLE_OUTPUTS_DIR"])
    vars_repository = AnsibleVarsRepository(app.config["ANSIBLE_GROUP_VARS_FILE"])

    cloud_analyzer_repository = CloudAnalyzerRepository(
        app.config["CLOUD_ANALYZER_LATEST_DECISION_FILE"]
    )
    cloud_analyzer_service = CloudAnalyzerService(cloud_analyzer_repository)

    prometheus_metrics_repository = PrometheusMetricsRepository(
        app.config["PROMETHEUS_METRICS_LATEST_DIR"]
    )
    prometheus_metrics_service = PrometheusMetricsService(prometheus_metrics_repository)

    dashboard_service = DashboardService(
        report_repository=report_repository,
        vars_repository=vars_repository,
        cloud_analyzer_service=cloud_analyzer_service,
        prometheus_metrics_service=prometheus_metrics_service,
    )

    app.extensions["dashboard_service"] = dashboard_service
    app.extensions["report_repository"] = report_repository
    app.extensions["vars_repository"] = vars_repository
    app.extensions["cloud_analyzer_service"] = cloud_analyzer_service
    app.extensions["prometheus_metrics_service"] = prometheus_metrics_service
