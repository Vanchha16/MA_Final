"""Admin API: the shop team manages products, categories, customers, orders and
Contact messages. Staff and admin accounts can use it; promo codes, blocking customers
and managing staff are for the owner (admin) only."""
from datetime import datetime
from functools import wraps

from flask import Blueprint, request
from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request
from PIL import UnidentifiedImageError
from slugify import slugify
from sqlalchemy import case, func, or_
from sqlalchemy.orm import selectinload

from ..admin_ops import (AdminError, activity, delete_category, mark_refunded, next_statuses, reply_contact, set_customer_active,
                         set_order_status, stats, update_staff)
from ..extensions import bcrypt, db
from ..models import Category, ContactMessage, Coupon, Order, OrderItem, Product, ProductImage, Review, Series, User
from ..product_images import add_uploaded_photo, remove_photo
from ..utils.responses import error, success
from ..utils.validators import STOCK_MAX, Fields, json_body

bp = Blueprint("admin_api", __name__, url_prefix="/api/admin")

MAX_PHOTO_BYTES = 5 * 1024 * 1024


TEAM_ROLES = ("staff", "admin")


def _role_required(roles, message):
    def decorator(view):
        @wraps(view)
        def wrapper(*args, **kwargs):
            verify_jwt_in_request()
            user = db.session.get(User, int(get_jwt_identity()))
            if user is None or user.role not in roles:
                return error(message, 403)
            return view(*args, **kwargs)

        return wrapper

    return decorator


# Staff and the owner
staff_required = _role_required(TEAM_ROLES, "Shop staff only")
# The owner only
admin_required = _role_required(("admin",), "Admins only")


def _me():
    return db.session.get(User, int(get_jwt_identity()))


def _page(query, item):
    page = max(request.args.get("page", 1, type=int), 1)
    per_page = min(max(request.args.get("per_page", 20, type=int), 1), 100)
    result = query.paginate(page=page, per_page=per_page, error_out=False)
    return {
        "items": [item(x) for x in result.items],
        "page": result.page,
        "per_page": result.per_page,
        "total": result.total,
        "total_pages": result.pages,
    }


def _body():
    return json_body()


@bp.get("/stats")
@staff_required
def dashboard():
    return success(stats())


@bp.get("/activity")
@staff_required
def live_activity():
    """The dashboard's Live activity feed. Query: limit (default 20, max 50)."""
    return success(activity(min(max(request.args.get("limit", 20, type=int), 1), 50)))


# ---------------------------------------------------------------------------
# Products
# ---------------------------------------------------------------------------

def _product_dict(p):
    data = p.to_dict()
    data["is_active"] = p.is_active
    data["photos"] = [{"id": i.id, "url": url, "is_primary": i.is_primary} for i, url in zip(p.images, data["images"])]
    data["created_at"] = p.created_at.isoformat()
    return data


def _unique_slug(name, product_id=None):
    base = slugify(name)[:160] or "product"
    slug, n = base, 2
    while (other := Product.query.filter_by(slug=slug).first()) is not None and other.id != product_id:
        slug, n = f"{base}-{n}", n + 1
    return slug


def _apply_product(product, data, creating):
    """Checks and copies the fields that were sent. On create, name, category_id and price are required."""
    f = Fields(data)
    if creating or f.has("name"):
        name = f.text("name", required=True, max_len=150)
        if name:
            product.name = name
            product.slug = _unique_slug(name, product.id)
    if creating or f.has("category_id"):
        category_id = f.integer("category_id", required=True, min_value=1)
        if category_id is not None:
            category = db.session.get(Category, category_id)
            if category is None:
                f.errors["category_id"] = "Category not found"
            else:
                product.category = category
    if f.has("series_id"):
        if data["series_id"] in (None, ""):
            product.series = None
        else:
            series_id = f.integer("series_id", min_value=1)
            if series_id is not None:
                series = db.session.get(Series, series_id)
                if series is None:
                    f.errors["series_id"] = "Series not found"
                else:
                    product.series = series
    if creating or f.has("price"):
        price = f.money("price", required=True, label="Price")
        if price is not None:
            product.price = price
    if f.has("discount_price"):
        if data["discount_price"] in (None, ""):
            product.discount_price = None
        else:
            discount = f.money("discount_price", label="Sale price")
            if discount is not None:
                product.discount_price = discount
    if f.has("stock"):
        stock = f.integer("stock", required=True, min_value=0, max_value=STOCK_MAX, label="Stock")
        if stock is not None:
            product.stock = stock
    if f.has("brand"):
        product.brand = f.text("brand", max_len=100, label="Brand")
    if f.has("description"):
        product.description = f.text("description", max_len=5000, label="Description")
    for name in ("is_featured", "is_active"):
        if f.has(name):
            value = f.boolean(name)
            if value is not None:
                setattr(product, name, value)
    # Checked on the result, so lowering only the price can't leave a dearer "sale" price
    if (product.discount_price is not None and product.price is not None
            and float(product.discount_price) >= float(product.price) and "price" not in f.errors):
        f.errors.setdefault("discount_price", "Sale price must be lower than the price")
    return f.errors


