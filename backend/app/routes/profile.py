import os
import uuid

from flask import Blueprint, current_app, request
from flask_jwt_extended import get_jwt_identity, jwt_required
from sqlalchemy import func

from ..extensions import bcrypt, db
from ..models import Favorite, Order, OrderItem, Review, User
from ..utils.responses import error, success
from ..utils.validators import is_valid_phone, normalize_phone, require_fields

bp = Blueprint("profile", __name__, url_prefix="/api/profile")

# Loyalty tiers: 1 point per $1 spent on delivered orders
TIERS = [("Bronze", 0), ("Silver", 500), ("Gold", 2000), ("Platinum", 5000)]

# First bytes of the image types we accept
IMAGE_SIGNATURES = {
    b"\x89PNG\r\n\x1a\n": "png",
    b"\xff\xd8\xff": "jpg",
}
MAX_AVATAR_BYTES = 5 * 1024 * 1024


def _current_user():
    return db.session.get(User, int(get_jwt_identity()))


def _tier(points):
    current = TIERS[0]
    for tier in TIERS:
        if points >= tier[1]:
            current = tier
    idx = TIERS.index(current)
    nxt = TIERS[idx + 1] if idx + 1 < len(TIERS) else None
    if not nxt:
        return {"name": current[0], "next_name": None, "points_to_next": 0, "progress": 1.0}
    span = nxt[1] - current[1]
    return {
        "name": current[0],
        "next_name": nxt[0],
        "points_to_next": nxt[1] - points,
        "progress": round((points - current[1]) / span, 3),
    }


@bp.get("/summary")
@jwt_required()
def summary():
    user = _current_user()
    if not user:
        return error("User not found", 404)

    orders = Order.query.filter_by(user_id=user.id)
    to_pay = orders.filter(Order.status == "pending", Order.payment_method != "cod",
                           Order.payment_status == "unpaid").count()
    to_ship = orders.filter(
        db.or_(Order.status == "confirmed",
               db.and_(Order.status == "pending",
                       db.or_(Order.payment_method == "cod", Order.payment_status == "paid")))
    ).count()
    to_receive = orders.filter(Order.status == "shipped").count()

    # Delivered products the user hasn't reviewed yet
    reviewed = {r.product_id for r in Review.query.filter_by(user_id=user.id)}
    delivered_products = {
        pid for (pid,) in db.session.query(OrderItem.product_id)
        .join(Order).filter(Order.user_id == user.id, Order.status == "delivered", OrderItem.product_id.isnot(None))
    }
    spent = db.session.query(func.coalesce(func.sum(Order.total), 0)).filter(
        Order.user_id == user.id, Order.status == "delivered").scalar()
    points = int(spent)

    return success({
        "user": user.to_dict(),
        "stats": {
            "orders": orders.filter(Order.status != "cancelled").count(),
            "wishlist": Favorite.query.filter_by(user_id=user.id).count(),
            "reviews": len(reviewed),
        },
        "order_status": {
            "to_pay": to_pay,
            "to_ship": to_ship,
            "to_receive": to_receive,
            "to_review": len(delivered_products - reviewed),
        },
        "points": points,
        "tier": _tier(points),
    })


@bp.put("")
@jwt_required()
def update_profile():
    user = _current_user()
    data = request.get_json(silent=True) or {}
    errors = require_fields(data, ["full_name"])
    name = (data.get("full_name") or "").strip()
    if name and len(name) < 2:
        errors["full_name"] = "Name is too short"
    phone = normalize_phone(data.get("phone"))
    if phone and not is_valid_phone(phone):
        errors["phone"] = "Phone number is not valid"
    if errors:
        return error("Validation failed", 422, errors)

    user.full_name = name
    user.phone = phone
    db.session.commit()
    return success(user.to_dict(), "Profile updated")


@bp.put("/password")
@jwt_required()
def change_password():
    user = _current_user()
    data = request.get_json(silent=True) or {}
    errors = require_fields(data, ["current_password", "new_password"])
    if data.get("new_password") and len(data["new_password"]) < 6:
        errors["new_password"] = "Password must be at least 6 characters"
    if errors:
        return error("Validation failed", 422, errors)
    if not bcrypt.check_password_hash(user.password_hash, data["current_password"]):
        return error("Validation failed", 422, {"current_password": "Current password is incorrect"})
    if data["current_password"] == data["new_password"]:
        return error("Validation failed", 422, {"new_password": "Choose a different password"})

    user.password_hash = bcrypt.generate_password_hash(data["new_password"]).decode()
    db.session.commit()
    return success(None, "Password changed")


@bp.post("/avatar")
@jwt_required()
def upload_avatar():
    user = _current_user()
    file = request.files.get("file")
    if not file:
        return error("Validation failed", 422, {"file": "Please choose a photo"})

    content = file.read(MAX_AVATAR_BYTES + 1)
    if len(content) > MAX_AVATAR_BYTES:
        return error("Validation failed", 422, {"file": "Photo must be 5 MB or smaller"})
    ext = next((e for sig, e in IMAGE_SIGNATURES.items() if content.startswith(sig)), None)
    if ext is None and content[:4] == b"RIFF" and content[8:12] == b"WEBP":
        ext = "webp"
    if ext is None:
        return error("Validation failed", 422, {"file": "Use a JPG, PNG or WebP image"})

    # Random file name - never trust the client's name
    folder = os.path.join(current_app.config["UPLOAD_FOLDER"], "avatars")
    os.makedirs(folder, exist_ok=True)
    name = f"{uuid.uuid4().hex}.{ext}"
    with open(os.path.join(folder, name), "wb") as f:
        f.write(content)

    old = user.avatar_url
    user.avatar_url = f"/uploads/avatars/{name}"
    db.session.commit()
    if old and old.startswith("/uploads/avatars/"):
        try:
            os.remove(os.path.join(current_app.config["UPLOAD_FOLDER"], old.removeprefix("/uploads/")))
        except OSError:
            pass
    return success(user.to_dict(), "Photo updated")


PREFERENCES = ("notify_orders", "notify_offers", "notify_news")


@bp.get("/preferences")
@jwt_required()
def get_preferences():
    """Settings > Notify me about."""
    user = _current_user()
    if not user:
        return error("User not found", 404)
    return success({k: getattr(user, k) for k in PREFERENCES})


@bp.put("/preferences")
@jwt_required()
def update_preferences():
    """Body: any of {"notify_orders": true, "notify_offers": false, "notify_news": true}."""
    user = _current_user()
    if not user:
        return error("User not found", 404)
    data = request.get_json(silent=True) or {}
    bad = {k: "Must be true or false" for k in PREFERENCES if k in data and not isinstance(data[k], bool)}
    if bad:
        return error("Validation failed", 422, bad)
    for k in PREFERENCES:
        if k in data:
            setattr(user, k, data[k])
    db.session.commit()
    return success({k: getattr(user, k) for k in PREFERENCES}, "Saved")
