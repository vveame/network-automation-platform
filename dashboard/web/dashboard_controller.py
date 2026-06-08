from flask import Blueprint, render_template, current_app


dashboard_bp = Blueprint("dashboard", __name__)


def _build_dashboard():
    dashboard_service = current_app.extensions["dashboard_service"]
    return dashboard_service.build_dashboard()


def _render_dashboard_page(template_name: str, active_page: str):
    dashboard = _build_dashboard()

    return render_template(
        template_name,
        dashboard=dashboard,
        active_page=active_page,
    )


@dashboard_bp.route("/")
def index():
    return _render_dashboard_page("pages/overview.html", "overview")


@dashboard_bp.route("/analyzer")
def analyzer():
    return _render_dashboard_page("pages/analyzer.html", "analyzer")


@dashboard_bp.route("/ml")
def ml():
    return _render_dashboard_page("pages/ml.html", "ml")


@dashboard_bp.route("/remediation")
def remediation():
    return _render_dashboard_page("pages/remediation.html", "remediation")


@dashboard_bp.route("/monitoring")
def monitoring():
    return _render_dashboard_page("pages/monitoring.html", "monitoring")


@dashboard_bp.route("/validation")
def validation():
    return _render_dashboard_page("pages/validation.html", "validation")


@dashboard_bp.route("/infrastructure")
def infrastructure():
    return _render_dashboard_page("pages/infrastructure.html", "infrastructure")


@dashboard_bp.route("/services")
def services():
    return _render_dashboard_page("pages/services.html", "services")
