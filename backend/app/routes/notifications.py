from flask import Blueprint
from flask_jwt_extended import get_jwt_identity, jwt_required
from sqlalchemy.orm import selectinload

from ..extensions import db
from ..models import Notification, Order, OrderItem
from ..utils.responses import error, success

bp = Blueprint("notifications", __name__, url_prefix="/api/notifications")


def _user_id():
    return int(get_jwt_identity())


def _mine():
    return Notification.query.filter_by(user_id=_user_id())


def _unread():
    return _mine().filter_by(is_read=False).count()


@bp.get("")
@jwt_required()
def list_notifications():
    """Newest first, with the unread count (for the bell badge)."""
    items = (
        _mine()
        .options(selectinload(Notification.order).selectinload(Order.items).selectinload(OrderItem.product))
        .order_by(Notification.created_at.desc(), Notification.id.desc())
        .limit(100)
        .all()
    )
    return success({"items": [n.to_dict() for n in items], "unread": _unread()})


@bp.get("/unread-count")
@jwt_required()
def unread_count():
    return success({"unread": _unread()})


@bp.post("/read-all")
@jwt_required()
def read_all():
    _mine().filter_by(is_read=False).update({"is_read": True})
    db.session.commit()
    return success({"unread": 0}, "All caught up")


@bp.post("/<int:notification_id>/read")
@jwt_required()
def read_one(notification_id):
    n = _mine().filter_by(id=notification_id).first()
    if not n:
        return error("Notification not found", 404)
    n.is_read = True
    db.session.commit()
    return success({"unread": _unread()})


@bp.delete("/<int:notification_id>")
@jwt_required()
def delete_one(notification_id):
    n = _mine().filter_by(id=notification_id).first()
    if not n:
        return error("Notification not found", 404)
    db.session.delete(n)
    db.session.commit()
    return success({"unread": _unread()}, "Deleted")