def _admin_product(product_id):
    return db.session.get(Product, product_id)


@bp.get("/products")
@staff_required
def list_products():
    """All products, hidden ones too. Query: q, category_id, active=1|0, low_stock=1, page, per_page."""
    query = Product.query.options(selectinload(Product.images), selectinload(Product.category), selectinload(Product.series))
    args = request.args
    if q := args.get("q", "").strip():
        like = f"%{q}%"
        query = query.filter(or_(Product.name.ilike(like), Product.brand.ilike(like)))
    if category_id := args.get("category_id", type=int):
        query = query.filter(Product.category_id == category_id)
    if args.get("active") in ("0", "1"):
        query = query.filter(Product.is_active.is_(args["active"] == "1"))
    if args.get("low_stock") == "1":
        query = query.filter(Product.stock <= 3)
    return success(_page(query.order_by(Product.id.desc()), _product_dict))


@bp.post("/products")
@staff_required
def create_product():
    product = Product(stock=0)
    errors = _apply_product(product, _body(), creating=True)
    if errors:
        db.session.rollback()
        return error("Validation failed", 422, errors)
    db.session.add(product)
    db.session.commit()
    return success(_product_dict(product), "Product added", 201)


@bp.get("/products/<int:product_id>")
@staff_required
def get_product(product_id):
    product = _admin_product(product_id)
    if product is None:
        return error("Product not found", 404)
    return success(_product_dict(product))


@bp.put("/products/<int:product_id>")
@staff_required
def update_product(product_id):
    """Send only the fields to change."""
    product = _admin_product(product_id)
    if product is None:
        return error("Product not found", 404)
    errors = _apply_product(product, _body(), creating=False)
    if errors:
        db.session.rollback()
        return error("Validation failed", 422, errors)
    db.session.commit()
    return success(_product_dict(product), "Product saved")


@bp.delete("/products/<int:product_id>")
@staff_required
def hide_product(product_id):
    """Hides the product from the shop. It is kept because past orders point to it."""
    product = _admin_product(product_id)
    if product is None:
        return error("Product not found", 404)
    product.is_active = False
    product.is_featured = False
    db.session.commit()
    return success(_product_dict(product), "Product hidden from the shop")


@bp.post("/products/<int:product_id>/images")
@staff_required
def upload_photo(product_id):
    """multipart/form-data with a `file` (JPG, PNG or WebP, 5 MB max). Made square and saved as WebP."""
    product = _admin_product(product_id)
    if product is None:
        return error("Product not found", 404)
    file = request.files.get("file")
    if not file:
        return error("Validation failed", 422, {"file": "Please choose a photo"})
    file.stream.seek(0, 2)
    too_big = file.stream.tell() > MAX_PHOTO_BYTES
    file.stream.seek(0)
    if too_big:
        return error("Validation failed", 422, {"file": "Photo must be 5 MB or smaller"})
    try:
        add_uploaded_photo(product, file.stream)
    except (UnidentifiedImageError, OSError):
        return error("Validation failed", 422, {"file": "Use a JPG, PNG or WebP image"})
    db.session.commit()
    return success(_product_dict(product), "Photo added", 201)


@bp.delete("/products/<int:product_id>/images/<int:image_id>")
@staff_required
def delete_photo(product_id, image_id):
    image = ProductImage.query.filter_by(id=image_id, product_id=product_id).first()
    if image is None:
        return error("Photo not found", 404)
    product = image.product
    remove_photo(image)
    db.session.commit()
    return success(_product_dict(product), "Photo removed")


