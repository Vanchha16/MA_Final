import secrets
from datetime import timedelta

from flask import Blueprint, current_app, request
from flask_jwt_extended import create_access_token, decode_token, get_jwt_identity, jwt_required

from .. import notify
from ..extensions import bcrypt, db, limiter
from ..models import PasswordReset, User
from ..utils.clock import utcnow
from ..utils.mailer import send_email
from ..utils.responses import error, success
from ..utils.validators import Fields, json_body

bp = Blueprint("auth", __name__, url_prefix="/api/auth")


def token_for(user):
    # JWT "sub" must be a string; "ver" lets a password change sign out other devices
    return create_access_token(identity=str(user.id), additional_claims={"role": user.role, "ver": user.token_version})


def _login_email():
    """Rate-limit key: the email being tried (so one account can't be guessed from many IPs)."""
    email = json_body().get("email")
    return f"login:{email.strip().lower()}" if isinstance(email, str) and email.strip() else request.remote_addr


@bp.post("/register")
@limiter.limit("20 per hour", error_message="Too many sign-ups from this network. Please try again later.")
def register():
    f = Fields(json_body())
    full_name = f.person_name("full_name", label="Name")
    email = f.email()
    password = f.password("password")
    phone = f.phone()
    if f.errors:
        return error("Validation failed", 422, f.errors)

    if User.query.filter_by(email=email).first():
        return error("Validation failed", 422, {"email": "Email is already registered"})

    user = User(
        full_name=full_name,
        email=email,
        phone=phone,
        password_hash=bcrypt.generate_password_hash(password).decode(),
    )
    db.session.add(user)
    db.session.flush()
    notify.welcome(user.id)
    db.session.commit()
    return success({"token": token_for(user), "user": user.to_dict()}, "Registered successfully", 201)


@bp.post("/login")
@limiter.limit("10 per minute", error_message="Too many login attempts. Please wait a minute and try again.")
@limiter.limit("10 per 15 minutes", key_func=_login_email,
               error_message="Too many wrong passwords for this account. Please wait 15 minutes or reset your password.")
def login():
    f = Fields(json_body())
    email = f.text("email", required=True, max_len=150, label="Email")
    password = f.text("password", required=True, strip=False, max_len=200, label="Password")
    if f.errors:
        return error("Validation failed", 422, f.errors)

    user = User.query.filter_by(email=email.lower()).first()
    if not user or not bcrypt.check_password_hash(user.password_hash, password):
        return error("Incorrect email or password", 401)
    if not user.is_active:
        return error("This account has been disabled", 403)

    user.last_login_at = utcnow()
    db.session.commit()
    return success({"token": token_for(user), "user": user.to_dict()}, "Logged in successfully")


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
    f = Fields(json_body())
    email = f.email()
    if f.errors:
        return error("Validation failed", 422, f.errors)

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
    data = json_body()
    f = Fields(data)
    email = f.text("email", required=True, max_len=150, label="Email")
    code = data.get("code")
    code = str(code).strip() if isinstance(code, (str, int)) and not isinstance(code, bool) else ""
    if not code:
        f.errors["code"] = "code is required"
    elif not code.isdigit() or len(code) != 6:
        f.errors["code"] = "The code has 6 digits"
    if f.errors:
        return error("Validation failed", 422, f.errors)

    invalid = error("Invalid or expired code", 400, {"code": "The code is incorrect or has expired"})
    user = User.query.filter_by(email=email.lower()).first()
    reset = _latest_reset(user) if user else None
    if not reset or reset.expires_at < utcnow():
        return invalid

    if not bcrypt.check_password_hash(reset.code_hash, code):
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
    f = Fields(json_body())
    reset_token = f.text("reset_token", required=True, max_len=2000)
    new_password = f.password("new_password")
    if f.errors:
        return error("Validation failed", 422, f.errors)

    expired = error("This reset link has expired. Please request a new code.", 400)
    try:
        claims = decode_token(reset_token)
    except Exception:  # bad signature, expired, malformed
        return expired
    if claims.get("purpose") != "password_reset":
        return expired

    reset = db.session.get(PasswordReset, claims.get("rid"))
    user = db.session.get(User, int(claims["sub"]))
    if not reset or reset.used or not user or reset.user_id != user.id:
        return expired

    user.password_hash = bcrypt.generate_password_hash(new_password).decode()
    user.token_version += 1  # signs out every device that was logged in
    reset.used = True
    db.session.commit()
    return success(None, "Password updated. You can now log in.")
