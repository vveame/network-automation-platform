from flask import Blueprint, render_template, current_app

dashboard_bp = Blueprint("dashboard", __name__)


@dashboard_bp.route("/")
def index():
    dashboard_service = current_app.extensions["dashboard_service"]
    dashboard = dashboard_service.build_dashboard()

    return render_template("index.html", dashboard=dashboard)