# ---------------------------------------------------------------------------
# Categories
# ---------------------------------------------------------------------------

def _category_dict(c, counts=None):
    data = c.to_dict()
    data["product_count"] = (counts or {}).get(c.id, 0) if counts is not None else len(c.products)
    return data


def _apply_category(category, data, creating):
    errors = {}
    if creating or "name" in data:
        name = data.get("name")
        if name is not None and not isinstance(name, str):
            return {"name": "name must be text"}
        name = (name or "").strip()
        if not name:
            errors["name"] = "name is required"
        elif len(name) > 100:
            errors["name"] = "Keep the name under 100 characters"
        else:
            slug = slugify(name)[:120]
            other = Category.query.filter(func.lower(Category.name) == name.lower()).first()
            if other is not None and other.id != category.id:
                errors["name"] = "There is already a category with this name"
            else:
                category.name = name
                if creating or not category.slug:
                    taken = Category.query.filter_by(slug=slug).first()
                    category.slug = slug if taken is None or taken.id == category.id else f"{slug}-{Category.query.count() + 1}"
    if "description" in data:
        f = Fields(data)
        category.description = f.text("description", max_len=1000, label="Description")
        errors.update(f.errors)
    return errors


@bp.get("/categories")
@staff_required
def list_categories():
    counts = dict(db.session.query(Product.category_id, func.count(Product.id)).group_by(Product.category_id).all())
    return success([_category_dict(c, counts) for c in Category.query.order_by(Category.id)])


@bp.post("/categories")
@staff_required
def create_category():
    category = Category()
    errors = _apply_category(category, _body(), creating=True)
    if errors:
        db.session.rollback()
        return error("Validation failed", 422, errors)
    db.session.add(category)
    db.session.commit()
    return success(_category_dict(category), "Category added", 201)


@bp.put("/categories/<int:category_id>")
@staff_required
def update_category(category_id):
    category = db.session.get(Category, category_id)
    if category is None:
        return error("Category not found", 404)
    errors = _apply_category(category, _body(), creating=False)
    if errors:
        db.session.rollback()
        return error("Validation failed", 422, errors)
    db.session.commit()
    return success(_category_dict(category), "Category saved")


@bp.delete("/categories/<int:category_id>")
@staff_required
def remove_category(category_id):
    category = db.session.get(Category, category_id)
    if category is None:
        return error("Category not found", 404)
    try:
        delete_category(category)
    except AdminError as e:
        return error(str(e), 409)
    return success(None, "Category deleted")


# ---------------------------------------------------------------------------
# Customers
# ---------------------------------------------------------------------------

def _customer_dict(u, with_orders=False):
    data = u.to_dict()
    data["is_active"] = u.is_active
    orders = [o for o in u.orders]
    data["order_count"] = len(orders)
    data["total_spent"] = round(sum(float(o.total) for o in orders if o.payment_status == "paid" and o.status != "cancelled"), 2)
    if with_orders:
        data["addresses"] = [a.to_dict() for a in u.addresses]
        data["orders"] = [o.to_dict() for o in sorted(orders, key=lambda o: o.created_at, reverse=True)]
    return data


@bp.get("/customers")
@staff_required
def list_customers():
    """Query: q (name, email or phone), active=1|0, page, per_page."""
    query = User.query.filter_by(role="customer").options(selectinload(User.orders))
    if q := request.args.get("q", "").strip():
        like = f"%{q}%"
        query = query.filter(or_(User.full_name.ilike(like), User.email.ilike(like), User.phone.ilike(like)))
    if request.args.get("active") in ("0", "1"):
        query = query.filter(User.is_active.is_(request.args["active"] == "1"))
    return success(_page(query.order_by(User.id.desc()), _customer_dict))


def _customer(user_id):
    return User.query.filter_by(id=user_id, role="customer").first()


@bp.get("/customers/<int:user_id>")
@staff_required
def get_customer(user_id):
    user = _customer(user_id)
    if user is None:
        return error("Customer not found", 404)
    return success(_customer_dict(user, with_orders=True))


