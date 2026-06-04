# py -m venv dashboard/.venv
# source dashboard/.venv/Scripts/activate (Win) - dashboard/.venv/bin/activate (Linux)
# python -m pip install -r dashboard/requirements.txt
# python dashboard/app.py

from flask import Flask

from config import Config
from extensions import init_services
from global_error_handler import register_error_handlers
from security.simple_headers import register_security_headers
from web.dashboard_controller import dashboard_bp
from web.report_controller import report_bp
from web.api_controller import api_bp


def create_app():
    app = Flask(__name__)

    app.config.from_object(Config)

    init_services(app)
    register_error_handlers(app)
    register_security_headers(app)

    app.register_blueprint(dashboard_bp)
    app.register_blueprint(report_bp)
    app.register_blueprint(api_bp)

    return app


app = create_app()


if __name__ == "__main__":
    app.run(
        host=app.config["HOST"],
        port=app.config["PORT"],
        debug=app.config["DEBUG"],
    )
