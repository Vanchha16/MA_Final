import io
import os
import uuid

from flask import Blueprint, current_app, request
from flask_jwt_extended import get_jwt_identity, jwt_required
from PIL import Image, ImageOps, UnidentifiedImageError
from sqlalchemy import func

from ..extensions import bcrypt, db
from ..models import Favorite, Order, OrderItem, Review, User
from ..utils.responses import error, success
from ..utils.validators import Fields, json_body
from .auth import token_for

bp = Blueprint("profile", __name__, url_prefix="/api/profile")

# Loyalty tiers: 1 point per $1 spent on delivered orders
TIERS = [("Bronze", 0), ("Silver", 500), ("Gold", 2000), ("Platinum", 5000)]

# First bytes of the image types we accept
IMAGE_SIGNATURES = {
    b"\x89PNG\r\n\x1a\n": "png",
    b"\xff\xd8\xff": "jpg",
}
MAX_AVATAR_BYTES = 5 * 1024 * 1024
AVATAR_SIDE = 512  # saved as a WebP at most this wide


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
    f = Fields(json_body())
    name = f.person_name("full_name")
    phone = f.phone()
    if f.errors:
        return error("Validation failed", 422, f.errors)

    user.full_name = name
    user.phone = phone
    db.session.commit()
    return success(user.to_dict(), "Profile updated")


@bp.put("/password")
@jwt_required()
def change_password():
    user = _current_user()
    f = Fields(json_body())
    current = f.text("current_password", required=True, strip=False, max_len=200, label="Current password")
    new = f.password("new_password", label="New password")
    if f.errors:
        return error("Validation failed", 422, f.errors)
    if not bcrypt.check_password_hash(user.password_hash, current):
        return error("Validation failed", 422, {"current_password": "Current password is incorrect"})
    if current == new:
        return error("Validation failed", 422, {"new_password": "Choose a different password"})

    user.password_hash = bcrypt.generate_password_hash(new).decode()
    user.token_version += 1  # other devices are signed out
    db.session.commit()
    # a fresh token so this device stays logged in
    return success({"token": token_for(user)}, "Password changed")


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
    # The first bytes can be faked: the file must also open as a picture.
    # Saving it again as WebP drops anything hidden in it (and the camera's location data).
    try:
        with Image.open(io.BytesIO(content)) as probe:
            probe.verify()
        with Image.open(io.BytesIO(content)) as img:
            img = ImageOps.exif_transpose(img).convert("RGB")
            img.thumbnail((AVATAR_SIDE, AVATAR_SIDE))
            out = io.BytesIO()
            img.save(out, "WEBP", quality=88)
    except (UnidentifiedImageError, OSError, SyntaxError, ValueError, Image.DecompressionBombError):
        return error("Validation failed", 422, {"file": "This photo could not be opened"})

    # Random file name - never trust the client's name
    folder = os.path.join(current_app.config["UPLOAD_FOLDER"], "avatars")
    os.makedirs(folder, exist_ok=True)
    name = f"{uuid.uuid4().hex}.webp"
    with open(os.path.join(folder, name), "wb") as fh:
        fh.write(out.getvalue())

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
    data = json_body()
    bad = {k: "Must be true or false" for k in PREFERENCES if k in data and not isinstance(data[k], bool)}
    if bad:
        return error("Validation failed", 422, bad)
    for k in PREFERENCES:
        if k in data:
            setattr(user, k, data[k])
    db.session.commit()
    return success({k: getattr(user, k) for k in PREFERENCES}, "Saved")