@bp.put("/customers/<int:user_id>")
@admin_required
def update_customer(user_id):
    """Body: {is_active: true|false}. Blocking signs the customer out everywhere."""
    user = _customer(user_id)
    if user is None:
        return error("Customer not found", 404)
    data = _body()
    if not isinstance(data.get("is_active"), bool):
        return error("Validation failed", 422, {"is_active": "Send true or false"})
    set_customer_active(user, data["is_active"])
    return success(_customer_dict(user), "Customer unblocked" if user.is_active else "Customer blocked")


# ---------------------------------------------------------------------------
# Staff (the owner adds shop accounts, changes their role, disables them)
# ---------------------------------------------------------------------------

def _staff_dict(u):
    data = u.to_dict()
    data["is_active"] = u.is_active
    data["last_login_at"] = u.last_login_at.isoformat() if u.last_login_at else None
    return data


def _staff(user_id):
    return User.query.filter(User.id == user_id, User.role.in_(TEAM_ROLES)).first()


@bp.get("/staff")
@admin_required
def list_staff():
    """Admin and staff accounts, owners first. Query: q (name, email or phone), active=1|0."""
    query = User.query.filter(User.role.in_(TEAM_ROLES))
    if q := request.args.get("q", "").strip():
        like = f"%{q}%"
        query = query.filter(or_(User.full_name.ilike(like), User.email.ilike(like), User.phone.ilike(like)))
    if request.args.get("active") in ("0", "1"):
        query = query.filter(User.is_active.is_(request.args["active"] == "1"))
    owners_first = case((User.role == "admin", 0), else_=1)
    return success([_staff_dict(u) for u in query.order_by(owners_first, User.full_name)])


@bp.post("/staff")
@admin_required
def create_staff():
    """Body: full_name, email, password, phone?, role (staff|admin, default staff)."""
    f = Fields(_body())
    full_name = f.person_name("full_name", label="Name")
    email = f.email()
    password = f.password("password")
    phone = f.phone()
    role = f.choice("role", TEAM_ROLES, default="staff", message="Choose staff or admin")
    if email and User.query.filter_by(email=email).first():
        f.errors.setdefault("email", "Email is already registered")
    if f.errors:
        return error("Validation failed", 422, f.errors)
    user = User(full_name=full_name, email=email, phone=phone, role=role,
                password_hash=bcrypt.generate_password_hash(password).decode())
    db.session.add(user)
    db.session.commit()
    return success(_staff_dict(user), "Staff account added", 201)


@bp.put("/staff/<int:user_id>")
@admin_required
def edit_staff(user_id):
    """Send only what changes: full_name, phone, role, is_active, password (a new one to give them).
    A new role, a new password or disabling signs them out everywhere."""
    user = _staff(user_id)
    if user is None:
        return error("Staff account not found", 404)
    f = Fields(_body())
    changes = {}
    if f.has("full_name"):
        changes["full_name"] = f.person_name("full_name", label="Name")
    if f.has("phone"):
        changes["phone"] = f.phone()
    if f.has("role"):
        changes["role"] = f.choice("role", TEAM_ROLES, required=True, message="Choose staff or admin")
    if f.has("is_active"):
        changes["is_active"] = f.boolean("is_active")
    if f.has("password"):
        changes["password_hash"] = f.password("password", label="New password")
    if f.errors:
        return error("Validation failed", 422, f.errors)
    if "password_hash" in changes:
        changes["password_hash"] = bcrypt.generate_password_hash(changes["password_hash"]).decode()
    try:
        update_staff(user, _me(), changes)
    except AdminError as e:
        return error(str(e), 409)
    return success(_staff_dict(user), "Staff account saved")


# ---------------------------------------------------------------------------
# Orders
# ---------------------------------------------------------------------------

def _order_dict(o, with_items=False):
    data = o.to_dict(with_items=with_items)
    data["customer"] = {"id": o.user.id, "full_name": o.user.full_name, "email": o.user.email, "phone": o.shipping_phone}
    data["next_statuses"] = list(next_statuses(o))
    first = next((i for i in o.items if i.product is not None and i.product.photo_url), None)
    data["image_url"] = first.product.photo_url if first else None  # for the list's thumbnail
    return data


