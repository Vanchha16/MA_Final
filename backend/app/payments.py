"""Online payments for orders: Bakong KHQR, or ABA PayWay (which also shows a
KHQR and can open ABA Mobile).

Every place that can see a payment (the app polling, the order list) goes
through refresh(), so "mark paid" and "expire" happen in exactly one way.
"""
import hashlib
from datetime import timedelta

from bakong_khqr import KHQR
from flask import current_app, url_for

from . import notify, payway
from .extensions import db
from .models import Payment
from .utils.clock import utcnow


def _khqr():
    return KHQR(current_app.config["BAKONG_TOKEN"] or None)


def is_set_up(method):
    """True when the server has the keys for "khqr" (Bakong) or "aba" (PayWay)."""
    cfg = current_app.config
    if method == "aba":
        return bool(cfg["PAYWAY_MERCHANT_ID"] and cfg["PAYWAY_API_KEY"])
    return bool(cfg["BAKONG_ACCOUNT_ID"])


def active_payment(order):
    return Payment.query.filter_by(order_id=order.id).order_by(Payment.id.desc()).first()


def _bakong_qr(order):
    cfg = current_app.config
    created = _khqr().create_qr(
        account_id=cfg["BAKONG_ACCOUNT_ID"],
        merchant_name=cfg["KHQR_MERCHANT_NAME"],
        merchant_city=cfg["KHQR_MERCHANT_CITY"],
        amount=float(order.total),
        currency="USD",
        bill_number=order.order_number,
        store_label="AnimeWorld",
    )
    return {"provider": "bakong", "qr": created.qr, "md5": created.md5}


def _payway_qr(order):
    """Raises payway.PaywayError when PayWay says no."""
    tran_id = payway.new_tran_id(order)
    callback = current_app.config["PAYWAY_CALLBACK_URL"] or url_for("orders.payway_callback", _external=True)
    made = payway.purchase(order, tran_id, callback)
    return {"provider": "payway", "qr": made["qr"], "md5": hashlib.md5(made["qr"].encode()).hexdigest(),
            "tran_id": tran_id, "deeplink": made["deeplink"]}


def start(order):
    """The order's payment, made once and reused (a new QR would be a new transaction)."""
    payment = active_payment(order)
    if payment:
        return refresh(order, payment)
    cfg = current_app.config
    made = _payway_qr(order) if order.payment_method == "aba" else _bakong_qr(order)
    payment = Payment(
        order_id=order.id,
        **made,
        amount=order.total,
        currency="USD",
        expires_at=utcnow() + timedelta(minutes=cfg["KHQR_MINUTES"]),
    )
    db.session.add(payment)
    db.session.commit()
    return payment


def _is_paid(payment):
    """Asks the bank. Network or key problems count as "not paid yet", never as an error."""
    try:
        if payment.provider == "payway":
            return payway.is_paid(payment.tran_id)
        return str(_khqr().check_payment(payment.md5)).upper() == "PAID"
    except Exception as exc:  # noqa: BLE001 - the SDKs raise plain exceptions
        current_app.logger.warning("%s check failed for order %s: %s", payment.provider, payment.order_id, exc)
        return False


def mark_paid(order, payment):
    if payment.status == "paid":
        return payment
    payment.status = "paid"
    payment.paid_at = utcnow()
    order.payment_status = "paid"
    if order.status == "pending":
        order.status = "confirmed"
    notify.order_event(order, "paid")
    db.session.commit()
    return payment


def expire(order, payment):
    """Cancels the unpaid order and puts its stock back."""
    payment.status = "expired"
    if order.status == "pending":
        from .admin_ops import cancel_order

        cancel_order(order, "system")
    db.session.commit()
    return payment


def refresh(order, payment=None):
    """Checks the payment once: marks it paid, or expires it when its time is up.
    The bank is asked first, so money paid just before the deadline still counts."""
    payment = payment or active_payment(order)
    if payment is None or payment.status != "pending":
        return payment
    if _is_paid(payment):
        return mark_paid(order, payment)
    if utcnow() >= payment.expires_at:
        return expire(order, payment)
    return payment
