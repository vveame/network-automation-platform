from flask import jsonify, request


def wants_json_response():
    return request.path.startswith("/api/")


def register_error_handlers(app):
    @app.errorhandler(404)
    def not_found(error):
        if wants_json_response():
            return jsonify({
                "status": "error",
                "message": "Resource not found",
            }), 404

        return "<h1>404 - Resource not found</h1>", 404

    @app.errorhandler(500)
    def internal_error(error):
        if wants_json_response():
            return jsonify({
                "status": "error",
                "message": "Internal server error",
            }), 500

        return "<h1>500 - Internal server error</h1>", 500
