"""Real-time updates over Socket.IO (Flask-SocketIO).

The app and the web admin open one socket after login (auth: {"token": "<JWT>"}).
Each user joins the room "user:<id>"; staff and admins also join "staff".

The server pushes small signals; clients then load the new data with the normal REST
calls, so the socket never has to repeat the API's JSON:

    notification   -> the customer   {"id", "type"}                 a new message
    order_updated  -> the customer   {"order_id", "order_number",   placed, paid, shipped,
                      and staff       "status", "payment_status"}    cancelled, refunded ...
    admin_update   -> staff          {"kind": "message"|"review"}   something new for the dashboard

Events are sent after the database commit (never for a rolled-back change), from
SQLAlchemy session hooks, so no route has to remember to send them.

Bakong KHQR has no callback, so a background task asks the bank about pending online
payments every few seconds; a payment found paid is committed and pushed like any change.
"""
import threading

from flask import current_app, request
from flask_jwt_extended import decode_token
from flask_socketio import ConnectionRefusedError, SocketIO, join_room
from sqlalchemy import event
from sqlalchemy.orm import Session

socketio = SocketIO(cors_allowed_origins="*", async_mode="threading")

STAFF_ROOM = "staff"
TEAM_ROLES = ("staff", "admin")
WATCH_SECONDS = 3  # how often pending online payments are checked with the bank


def user_room(user_id):
    return f"user:{user_id}"


# ---------- Connecting ----------

@socketio.on("connect")
def on_connect(auth=None):
    """Only logged-in users with a token that still works (same rules as the REST API)."""
    from .extensions import db
    from .models import User

    token = (auth or {}).get("token") if isinstance(auth, dict) else None
    token = token or request.args.get("token")
    if not token:
        raise ConnectionRefusedError("Log in first")
    try:
        claims = decode_token(token)
        user = db.session.get(User, int(claims["sub"]))
    except Exception:  # noqa: BLE001 - expired, forged or not a token at all
        raise ConnectionRefusedError("Your login has expired. Please log in again.")
    if user is None or not user.is_active or claims.get("ver", 0) != user.token_version:
        raise ConnectionRefusedError("Your login has expired. Please log in again.")
    join_room(user_room(user.id))
    if user.role in TEAM_ROLES:
        join_room(STAFF_ROOM)
    _start_payment_watcher()


# ---------- Sending changes after commit ----------

def _pending(session):
    return session.info.setdefault("realtime", {})


@event.listens_for(Session, "after_flush")
def _collect(session, _flush_context):
    """Notes what changed in this flush. Values are read now, while the rows are loaded."""
    from .models import ContactMessage, Notification, Order, Review

    pending = _pending(session)
    for obj in list(session.new) + [o for o in session.dirty if session.is_modified(o)]:
        if isinstance(obj, Notification) and obj in session.new:
            pending[("notification", obj.id)] = (
                "notification", {"id": obj.id, "type": obj.type}, [user_room(obj.user_id)])
        elif isinstance(obj, Order):
            pending[("order", obj.id)] = ("order_updated", {
                "order_id": obj.id, "order_number": obj.order_number,
                "status": obj.status, "payment_status": obj.payment_status,
            }, [user_room(obj.user_id), STAFF_ROOM])
        elif isinstance(obj, ContactMessage) and obj in session.new:
            pending[("message", obj.id)] = ("admin_update", {"kind": "message"}, [STAFF_ROOM])
        elif isinstance(obj, Review) and obj in session.new:
            pending[("review", obj.id)] = ("admin_update", {"kind": "review"}, [STAFF_ROOM])


@event.listens_for(Session, "after_commit")
def _send(session):
    for name, payload, rooms in session.info.pop("realtime", {}).values():
        for room in rooms:
            socketio.emit(name, payload, to=room)


@event.listens_for(Session, "after_rollback")
def _forget(session):
    session.info.pop("realtime", None)


# ---------- Watching pending payments ----------

_watcher_lock = threading.Lock()
_watcher_started = False


def _start_payment_watcher():
    """Starts once, when the first socket connects (not in tests or CLI commands)."""
    global _watcher_started
    app = current_app._get_current_object()
    if app.config.get("TESTING") or not app.config.get("PAYMENT_WATCHER", True):
        return
    with _watcher_lock:
        if _watcher_started:
            return
        _watcher_started = True
    socketio.start_background_task(_watch_payments, app)


def check_pending_payments():
    """One round: each pending online payment is asked about once (paid, expired or still waiting)."""
    from . import payments
    from .models import Payment

    for payment in Payment.query.filter_by(status="pending").all():
        payments.refresh(payment.order, payment)


def _watch_payments(app):
    while True:
        socketio.sleep(WATCH_SECONDS)
        with app.app_context():
            try:
                check_pending_payments()
            except Exception:  # noqa: BLE001 - keep watching after a database or network hiccup
                app.logger.exception("Payment watcher failed")
            finally:
                from .extensions import db

                db.session.rollback()
                db.session.remove()
