from flask import Blueprint, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from ..extensions import db, limiter
from ..models import ContactMessage, Order
from ..utils.responses import error, success
from ..utils.validators import json_body

bp = Blueprint("contact", __name__, url_prefix="/api/contact")

MAX_LENGTH = 1000


def _user_id():
    return int(get_jwt_identity())


def _sender():
    """Rate-limit key: the logged-in account (so one person can't flood the shop's inbox)."""
    return f"contact:{get_jwt_identity()}"


@bp.get("")
@jwt_required()
def list_messages():
    """The customer's own messages, newest first."""
    items = (
        ContactMessage.query.filter_by(user_id=_user_id())
        .order_by(ContactMessage.created_at.desc(), ContactMessage.id.desc())
        .limit(50)
        .all()
    )
    return success([m.to_dict() for m in items])


@bp.post("")
@jwt_required()
@limiter.limit("5 per 10 minutes;30 per day", key_func=_sender,
               error_message="You have sent a lot of messages. Please wait for our reply before sending more.")
def send_message():
    """Body: {topic: order|payment|product|other, message, order_id?}. The order is
    only kept for order and payment questions, and must be one of the customer's."""
    data = json_body()
    topic = data.get("topic") or "other"
    raw = data.get("message")
    text = raw.strip() if isinstance(raw, str) else ""
    errors = {}
    if not isinstance(topic, str) or topic not in ContactMessage.TOPICS:
        errors["topic"] = "Pick what the message is about"
    if raw is not None and not isinstance(raw, str):
        errors["message"] = "The message must be text"
    elif not text:
        errors["message"] = "Write your message"
    elif len(text) > MAX_LENGTH:
        errors["message"] = f"Keep it under {MAX_LENGTH} characters"
    if errors:
        return error("Please check the message", 422, errors)

    order = None
    if topic in ("order", "payment") and data.get("order_id") is not None:
        order_id = data["order_id"]
        if not isinstance(order_id, int) or isinstance(order_id, bool):
            return error("Please check the message", 422, {"order_id": "Pick one of your orders"})
        order = Order.query.filter_by(id=order_id, user_id=_user_id()).first()
        if order is None:
            return error("Order not found", 404)

    msg = ContactMessage(user_id=_user_id(), topic=topic, message=text, order=order)
    db.session.add(msg)
    db.session.commit()
    return success(msg.to_dict(), "Message sent", 201)
