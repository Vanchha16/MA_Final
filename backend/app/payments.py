"""Bakong KHQR payments for orders.

Every place that can see a payment (the app polling, the order list) goes
through refresh(), so "mark paid" and "expire" happen in exactly one way.
"""
from datetime import timedelta

from bakong_khqr import KHQR
from flask import current_app

from . import notify
from .extensions import db
from .models import Payment
from .utils.clock import utcnow


def _khqr():
    return KHQR(current_app.config["BAKONG_TOKEN"] or None)


def active_payment(order):
    return Payment.query.filter_by(order_id=order.id).order_by(Payment.id.desc()).first()


def start(order):
    """The order's KHQR payment, made once and reused (a new QR would be a new transaction)."""
    payment = active_payment(order)
    if payment:
        return refresh(order, payment)
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
    payment = Payment(
        order_id=order.id,
        provider="bakong",
        qr=created.qr,
        md5=created.md5,
        amount=order.total,
        currency="USD",
        expires_at=utcnow() + timedelta(minutes=cfg["KHQR_MINUTES"]),
    )
    db.session.add(payment)
    db.session.commit()
    return payment


def _paid_on_bakong(payment):
    """Network or token problems count as "not paid yet", never as an error."""
    try:
        return str(_khqr().check_payment(payment.md5)).upper() == "PAID"
    except Exception as exc:  # noqa: BLE001 - the SDK raises plain exceptions
        current_app.logger.warning("Bakong check failed for %s: %s", payment.md5, exc)
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
        from .admin_ops import restock

        order.status = "cancelled"
        restock(order)
        notify.order_event(order, "cancelled")
    db.session.commit()
    return payment


def refresh(order, payment=None):
    """Checks the payment once: marks it paid, or expires it when its time is up.
    Bakong is asked first, so money paid just before the deadline still counts."""
    payment = payment or active_payment(order)
    if payment is None or payment.status != "pending":
        return payment
    if _paid_on_bakong(payment):
        return mark_paid(order, payment)
    if utcnow() >= payment.expires_at:
        return expire(order, payment)
    return payment
