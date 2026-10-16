from flask import Blueprint, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from ..extensions import db
from ..models import ContactMessage, Order
from ..utils.responses import error, success

bp = Blueprint("contact", __name__, url_prefix="/api/contact")

MAX_LENGTH = 1000


def _user_id():
    return int(get_jwt_identity())


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
def send_message():
    """Body: {topic: order|payment|product|other, message, order_id?}. The order is
    only kept for order and payment questions, and must be one of the customer's."""
    data = request.get_json(silent=True) or {}
    topic = data.get("topic") or "other"
    text = str(data.get("message") or "").strip()
    errors = {}
    if topic not in ContactMessage.TOPICS:
        errors["topic"] = "Pick what the message is about"
    if not text:
        errors["message"] = "Write your message"
    elif len(text) > MAX_LENGTH:
        errors["message"] = f"Keep it under {MAX_LENGTH} characters"
    if errors:
        return error("Please check the message", 422, errors)

    order = None
    if topic in ("order", "payment") and data.get("order_id") is not None:
        order = Order.query.filter_by(id=data["order_id"], user_id=_user_id()).first()
        if order is None:
            return error("Order not found", 404)

    msg = ContactMessage(user_id=_user_id(), topic=topic, message=text, order=order)
    db.session.add(msg)
    db.session.commit()
    return success(msg.to_dict(), "Message sent", 201)
