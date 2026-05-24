from flask import Blueprint, render_template, current_app, abort
from service.report_parser_service import ReportParserService

report_bp = Blueprint("report", __name__)

parser = ReportParserService()


@report_bp.route("/report/<path:filename>")
def report_detail(filename):
    dashboard_service = current_app.extensions["dashboard_service"]
    content = dashboard_service.get_report_content(filename)

    if content is None:
        abort(404)

    return render_template(
        "report.html",
        filename=filename,
        title=parser.title_from_filename(filename),
        category=parser.detect_category(filename),
        status=parser.detect_status(content),
        content=content,
    )