@bp.get("/orders")
@staff_required
def list_orders():
    """Every customer's orders, newest first. Query: status, refund=1 (refunds still to send), q (order number or customer), page, per_page."""
    query = Order.query.join(User, Order.user_id == User.id).options(selectinload(Order.items).selectinload(OrderItem.product).selectinload(Product.images), selectinload(Order.user))
    if status := request.args.get("status"):
        if status not in ("pending", "confirmed", "shipped", "delivered", "cancelled"):
            return error("Validation failed", 422, {"status": "Unknown status"})
        query = query.filter(Order.status == status)
    if request.args.get("refund") == "1":
        query = query.filter(Order.payment_status == "refund_pending")
    if q := request.args.get("q", "").strip():
        like = f"%{q}%"
        query = query.filter(or_(Order.order_number.ilike(like), User.full_name.ilike(like), User.email.ilike(like)))
    return success(_page(query.order_by(Order.created_at.desc(), Order.id.desc()), _order_dict))


@bp.get("/orders/<int:order_id>")
@staff_required
def get_order(order_id):
    order = Order.query.options(selectinload(Order.items).selectinload(OrderItem.product)).filter_by(id=order_id).first()
    if order is None:
        return error("Order not found", 404)
    return success(_order_dict(order, with_items=True))


@bp.put("/orders/<int:order_id>/status")
@staff_required
def update_order_status(order_id):
    """Body: {status, reason?}. Allowed steps are in the order's next_statuses; the customer is
    notified. Cancelling a paid online order leaves a refund to send (payment_status refund_pending)."""
    order = db.session.get(Order, order_id)
    if order is None:
        return error("Order not found", 404)
    body = _body()
    reason = body.get("reason")
    if reason is not None and not isinstance(reason, str):
        return error("Validation failed", 422, {"reason": "reason must be text"})
    try:
        set_order_status(order, body.get("status"), reason)
    except AdminError as e:
        return error(str(e), 409)
    return success(_order_dict(order, with_items=True), f"Order marked {order.status}")


@bp.post("/orders/<int:order_id>/refund")
@staff_required
def refund_order(order_id):
    """Marks a cancelled paid order as refunded, after the shop has sent the money back
    (bank transfer / ABA). The customer is notified."""
    order = db.session.get(Order, order_id)
    if order is None:
        return error("Order not found", 404)
    try:
        mark_refunded(order)
    except AdminError as e:
        return error(str(e), 409)
    return success(_order_dict(order, with_items=True), "Marked as refunded")


# ---------------------------------------------------------------------------
# Contact messages
# ---------------------------------------------------------------------------

@bp.get("/contact-messages")
@staff_required
def list_contact_messages():
    """Query: status=open|answered, page, per_page."""
    query = ContactMessage.query
    if (status := request.args.get("status")) in ("open", "answered"):
        query = query.filter_by(status=status)

    def item(m):
        data = m.to_dict()
        data["customer"] = {"id": m.user_id, "full_name": db.session.get(User, m.user_id).full_name}
        return data

    return success(_page(query.order_by(ContactMessage.created_at.desc(), ContactMessage.id.desc()), item))


@bp.post("/contact-messages/<int:message_id>/reply")
@staff_required
def reply_to_message(message_id):
    """Body: {reply}. The customer gets the reply in Notifications."""
    message = db.session.get(ContactMessage, message_id)
    if message is None:
        return error("Message not found", 404)
    try:
        reply_contact(message, _body().get("reply"))
    except AdminError as e:
        return error("Validation failed", 422, {"reply": str(e)})
    return success(message.to_dict(), "Reply sent")


# ---------------------------------------------------------------------------
# Coupons (promo codes) and reviews - used by the web admin
# ---------------------------------------------------------------------------

def _coupon_dict(c):
    return {
        "id": c.id,
        "code": c.code,
        "description": c.description,
        "discount_type": c.discount_type,
        "value": float(c.value),
        "min_subtotal": float(c.min_subtotal or 0),
        "max_discount": float(c.max_discount) if c.max_discount is not None else None,
        "expires_at": c.expires_at.isoformat() if c.expires_at else None,
        "is_active": c.is_active,
        "used": Order.query.filter(Order.coupon_code == c.code).count(),
    }


