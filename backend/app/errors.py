from werkzeug.exceptions import HTTPException

from .extensions import db, jwt
from .utils.responses import error


def register_error_handlers(app):
    @app.errorhandler(HTTPException)
    def handle_http(e):
        return error(e.description, e.code)

    @app.errorhandler(Exception)
    def handle_unexpected(e):
        db.session.rollback()
        app.logger.exception(e)
        return error("Internal server error", 500)

    # JWT problems -> 401 in our standard format
    @jwt.unauthorized_loader
    def missing_token(reason):
        return error("Missing or invalid token", 401)

    @jwt.invalid_token_loader
    def invalid_token(reason):
        return error("Invalid token", 401)

    @jwt.expired_token_loader
    def expired_token(header, payload):
        return error("Token has expired, please log in again", 401)
