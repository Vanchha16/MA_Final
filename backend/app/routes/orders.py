import uuid

from flask import Blueprint, current_app, request
from flask_jwt_extended import get_jwt_identity, jwt_required
from sqlalchemy import select, update
from sqlalchemy.orm import selectinload

from .. import notify, payments
from ..extensions import db
from ..models import Address, CartItem, Order, OrderItem, Product, Review, User
from ..pricing import DELIVERY_METHODS, find_coupon, shipping_for, summarize
from ..utils.clock import utcnow
from ..utils.responses import error, success
from ..utils.validators import Fields, json_body

bp = Blueprint("orders", __name__, url_prefix="/api")

PAYMENT_METHODS = ("cod", "khqr")
STORE = {"name": "Anime World Shop", "address": "#88 St. 315, Boeung Kak 2, Toul Kork, Phnom Penh", "hours": "9:00 - 20:00"}


def _user_id():
    return int(get_jwt_identity())


# ---------- Addresses ----------

def _own_address(address_id):
    return Address.query.filter_by(id=address_id, user_id=_user_id()).first()


def _addresses(user_id):
    return Address.query.filter_by(user_id=user_id).order_by(Address.is_default.desc(), Address.id.desc()).all()


def _read_address(data):
    """Checks an address body; returns (fields, errors). Text longer than its column is refused, not cut."""
    f = Fields(data)
    fields = {
        "label": f.text("label", max_len=50, label="Label") or "Home",
        "recipient_name": f.person_name("recipient_name"),
        "phone": f.phone(required=True),
        "street": f.text("street", required=True, max_len=255, label="Street address"),
        "city": f.text("city", required=True, max_len=100, label="District"),
        "province": f.text("province", max_len=100, label="Province"),
        "postal_code": f.text("postal_code", max_len=20, label="Postal code"),
    }
    if f.has("is_default") and data["is_default"] is not None:
        f.boolean("is_default")
    return fields, f.errors


def _fill(address, fields):
    for name, value in fields.items():
        setattr(address, name, value)


def _make_default(address):
    Address.query.filter(Address.user_id == address.user_id, Address.id != address.id).update({"is_default": False})
    address.is_default = True


@bp.get("/addresses")
@jwt_required()
def list_addresses():
    return success([a.to_dict() for a in _addresses(_user_id())])


@bp.post("/addresses")
@jwt_required()
def add_address():
    data = json_body()
    fields, errors = _read_address(data)
    if errors:
        return error("Validation failed", 422, errors)
    user_id = _user_id()
    address = Address(user_id=user_id)
    _fill(address, fields)
    db.session.add(address)
    db.session.flush()
    # The first address, or one marked default, becomes the default
    if data.get("is_default") is True or Address.query.filter_by(user_id=user_id).count() == 1:
        _make_default(address)
    db.session.commit()
    return success(address.to_dict(), "Address saved", 201)


@bp.put("/addresses/<int:address_id>")
@jwt_required()
def update_address(address_id):
    address = _own_address(address_id)
    if not address:
        return error("Address not found", 404)
    data = json_body()
    fields, errors = _read_address(data)
    if errors:
        return error("Validation failed", 422, errors)
    _fill(address, fields)
    if data.get("is_default") is True:
        _make_default(address)
    db.session.commit()
    return success(address.to_dict(), "Address updated")


@bp.delete("/addresses/<int:address_id>")
@jwt_required()
def delete_address(address_id):
    address = _own_address(address_id)
    if not address:
        return error("Address not found", 404)
    user_id, was_default = address.user_id, address.is_default
    db.session.delete(address)
    db.session.flush()
    if was_default:
        newest = Address.query.filter_by(user_id=user_id).order_by(Address.id.desc()).first()
        if newest:
            newest.is_default = True
    db.session.commit()
    return success([a.to_dict() for a in _addresses(user_id)], "Address removed")


# ---------- Checkout ----------

def _cart_items(user_id):
    return CartItem.query.filter_by(user_id=user_id).options(selectinload(CartItem.product)).order_by(CartItem.created_at.desc()).all()


def _delivery_options(subtotal):
    return [
        {"id": "standard", "label": "Standard", "detail": "Tomorrow, 9:00 - 18:00", "fee": shipping_for(subtotal)},
        {"id": "pickup", "label": "Store pickup", "detail": "Today at Toul Kork", "fee": 0.0},
    ]