def _apply_coupon(coupon, data, creating):
    """Checks and copies the sent fields. On create, code, description, discount_type and value are required."""
    f = Fields(data)
    if creating or f.has("code"):
        code = f.text("code", required=True, max_len=30, label="Code")
        if code is not None:
            code = code.upper()
            if not code.replace("-", "").isalnum():
                f.errors["code"] = "Use letters and numbers only, e.g. ANIME5"
            elif (other := Coupon.query.filter_by(code=code).first()) is not None and other.id != coupon.id:
                f.errors["code"] = "There is already a coupon with this code"
            else:
                coupon.code = code
    if creating or f.has("description"):
        description = f.text("description", required=True, max_len=150, label="Description")
        if description:
            coupon.description = description
    if creating or f.has("discount_type"):
        kind = f.choice("discount_type", ("percent", "fixed"), required=True, message="Choose percent or fixed")
        if kind:
            coupon.discount_type = kind
    if creating or f.has("value"):
        value = f.money("value", required=True, label="Value")
        if value is not None:
            coupon.value = value
    if f.has("min_subtotal"):
        raw = data["min_subtotal"]
        coupon.min_subtotal = 0 if raw in (None, "", 0, "0") else (f.money("min_subtotal", label="Minimum spend") or coupon.min_subtotal)
    if f.has("max_discount"):
        coupon.max_discount = None if data["max_discount"] in (None, "") else f.money("max_discount", label="Maximum discount")
    if f.has("expires_at"):
        raw = data["expires_at"]
        if raw in (None, ""):
            coupon.expires_at = None
        else:
            try:
                coupon.expires_at = datetime.fromisoformat(str(raw).replace("Z", ""))
            except ValueError:
                f.errors["expires_at"] = "Use a date like 2026-12-31"
    if f.has("is_active"):
        active = f.boolean("is_active")
        if active is not None:
            coupon.is_active = active
    if coupon.discount_type == "percent" and coupon.value is not None and float(coupon.value) > 100:
        f.errors.setdefault("value", "A percent coupon can be at most 100")
    return f.errors


@bp.get("/coupons")
@admin_required
def list_coupons():
    return success([_coupon_dict(c) for c in Coupon.query.order_by(Coupon.is_active.desc(), Coupon.code)])


@bp.post("/coupons")
@admin_required
def create_coupon():
    coupon = Coupon(min_subtotal=0, is_active=True)
    errors = _apply_coupon(coupon, _body(), creating=True)
    if errors:
        db.session.rollback()
        return error("Validation failed", 422, errors)
    db.session.add(coupon)
    db.session.commit()
    return success(_coupon_dict(coupon), "Coupon added", 201)


@bp.put("/coupons/<int:coupon_id>")
@admin_required
def update_coupon(coupon_id):
    coupon = db.session.get(Coupon, coupon_id)
    if coupon is None:
        return error("Coupon not found", 404)
    errors = _apply_coupon(coupon, _body(), creating=False)
    if errors:
        db.session.rollback()
        return error("Validation failed", 422, errors)
    db.session.commit()
    return success(_coupon_dict(coupon), "Coupon saved")


@bp.delete("/coupons/<int:coupon_id>")
@admin_required
def delete_coupon(coupon_id):
    coupon = db.session.get(Coupon, coupon_id)
    if coupon is None:
        return error("Coupon not found", 404)
    db.session.delete(coupon)
    db.session.commit()
    return success(None, "Coupon deleted")


@bp.get("/reviews")
@staff_required
def list_reviews():
    """All reviews, newest first. Query: rating=1-5, q (product or customer), page, per_page."""
    query = Review.query.join(Product).join(User, User.id == Review.user_id)
    if (rating := request.args.get("rating", type=int)) is not None:
        query = query.filter(Review.rating == rating)
    if q := request.args.get("q", "").strip()[:100]:
        like = f"%{q}%"
        query = query.filter(or_(Product.name.ilike(like), User.full_name.ilike(like)))

    def item(r):
        data = r.to_dict()
        data["product"] = {"id": r.product.id, "name": r.product.name, "image_url": r.product.photo_url}
        data["customer"] = {"id": r.user_id, "full_name": r.user.full_name, "email": r.user.email}
        return data

    return success(_page(query.order_by(Review.created_at.desc(), Review.id.desc()), item))


@bp.delete("/reviews/<int:review_id>")
@staff_required
def delete_review(review_id):
    """Removes a review (spam or rude words). The product's rating updates at once."""
    review = db.session.get(Review, review_id)
    if review is None:
        return error("Review not found", 404)
    db.session.delete(review)
    db.session.commit()
    return success(None, "Review deleted")
