from flask import Blueprint, request
from flask_jwt_extended import create_access_token, get_jwt_identity, jwt_required

from ..extensions import bcrypt, db
from ..models import User
from ..utils.responses import error, success
from ..utils.validators import is_valid_email, require_fields

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
    if errors:
        return error("Validation failed", 422, errors)

    email = data["email"].strip().lower()
    if User.query.filter_by(email=email).first():
        return error("Validation failed", 422, {"email": "Email is already registered"})

    user = User(
        full_name=data["full_name"].strip(),
        email=email,
        phone=data.get("phone"),
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