@bp.get("/checkout")
@jwt_required()
def checkout_preview():
    """Everything the Checkout screen shows. ?coupon=CODE&delivery=standard|pickup"""
    user_id = _user_id()
    delivery = request.args.get("delivery", "standard")
    if delivery not in DELIVERY_METHODS:
        delivery = "standard"
    items = _cart_items(user_id)
    summary = summarize(items, request.args.get("coupon"), delivery)
    return success({
        "items": [i.to_dict() for i in items],
        **summary,
        "delivery_method": delivery,
        "delivery_options": _delivery_options(summary["subtotal"]),
        "addresses": [a.to_dict() for a in _addresses(user_id)],
        "store": STORE,
    })


def _order_number(order):
    """AWS-<date>-<id>: built from the order's own id, so two orders placed at the same
    moment can never get the same number (five digits keep it apart from older numbers)."""
    return f"AWS-{order.created_at:%Y%m%d}-{order.id:05d}"


@bp.post("/orders")
@jwt_required()
def place_order():
    """Body: {"address_id": 1, "delivery_method": "standard", "payment_method": "khqr", "coupon": "WELCOME10", "note": ""}.
    Turns the cart into an order, lowers stock and empties the cart."""
    data = json_body()
    user_id = _user_id()
    f = Fields(data)
    delivery = f.choice("delivery_method", DELIVERY_METHODS, default="standard", message="Choose Standard or Store pickup")
    payment = f.choice("payment_method", PAYMENT_METHODS, required=True, message="Choose KHQR or Cash on delivery")
    code = f.text("coupon", max_len=30, label="Promo code")
    note = f.text("note", max_len=255, label="The note")
    address_id = data.get("address_id")
    address = _own_address(address_id) if isinstance(address_id, int) and not isinstance(address_id, bool) else None
    if delivery == "standard" and not address:
        f.errors["address_id"] = "Choose a delivery address"
    if f.errors:
        return error("Validation failed", 422, f.errors)

    items = _cart_items(user_id)
    if not items:
        return error("Your cart is empty", 409)
    problems = [
        f"{i.product.name} is sold out" if i.product.stock <= 0 or not i.product.is_active
        else f"Only {i.product.stock} left of {i.product.name}"
        for i in items if not i.product.is_active or i.quantity > i.product.stock
    ]
    if problems:
        return error("Some items changed. " + "; ".join(problems) + ".", 409, {"items": problems})

    if code:
        _, reason = find_coupon(code, sum(float(i.product.final_price) * i.quantity for i in items))
        if reason:
            return error(reason, 422, {"coupon": reason})
    totals = summarize(items, code, delivery)

    user = db.session.get(User, user_id)
    if delivery == "pickup":
        name, phone = (address.recipient_name, address.phone) if address else (user.full_name, user.phone or "")
        where = f"Store pickup: {STORE['name']}, {STORE['address']}"
    else:
        name, phone, where = address.recipient_name, address.phone, address.one_line

    # Take the stock with one conditional UPDATE per item: if someone else bought
    # the last one a moment ago, the row no longer matches and nothing is sold twice.
    for i in items:
        taken = db.session.execute(
            update(Product).where(Product.id == i.product_id, Product.stock >= i.quantity)
            .values(stock=Product.stock - i.quantity).execution_options(synchronize_session=False)
        )
        if taken.rowcount != 1:
            name, stock = db.session.execute(select(Product.name, Product.stock).where(Product.id == i.product_id)).one()
            db.session.rollback()
            problem = f"{name} is sold out" if stock <= 0 else f"Only {stock} left of {name}"
            return error(f"Some items changed. {problem}.", 409, {"items": [problem]})

    order = Order(
        order_number=f"TMP-{uuid.uuid4().hex[:20]}", user_id=user_id, created_at=utcnow(),
        shipping_name=name, shipping_phone=phone, shipping_address=where,
        subtotal=totals["subtotal"], discount=totals["discount"], shipping_fee=totals["shipping_fee"], total=totals["total"],
        coupon_code=totals["coupon"]["code"] if totals["coupon"] else None,
        delivery_method=delivery, payment_method=payment, payment_status="unpaid", status="pending",
        note=note,
    )
    for i in items:
        p = i.product
        order.items.append(OrderItem(product_id=p.id, product_name=p.name, unit_price=p.final_price,
                                     quantity=i.quantity, subtotal=float(p.final_price) * i.quantity))
        db.session.delete(i)
    db.session.add(order)
    db.session.flush()
    order.order_number = _order_number(order)
    notify.order_event(order, "placed_khqr" if payment == "khqr" else "placed_cod")
    db.session.commit()
    return success(order.to_dict(with_items=True), "Order placed", 201)


