"""Admin API: the shop owner manages products, categories, customers, orders and
Contact messages. Every route needs a login token of an active admin account."""
from functools import wraps

from flask import Blueprint, request
from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request
from PIL import UnidentifiedImageError
from slugify import slugify
from sqlalchemy import func, or_
from sqlalchemy.orm import selectinload

from ..admin_ops import AdminError, activity, delete_category, next_statuses, reply_contact, set_customer_active, set_order_status, stats
from ..extensions import db
from ..models import Category, ContactMessage, Order, OrderItem, Product, ProductImage, Series, User
from ..product_images import add_uploaded_photo, remove_photo
from ..utils.responses import error, success

bp = Blueprint("admin_api", __name__, url_prefix="/api/admin")

MAX_PHOTO_BYTES = 5 * 1024 * 1024


def admin_required(view):
    @wraps(view)
    def wrapper(*args, **kwargs):
        verify_jwt_in_request()
        user = db.session.get(User, int(get_jwt_identity()))
        if user is None or user.role != "admin":
            return error("Admins only", 403)
        return view(*args, **kwargs)

    return wrapper


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
    return request.get_json(silent=True) or {}


@bp.get("/stats")
@admin_required
def dashboard():
    return success(stats())


@bp.get("/activity")
@admin_required
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


def _number(value, *, whole=False):
    try:
        return int(value) if whole else float(value)
    except (TypeError, ValueError):
        return None


def _apply_product(product, data, creating):
    """Checks and copies the fields that were sent. On create, name, category_id and price are required."""
    errors = {}
    fields = set(data)
    if creating:
        for f in ("name", "category_id", "price"):
            if data.get(f) in (None, ""):
                errors[f] = f"{f} is required"

    if "name" in fields and not errors.get("name"):
        name = str(data["name"] or "").strip()
        if not name:
            errors["name"] = "name is required"
        elif len(name) > 150:
            errors["name"] = "Keep the name under 150 characters"
        else:
            product.name = name
            product.slug = _unique_slug(name, product.id)
    if "category_id" in fields and not errors.get("category_id"):
        category = db.session.get(Category, _number(data["category_id"], whole=True) or 0)
        if category is None:
            errors["category_id"] = "Category not found"
        else:
            product.category = category
    if "series_id" in fields:
        if data["series_id"] in (None, ""):
            product.series = None
        elif (series := db.session.get(Series, _number(data["series_id"], whole=True) or 0)) is None:
            errors["series_id"] = "Series not found"
        else:
            product.series = series
    if "price" in fields and not errors.get("price"):
        price = _number(data["price"])
        if price is None or price <= 0:
            errors["price"] = "Price must be more than 0"
        else:
            product.price = price
    if "discount_price" in fields:
        discount = None if data["discount_price"] in (None, "") else _number(data["discount_price"])
        price = float(product.price) if product.price is not None else None
        if data["discount_price"] not in (None, "") and (discount is None or discount <= 0):
            errors["discount_price"] = "Sale price must be more than 0"
        elif discount is not None and price is not None and discount >= price:
            errors["discount_price"] = "Sale price must be lower than the price"
        else:
            product.discount_price = discount
    if "stock" in fields:
        stock = _number(data["stock"], whole=True)
        if stock is None or stock < 0:
            errors["stock"] = "Stock must be 0 or more"
        else:
            product.stock = stock
    for f in ("brand", "description"):
        if f in fields:
            setattr(product, f, (str(data[f]).strip() or None) if data[f] is not None else None)
    for f in ("is_featured", "is_active"):
        if f in fields:
            setattr(product, f, bool(data[f]))
    return errors


def _admin_product(product_id):
    return db.session.get(Product, product_id)


@bp.get("/products")
@admin_required
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
@admin_required
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
@admin_required
def get_product(product_id):
    product = _admin_product(product_id)
    if product is None:
        return error("Product not found", 404)
    return success(_product_dict(product))


@bp.put("/products/<int:product_id>")
@admin_required
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
@admin_required
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
@admin_required
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
@admin_required
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
        name = str(data.get("name") or "").strip()
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
        category.description = (str(data["description"]).strip() or None) if data["description"] is not None else None
    return errors


@bp.get("/categories")
@admin_required
def list_categories():
    counts = dict(db.session.query(Product.category_id, func.count(Product.id)).group_by(Product.category_id).all())
    return success([_category_dict(c, counts) for c in Category.query.order_by(Category.id)])


@bp.post("/categories")
@admin_required
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
@admin_required
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
@admin_required
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
@admin_required
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
@admin_required
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
@admin_required
def list_orders():
    """Every customer's orders, newest first. Query: status, q (order number or customer), page, per_page."""
    query = Order.query.join(User, Order.user_id == User.id).options(selectinload(Order.items).selectinload(OrderItem.product).selectinload(Product.images), selectinload(Order.user))
    if status := request.args.get("status"):
        if status not in ("pending", "confirmed", "shipped", "delivered", "cancelled"):
            return error("Validation failed", 422, {"status": "Unknown status"})
        query = query.filter(Order.status == status)
    if q := request.args.get("q", "").strip():
        like = f"%{q}%"
        query = query.filter(or_(Order.order_number.ilike(like), User.full_name.ilike(like), User.email.ilike(like)))
    return success(_page(query.order_by(Order.created_at.desc(), Order.id.desc()), _order_dict))


@bp.get("/orders/<int:order_id>")
@admin_required
def get_order(order_id):
    order = Order.query.options(selectinload(Order.items).selectinload(OrderItem.product)).filter_by(id=order_id).first()
    if order is None:
        return error("Order not found", 404)
    return success(_order_dict(order, with_items=True))


@bp.put("/orders/<int:order_id>/status")
@admin_required
def update_order_status(order_id):
    """Body: {status}. Allowed steps are in the order's next_statuses; the customer is notified."""
    order = db.session.get(Order, order_id)
    if order is None:
        return error("Order not found", 404)
    try:
        set_order_status(order, _body().get("status"))
    except AdminError as e:
        return error(str(e), 409)
    return success(_order_dict(order, with_items=True), f"Order marked {order.status}")


# ---------------------------------------------------------------------------
# Contact messages
# ---------------------------------------------------------------------------

@bp.get("/contact-messages")
@admin_required
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
@admin_required
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
