from repository.report_repository import ReportRepository
from repository.ansible_vars_repository import AnsibleVarsRepository
from repository.cloud_analyzer_repository import CloudAnalyzerRepository
from repository.prometheus_metrics_repository import PrometheusMetricsRepository

from service.dashboard_service import DashboardService
from service.cloud_analyzer_service import CloudAnalyzerService
from service.prometheus_metrics_service import PrometheusMetricsService
from service.runtime_artifact_service import RuntimeArtifactService


def init_services(app):
    report_repository = ReportRepository(app.config["ANSIBLE_OUTPUTS_DIR"])
    vars_repository = AnsibleVarsRepository(app.config["ANSIBLE_GROUP_VARS_FILE"])

    cloud_analyzer_repository = CloudAnalyzerRepository(
        app.config["CLOUD_ANALYZER_LATEST_DECISION_FILE"]
    )
    cloud_analyzer_service = CloudAnalyzerService(cloud_analyzer_repository)

    prometheus_metrics_repository = PrometheusMetricsRepository(
        app.config["PROMETHEUS_METRICS_DIR"]
    )
    prometheus_metrics_service = PrometheusMetricsService(prometheus_metrics_repository)

    runtime_artifact_service = RuntimeArtifactService(
        final_decision_file=app.config["CLOUD_ANALYZER_FINAL_DECISION_FILE"],
        final_report_file=app.config["CLOUD_ANALYZER_FINAL_REPORT_FILE"],
        ml_decision_file=app.config["ML_DECISION_FILE"],
        ml_scores_file=app.config["ML_SCORES_FILE"],
        ml_dataset_file=app.config["ML_DATASET_FILE"],
        remediation_dir=app.config["REMEDIATION_LATEST_DIR"],
    )

    dashboard_service = DashboardService(
        report_repository=report_repository,
        vars_repository=vars_repository,
        cloud_analyzer_service=cloud_analyzer_service,
        prometheus_metrics_service=prometheus_metrics_service,
        runtime_artifact_service=runtime_artifact_service,
    )

    app.extensions["dashboard_service"] = dashboard_service
    app.extensions["report_repository"] = report_repository
    app.extensions["vars_repository"] = vars_repository
    app.extensions["cloud_analyzer_service"] = cloud_analyzer_service
    app.extensions["prometheus_metrics_service"] = prometheus_metrics_service
    app.extensions["runtime_artifact_service"] = runtime_artifact_service
