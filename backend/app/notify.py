"""Messages for the Notifications screen. Callers commit."""
from .extensions import db
from .models import Notification

# event -> (type, title, message); {number} and {total} come from the order
ORDER_TEXT = {
    "placed_cod": ("Order placed", "We got order {number}. Pay {total} when it arrives."),
    "placed_khqr": ("Pay to confirm your order", "Scan the KHQR for {number} ({total}) within 15 minutes."),
    "paid": ("Payment received", "{total} for {number} by KHQR. We are packing it now."),
    "confirmed": ("Order confirmed", "We are packing order {number} now."),
    "shipped": ("Your order is on the way", "Order {number} arrives tomorrow, 9:00 - 18:00."),
    "ready": ("Ready to pick up", "Order {number} is waiting for you at our Toul Kork shop."),
    "delivered": ("Delivered! Enjoy your order", "How is it? Tell other collectors about order {number}."),
    "cancelled": ("Order cancelled", "Order {number} was not paid in time, so we put the items back on sale."),
}


def order_event(order, key):
    """Adds the message for one step of an order (key from ORDER_TEXT)."""
    title, text = ORDER_TEXT[key]
    event = key.split("_")[0] if key.startswith("placed") else ("shipped" if key == "ready" else key)
    db.session.add(Notification(
        user_id=order.user_id, type="order", event=event, order_id=order.id, title=title,
        message=text.format(number=order.order_number, total=f"${float(order.total):g}"),
    ))


def welcome(user_id):
    db.session.add(Notification(
        user_id=user_id, type="promo", event="welcome", promo_code="WELCOME10",
        title="Welcome to Anime World Shop", message="Here is 10% off your first order.",
    ))


def promo(user_id, title, message, code):
    db.session.add(Notification(user_id=user_id, type="promo", event="promo", promo_code=code, title=title, message=message))


def news(user_id, title, message):
    db.session.add(Notification(user_id=user_id, type="system", event="news", title=title, message=message))
