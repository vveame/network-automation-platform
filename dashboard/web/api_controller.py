from flask import Blueprint, jsonify, current_app, abort
from service.report_parser_service import ReportParserService

api_bp = Blueprint("api", __name__, url_prefix="/api")

parser = ReportParserService()


@api_bp.route("/dashboard")
def get_dashboard():
    dashboard_service = current_app.extensions["dashboard_service"]
    dashboard = dashboard_service.build_dashboard()

    return jsonify(dashboard.to_dict())


@api_bp.route("/report/<path:filename>")
def get_report(filename):
    dashboard_service = current_app.extensions["dashboard_service"]
    content = dashboard_service.get_report_content(filename)

    if content is None:
        abort(404)

    return jsonify({
        "filename": filename,
        "title": parser.title_from_filename(filename),
        "category": parser.detect_category(filename),
        "status": parser.detect_status(content),
        "content": content,
    })


@api_bp.route("/health")
def health():
    return jsonify({
        "status": "UP",
        "service": "validation-dashboard",
    })
