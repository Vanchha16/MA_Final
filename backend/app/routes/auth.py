import secrets
from datetime import timedelta

from flask import Blueprint, current_app, request
from flask_jwt_extended import create_access_token, decode_token, get_jwt_identity, jwt_required

from ..extensions import bcrypt, db
from ..models import PasswordReset, User
from ..utils.clock import utcnow
from ..utils.mailer import send_email
from ..utils.responses import error, success
from ..utils.validators import is_valid_email, is_valid_phone, normalize_phone, require_fields

bp = Blueprint("auth", __name__, url_prefix="/api/auth")


def _token_for(user):
    # JWT "sub" must be a string
    return create_access_token(identity=str(user.id), additional_claims={"role": user.role})


@bp.post("/register")
def register():
    data = request.get_json(silent=True) or {}
    errors = require_fields(data, ["full_name", "email", "password"])
    if data.get("email") and not is_valid_email(data["email"]):
        errors["email"] = "Email is not valid"
    if data.get("password") and len(data["password"]) < 6:
        errors["password"] = "Password must be at least 6 characters"
    phone = normalize_phone(data.get("phone"))
    if phone and not is_valid_phone(phone):
        errors["phone"] = "Phone number is not valid"
    if errors:
        return error("Validation failed", 422, errors)

    email = data["email"].strip().lower()
    if User.query.filter_by(email=email).first():
        return error("Validation failed", 422, {"email": "Email is already registered"})

    user = User(
        full_name=data["full_name"].strip(),
        email=email,
        phone=phone,
        password_hash=bcrypt.generate_password_hash(data["password"]).decode(),
    )
    db.session.add(user)
    db.session.commit()
    return success({"token": _token_for(user), "user": user.to_dict()}, "Registered successfully", 201)


@bp.post("/login")
def login():
    data = request.get_json(silent=True) or {}
    errors = require_fields(data, ["email", "password"])
    if errors:
        return error("Validation failed", 422, errors)

    user = User.query.filter_by(email=data["email"].strip().lower()).first()
    if not user or not bcrypt.check_password_hash(user.password_hash, data["password"]):
        return error("Incorrect email or password", 401)
    if not user.is_active:
        return error("This account has been disabled", 403)

    return success({"token": _token_for(user), "user": user.to_dict()}, "Logged in successfully")


@bp.get("/me")
@jwt_required()
def me():
    user = db.session.get(User, int(get_jwt_identity()))
    if not user:
        return error("User not found", 404)
    return success(user.to_dict())


# ---------------------------------------------------------------------------
# Forgot password: request code -> verify code -> set new password
# ---------------------------------------------------------------------------

GENERIC_SENT = "If this email is registered, we sent a 6-digit code to it."


def _latest_reset(user):
    return (
        PasswordReset.query.filter_by(user_id=user.id, used=False)
        .order_by(PasswordReset.created_at.desc(), PasswordReset.id.desc())
        .first()
    )


@bp.post("/forgot-password")
def forgot_password():
    cfg = current_app.config
    data = request.get_json(silent=True) or {}
    email = (data.get("email") or "").strip().lower()
    if not email:
        return error("Validation failed", 422, {"email": "email is required"})
    if not is_valid_email(email):
        return error("Validation failed", 422, {"email": "Email is not valid"})

    payload = {"expires_in": cfg["RESET_CODE_MINUTES"] * 60, "resend_after": cfg["RESET_RESEND_SECONDS"]}
    user = User.query.filter_by(email=email).first()
    # Same answer whether or not the email exists, so accounts can't be discovered
    if not user or not user.is_active:
        return success(payload, GENERIC_SENT)

    now = utcnow()
    recent = PasswordReset.query.filter(
        PasswordReset.user_id == user.id, PasswordReset.created_at >= now - timedelta(hours=1)
    ).order_by(PasswordReset.created_at.desc()).all()
    if recent:
        wait = cfg["RESET_RESEND_SECONDS"] - int((now - recent[0].created_at).total_seconds())
        if wait > 0:
            return error(f"Please wait {wait}s before requesting a new code", 429, {"retry_after": wait})
    if len(recent) >= cfg["RESET_MAX_PER_HOUR"]:
        return error("Too many code requests. Please try again in an hour.", 429)

    # Only the newest code is valid
    PasswordReset.query.filter_by(user_id=user.id, used=False).update({"used": True})
    code = f"{secrets.randbelow(1_000_000):06d}"
    db.session.add(PasswordReset(
        user_id=user.id,
        code_hash=bcrypt.generate_password_hash(code).decode(),
        expires_at=now + timedelta(minutes=cfg["RESET_CODE_MINUTES"]),
        created_at=now,
    ))
    db.session.commit()

    send_email(
        user.email,
        "Your Anime World Shop password reset code",
        f"Hi {user.full_name},\n\nYour password reset code is: {code}\n\n"
        f"It expires in {cfg['RESET_CODE_MINUTES']} minutes. If you didn't ask for this, you can ignore this email.",
    )
    # Development only: return the code so the app can be tested without real email
    if cfg["MAIL_MODE"] == "console" and (current_app.debug or current_app.testing):
        payload["dev_code"] = code
    return success(payload, GENERIC_SENT)


@bp.post("/verify-otp")
def verify_otp():
    cfg = current_app.config
    data = request.get_json(silent=True) or {}
    errors = require_fields(data, ["email", "code"])
    if errors:
        return error("Validation failed", 422, errors)

    invalid = error("Invalid or expired code", 400, {"code": "The code is incorrect or has expired"})
    user = User.query.filter_by(email=data["email"].strip().lower()).first()
    reset = _latest_reset(user) if user else None
    if not reset or reset.expires_at < utcnow():
        return invalid

    if not bcrypt.check_password_hash(reset.code_hash, str(data["code"]).strip()):
        reset.attempts += 1
        if reset.attempts >= cfg["RESET_MAX_ATTEMPTS"]:
            reset.used = True
            db.session.commit()
            return error("Too many wrong attempts. Please request a new code.", 429)
        db.session.commit()
        return invalid

    token = create_access_token(
        identity=str(user.id),
        additional_claims={"purpose": "password_reset", "rid": reset.id},
        expires_delta=timedelta(minutes=cfg["RESET_TOKEN_MINUTES"]),
    )
    return success({"reset_token": token}, "Code verified")


@bp.post("/reset-password")
def reset_password():
    data = request.get_json(silent=True) or {}
    errors = require_fields(data, ["reset_token", "new_password"])
    if data.get("new_password") and len(data["new_password"]) < 6:
        errors["new_password"] = "Password must be at least 6 characters"
    if errors:
        return error("Validation failed", 422, errors)

    expired = error("This reset link has expired. Please request a new code.", 400)
    try:
        claims = decode_token(data["reset_token"])
    except Exception:  # bad signature, expired, malformed
        return expired
    if claims.get("purpose") != "password_reset":
        return expired

    reset = db.session.get(PasswordReset, claims.get("rid"))
    user = db.session.get(User, int(claims["sub"]))
    if not reset or reset.used or not user or reset.user_id != user.id:
        return expired

    user.password_hash = bcrypt.generate_password_hash(data["new_password"]).decode()
    reset.used = True
    db.session.commit()
    return success(None, "Password updated. You can now log in.")
