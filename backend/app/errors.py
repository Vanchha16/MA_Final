from werkzeug.exceptions import HTTPException

from .extensions import db, jwt
from .models import User
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

    # Special-purpose tokens (e.g. password reset) must not work as a login token
    @jwt.token_verification_loader
    def only_login_tokens(header, payload):
        return payload.get("purpose") is None

    @jwt.token_verification_failed_loader
    def wrong_token_type(header, payload):
        return error("Invalid token", 401)

    # A blocked customer's token stops working at once, not only at the next login
    @jwt.token_in_blocklist_loader
    def blocked_account(header, payload):
        if payload.get("purpose") is not None:
            return False
        user = db.session.get(User, int(payload["sub"]))
        # also refused: tokens from before the last password change
        return user is None or not user.is_active or payload.get("ver", 0) != user.token_version

    @jwt.revoked_token_loader
    def account_disabled(header, payload):
        user = db.session.get(User, int(payload["sub"]))
        if user is not None and user.is_active:
            return error("Your password was changed. Please log in again.", 401)
        return error("This account has been disabled", 403)
