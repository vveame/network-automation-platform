from repository.report_repository import ReportRepository
from repository.ansible_vars_repository import AnsibleVarsRepository
from service.dashboard_service import DashboardService


def init_services(app):
    report_repository = ReportRepository(app.config["ANSIBLE_OUTPUTS_DIR"])
    vars_repository = AnsibleVarsRepository(app.config["ANSIBLE_GROUP_VARS_FILE"])

    dashboard_service = DashboardService(
        report_repository=report_repository,
        vars_repository=vars_repository,
    )

    app.extensions["dashboard_service"] = dashboard_service
    app.extensions["report_repository"] = report_repository
    app.extensions["vars_repository"] = vars_repository
