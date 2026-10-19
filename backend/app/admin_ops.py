"""Shop-owner actions shared by the admin API (/api/admin) and the web panel (/admin),
so both send the same notifications and keep stock right. Callers handle AdminError."""
from datetime import timedelta

from sqlalchemy import func
from sqlalchemy.orm import selectinload

from . import notify
from .extensions import db
from .models import Category, ContactMessage, Order, OrderItem, Product, Review, User
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


PAY_NAMES = {"khqr": "KHQR", "aba": "ABA PayWay"}


def next_statuses(order):
    """Statuses the shop can move this order to. An unpaid online order waits for its payment."""
    if order.status == "pending" and order.payment_method != "cod" and order.payment_status != "paid":
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
    if not isinstance(status, str) or status not in ORDER_STEPS:
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
    text = text.strip() if isinstance(text, str) else ""
    if not text:
        raise AdminError("Write a reply")
    if len(text) > 2000:
        raise AdminError("Keep the reply under 2000 characters")
    message.reply, message.status, message.replied_at = text, "answered", utcnow()
    notify.support_reply(message)
    db.session.commit()
    return message


def _paid_on(order):
    """When the money came in: the KHQR payment time, else when the order was placed."""
    times = [p.paid_at for p in order.payments if p.paid_at]
    return max(times) if times else order.created_at


def stats():
    """Numbers for the dashboard, with paid revenue for each of the last 7 days (UTC, oldest first)."""
    paid = Order.query.filter(Order.payment_status == "paid", Order.status != "cancelled")
    today = utcnow().date()
    days = [today - timedelta(days=n) for n in range(6, -1, -1)]
    per_day = dict.fromkeys(days, 0.0)
    for order in paid.filter(Order.created_at >= utcnow() - timedelta(days=14)).options(selectinload(Order.payments)):
        day = _paid_on(order).date()
        if day in per_day:
            per_day[day] += float(order.total)
    return {
        "week": [{"date": d.isoformat(), "revenue": round(v, 2)} for d, v in per_day.items()],
        "week_revenue": round(sum(per_day.values()), 2),
        "products": Product.query.filter_by(is_active=True).count(),
        "low_stock": Product.query.filter(Product.is_active.is_(True), Product.stock <= 3).count(),
        "categories": Category.query.count(),
        "customers": User.query.filter_by(role="customer").count(),
        "orders": Order.query.count(),
        "orders_to_handle": Order.query.filter(Order.status.in_(["pending", "confirmed"])).count(),
        "revenue": float(paid.with_entities(func.coalesce(func.sum(Order.total), 0)).scalar()),
        "open_messages": ContactMessage.query.filter_by(status="open").count(),
    }


def _first_photo(order):
    item = next((i for i in order.items if i.product is not None and i.product.photo_url), None)
    return item.product.photo_url if item else None


def activity(limit=20):
    """What just happened, newest first: payments, new orders, Contact messages and sold-out
    products. `action` is what the shop can do about it now (None once it has been handled)."""
    events = []
    orders = (
        Order.query.options(selectinload(Order.items).selectinload(OrderItem.product), selectinload(Order.payments), selectinload(Order.user))
        .order_by(Order.created_at.desc()).limit(30).all()
    )
    for o in orders:
        name, total = o.user.full_name, f"${float(o.total):,.2f}"
        base = {"order_id": o.id, "order_number": o.order_number, "status": o.status, "image_url": _first_photo(o)}
        paid = next((p for p in o.payments if p.status == "paid"), None)
        if paid is not None:
            events.append({**base, "id": f"paid-{o.id}", "kind": "paid", "at": paid.paid_at, "title": "Payment received",
                           "message": f"{name} paid {total} by {PAY_NAMES.get(o.payment_method, 'KHQR')}", "action": "ship" if o.status == "confirmed" else None})
        pay = "cash" if o.payment_method == "cod" else PAY_NAMES.get(o.payment_method, "KHQR")
        events.append({**base, "id": f"order-{o.id}", "kind": "order", "at": o.created_at, "title": f"New order {o.order_number}",
                       "message": f"{name} · {total} · {pay}",
                       "action": "confirm" if o.status == "pending" and o.payment_method == "cod" else
                                 "ship" if o.status == "confirmed" and paid is None else None})
    for m in ContactMessage.query.order_by(ContactMessage.created_at.desc()).limit(10):
        events.append({"id": f"message-{m.id}", "kind": "message", "at": m.created_at, "title": "New message",
                       "message": f'"{m.message[:90]}"', "message_id": m.id, "status": m.status,
                       "action": "reply" if m.status == "open" else None, "image_url": None})
    for r in Review.query.order_by(Review.created_at.desc()).limit(10):
        events.append({"id": f"review-{r.id}", "kind": "review", "at": r.created_at, "title": "New review",
                       "message": f"{r.user.full_name} gave {r.product.name} {r.rating} star{'s' if r.rating != 1 else ''}",
                       "product_id": r.product_id, "rating": r.rating, "action": None, "image_url": r.product.photo_url})
    for p in Product.query.filter(Product.is_active.is_(True), Product.stock <= 0).options(selectinload(Product.images)).limit(10):
        events.append({"id": f"stock-{p.id}", "kind": "sold_out", "at": p.updated_at, "title": "Sold out",
                       "message": f"{p.name} has 0 left", "product_id": p.id, "action": "restock", "image_url": p.photo_url})
    events.sort(key=lambda e: e["at"], reverse=True)
    for e in events:
        e["at"] = e["at"].isoformat() + "Z"
    return events[:limit]