@bp.get("/orders")
@jwt_required()
def list_orders():
    """Newest first, with their items. Unpaid KHQR orders past their time are cancelled first."""
    orders = (
        Order.query.filter_by(user_id=_user_id())
        .options(selectinload(Order.items).selectinload(OrderItem.product))
        .order_by(Order.created_at.desc(), Order.id.desc())
        .all()
    )
    for order in orders:
        if order.payment_method == "khqr" and order.status == "pending":
            payments.refresh(order)
    return success(_with_my_ratings([o.to_dict(with_items=True) for o in orders]))


@bp.post("/orders/<int:order_id>/received")
@jwt_required()
def mark_received(order_id):
    """"Got it": the customer has the parcel. Cash orders count as paid now."""
    order = Order.query.filter_by(id=order_id, user_id=_user_id()).first()
    if not order:
        return error("Order not found", 404)
    if order.status != "shipped":
        return error("Only orders on the way can be marked as received", 409)
    order.status = "delivered"
    if order.payment_method == "cod":
        order.payment_status = "paid"
    notify.order_event(order, "delivered")
    db.session.commit()
    return success(_with_my_ratings([order.to_dict(with_items=True)])[0], "Enjoy your order!")


@bp.get("/orders/<int:order_id>")
@jwt_required()
def get_order(order_id):
    order = Order.query.filter_by(id=order_id, user_id=_user_id()).first()
    if not order:
        return error("Order not found", 404)
    return success(_with_my_ratings([order.to_dict(with_items=True)])[0])


def _with_my_ratings(orders):
    """Adds my_rating (stars the customer gave, or null) to each item of a delivered order."""
    mine = {r.product_id: r.rating for r in Review.query.filter_by(user_id=_user_id())}
    for o in orders:
        for item in o["items"]:
            item["my_rating"] = mine.get(item["product_id"]) if o["status"] == "delivered" else None
    return orders


# ---------- KHQR payment ----------

def _own_order(order_id):
    return Order.query.filter_by(id=order_id, user_id=_user_id()).first()


def _payment_response(order, payment):
    return success({"payment": payment.to_dict(), "order": order.to_dict(with_items=True)})


@bp.post("/orders/<int:order_id>/khqr")
@jwt_required()
def start_khqr(order_id):
    """Makes (once) and returns the order's KHQR code. Calling it again returns the same code."""
    order = _own_order(order_id)
    if not order:
        return error("Order not found", 404)
    if order.payment_method != "khqr":
        return error("This order is paid in cash", 409)
    existing = payments.active_payment(order)
    if existing is None and order.payment_status == "paid":
        return error("This order is already paid", 409)
    if order.status == "cancelled" and (existing is None or existing.status != "paid"):
        return error("This order was cancelled", 409)
    return _payment_response(order, payments.start(order))


@bp.get("/orders/<int:order_id>/payment")
@jwt_required()
def payment_status(order_id):
    """Polled by the app every few seconds: pending, paid or expired."""
    order = _own_order(order_id)
    payment = payments.active_payment(order) if order else None
    if not payment:
        return error("No KHQR payment for this order", 404)
    return _payment_response(order, payments.refresh(order, payment))


@bp.post("/orders/<int:order_id>/payment/simulate")
@jwt_required()
def simulate_payment(order_id):
    """Demo mode only: pretend the customer paid from their bank app."""
    order = _own_order(order_id)
    payment = payments.active_payment(order) if order else None
    if not payment:
        return error("No KHQR payment for this order", 404)
    if payment.provider != "mock" or current_app.config["PAYMENT_PROVIDER"] != "mock":
        return error("Payments can only be simulated in demo mode", 403)
    payment = payments.refresh(order, payment)
    if payment.status == "expired":
        return error("This KHQR code has expired", 409)
    return _payment_response(order, payments.mark_paid(order, payment))
