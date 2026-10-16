"""Shop-owner actions shared by the admin API (/api/admin) and the web panel (/admin),
so both send the same notifications and keep stock right. Callers handle AdminError."""
from sqlalchemy import func

from . import notify
from .extensions import db
from .models import Category, ContactMessage, Order, Product, User
from .utils.clock import utcnow


class AdminError(ValueError):
    """A shop-owner action that is not allowed, with a message to show."""


# Where an order can go next. Delivered and cancelled orders are finished.
ORDER_STEPS = {
    "pending": ("confirmed", "cancelled"),
    "confirmed": ("shipped", "cancelled"),
    "shipped": ("delivered",),
    "delivered": (),
    "cancelled": (),
}


def next_statuses(order):
    """Statuses the shop can move this order to. An unpaid KHQR order waits for its payment."""
    if order.status == "pending" and order.payment_method == "khqr" and order.payment_status != "paid":
        return ("cancelled",)
    return ORDER_STEPS[order.status]


def restock(order):
    """Puts a cancelled order's items back on sale."""
    for item in order.items:
        if item.product_id:
            product = db.session.get(Product, item.product_id)
            if product:
                product.stock += item.quantity


def set_order_status(order, status):
    """Moves an order one step on and tells the customer. Commits."""
    if status not in ORDER_STEPS:
        raise AdminError(f"Unknown status: {status}")
    if status not in next_statuses(order):
        raise AdminError(f"A {order.status} order cannot be marked {status}")

    order.status = status
    if status == "confirmed":
        notify.order_event(order, "confirmed")
    elif status == "shipped":
        notify.order_event(order, "ready" if order.delivery_method == "pickup" else "shipped")
    elif status == "delivered":
        if order.payment_method == "cod":
            order.payment_status = "paid"  # cash collected at the door
        notify.order_event(order, "delivered")
    elif status == "cancelled":
        restock(order)
        for payment in order.payments:
            if payment.status == "pending":
                payment.status = "expired"
        notify.order_event(order, "cancelled")
    db.session.commit()
    return order


def set_customer_active(user, active):
    """Blocks or unblocks a customer. A blocked customer cannot log in, and their
    current token stops working. Commits."""
    if user.role == "admin":
        raise AdminError("Admin accounts cannot be blocked")
    user.is_active = bool(active)
    db.session.commit()
    return user


def delete_category(category):
    """Only an empty category can go; move or hide its products first. Commits."""
    if category.products:
        raise AdminError(f"{category.name} still has {len(category.products)} product(s)")
    db.session.delete(category)
    db.session.commit()


def reply_contact(message, text):
    """Answers a Contact message; the customer gets it in Notifications. Commits."""
    text = (text or "").strip()
    if not text:
        raise AdminError("Write a reply")
    message.reply, message.status, message.replied_at = text, "answered", utcnow()
    notify.support_reply(message)
    db.session.commit()
    return message


def stats():
    """Numbers for the dashboard."""
    paid = Order.query.filter(Order.payment_status == "paid", Order.status != "cancelled")
    return {
        "products": Product.query.filter_by(is_active=True).count(),
        "low_stock": Product.query.filter(Product.is_active.is_(True), Product.stock <= 3).count(),
        "categories": Category.query.count(),
        "customers": User.query.filter_by(role="customer").count(),
        "orders": Order.query.count(),
        "orders_to_handle": Order.query.filter(Order.status.in_(["pending", "confirmed"])).count(),
        "revenue": float(paid.with_entities(func.coalesce(func.sum(Order.total), 0)).scalar()),
        "open_messages": ContactMessage.query.filter_by(status="open").count(),
    }
