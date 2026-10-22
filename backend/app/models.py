"""SQLAlchemy models. These mirror docs/database/schema.sql - keep the two in sync."""
from flask import has_request_context, request
from flask_login import UserMixin

from .extensions import db
from .utils.clock import utcnow


def absolute_url(path):
    """Turn a stored "/uploads/..." path into a full URL for the current host."""
    if path and path.startswith("/") and has_request_context():
        return request.host_url.rstrip("/") + path
    return path


class TimestampMixin:
    created_at = db.Column(db.DateTime, nullable=False, default=utcnow)


class User(UserMixin, TimestampMixin, db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True)
    full_name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(150), nullable=False, unique=True)
    password_hash = db.Column(db.String(255), nullable=False)
    phone = db.Column(db.String(20))
    avatar_url = db.Column(db.String(255))
    # admin = the shop owner (everything); staff = runs the shop but cannot manage staff,
    # promo codes or block customers
    role = db.Column(db.Enum("customer", "staff", "admin", name="user_role"), nullable=False, default="customer")
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    last_login_at = db.Column(db.DateTime)
    # Goes up when the password changes; older login tokens stop working
    token_version = db.Column(db.Integer, nullable=False, default=0)
    updated_at = db.Column(db.DateTime, nullable=False, default=utcnow, onupdate=utcnow)

    addresses = db.relationship("Address", backref="user", cascade="all, delete-orphan")
    cart_items = db.relationship("CartItem", backref="user", cascade="all, delete-orphan")
    favorites = db.relationship("Favorite", backref="user", cascade="all, delete-orphan")
    orders = db.relationship("Order", backref="user")
    notifications = db.relationship("Notification", backref="user", cascade="all, delete-orphan")

    # Settings > Notify me about
    notify_orders = db.Column(db.Boolean, nullable=False, default=True)
    notify_offers = db.Column(db.Boolean, nullable=False, default=True)
    notify_news = db.Column(db.Boolean, nullable=False, default=True)

    def __str__(self):
        return f"{self.full_name} <{self.email}>"

    def to_dict(self):
        return {
            "id": self.id,
            "full_name": self.full_name,
            "email": self.email,
            "phone": self.phone,
            "avatar_url": absolute_url(self.avatar_url),
            "role": self.role,
            "created_at": self.created_at.isoformat(),
        }


class PasswordReset(TimestampMixin, db.Model):
    __tablename__ = "password_resets"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    code_hash = db.Column(db.String(255), nullable=False)
    expires_at = db.Column(db.DateTime, nullable=False)
    attempts = db.Column(db.Integer, nullable=False, default=0)  # wrong codes entered
    used = db.Column(db.Boolean, nullable=False, default=False)


class Address(TimestampMixin, db.Model):
    __tablename__ = "addresses"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    label = db.Column(db.String(50), nullable=False, default="Home")
    recipient_name = db.Column(db.String(100), nullable=False)
    phone = db.Column(db.String(20), nullable=False)
    street = db.Column(db.String(255), nullable=False)
    city = db.Column(db.String(100), nullable=False)
    province = db.Column(db.String(100))
    postal_code = db.Column(db.String(20))
    is_default = db.Column(db.Boolean, nullable=False, default=False)

    def to_dict(self):
        return {
            "id": self.id,
            "label": self.label,
            "recipient_name": self.recipient_name,
            "phone": self.phone,
            "street": self.street,
            "city": self.city,
            "province": self.province,
            "postal_code": self.postal_code,
            "is_default": self.is_default,
            "one_line": self.one_line,
        }

    @property
    def one_line(self):
        """'#24 St. 271, Chamkar Mon, Phnom Penh' - what is copied onto an order."""
        return ", ".join(part for part in (self.street, self.city, self.province) if part)


class Category(TimestampMixin, db.Model):
    __tablename__ = "categories"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    slug = db.Column(db.String(120), nullable=False, unique=True)
    description = db.Column(db.Text)
    image_url = db.Column(db.String(255))

    products = db.relationship("Product", backref="category")

    def __str__(self):
        return self.name

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "slug": self.slug,
            "description": self.description,
            "image_url": self.image_url,
        }


class Series(TimestampMixin, db.Model):
    """Anime franchise, e.g. One Piece, Pokemon."""
    __tablename__ = "series"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    slug = db.Column(db.String(120), nullable=False, unique=True)
    image_url = db.Column(db.String(255))

    products = db.relationship("Product", backref="series")

    def __str__(self):
        return self.name

    def to_dict(self):
        return {"id": self.id, "name": self.name, "slug": self.slug, "image_url": self.image_url}


class Product(TimestampMixin, db.Model):
    __tablename__ = "products"

    id = db.Column(db.Integer, primary_key=True)
    category_id = db.Column(db.Integer, db.ForeignKey("categories.id"), nullable=False)
    series_id = db.Column(db.Integer, db.ForeignKey("series.id", ondelete="SET NULL"))
    brand = db.Column(db.String(100), index=True)
    name = db.Column(db.String(150), nullable=False, index=True)
    slug = db.Column(db.String(170), nullable=False, unique=True)
    description = db.Column(db.Text)
    price = db.Column(db.Numeric(10, 2), nullable=False, index=True)
    discount_price = db.Column(db.Numeric(10, 2))
    stock = db.Column(db.Integer, nullable=False, default=0)
    is_featured = db.Column(db.Boolean, nullable=False, default=False)
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    updated_at = db.Column(db.DateTime, nullable=False, default=utcnow, onupdate=utcnow)

    images = db.relationship(
        "ProductImage", backref="product", cascade="all, delete-orphan",
        order_by="ProductImage.sort_order",
    )
    reviews = db.relationship("Review", backref="product", cascade="all, delete-orphan")

    @property
    def final_price(self):
        return self.discount_price if self.discount_price is not None else self.price

    @property
    def photo_url(self):
        """Absolute URL of the main photo, or None."""
        primary = next((i for i in self.images if i.is_primary), self.images[0] if self.images else None)
        return absolute_url(primary.image_url) if primary else None

    def __str__(self):
        return self.name

    def to_dict(self):
        ratings = [r.rating for r in self.reviews]
        return {
            "id": self.id,
            "category": self.category.to_dict(),
            "series": self.series.to_dict() if self.series else None,
            "brand": self.brand,
            "name": self.name,
            "slug": self.slug,
            "description": self.description,
            "price": float(self.price),
            "discount_price": float(self.discount_price) if self.discount_price is not None else None,
            "stock": self.stock,
            "is_featured": self.is_featured,
            "image_url": self.photo_url,
            "images": [absolute_url(i.image_url) for i in self.images],
            "rating": round(sum(ratings) / len(ratings), 1) if ratings else 0,
            "review_count": len(ratings),
        }


class ProductImage(db.Model):
    __tablename__ = "product_images"

    id = db.Column(db.Integer, primary_key=True)
    product_id = db.Column(db.Integer, db.ForeignKey("products.id", ondelete="CASCADE"), nullable=False)
    image_url = db.Column(db.String(255), nullable=False)
    is_primary = db.Column(db.Boolean, nullable=False, default=False)
    sort_order = db.Column(db.Integer, nullable=False, default=0)


class CartItem(TimestampMixin, db.Model):
    __tablename__ = "cart_items"
    __table_args__ = (db.UniqueConstraint("user_id", "product_id", name="uq_cart_user_product"),)

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey("products.id", ondelete="CASCADE"), nullable=False)
    quantity = db.Column(db.Integer, nullable=False, default=1)

    product = db.relationship("Product")

    def to_dict(self):
        return {
            "id": self.id,
            "quantity": self.quantity,
            "subtotal": float(self.product.final_price) * self.quantity,
            "product": self.product.to_dict(),
        }


class Favorite(TimestampMixin, db.Model):
    __tablename__ = "favorites"
    __table_args__ = (db.UniqueConstraint("user_id", "product_id", name="uq_fav_user_product"),)

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey("products.id", ondelete="CASCADE"), nullable=False)

    product = db.relationship("Product")


class Order(TimestampMixin, db.Model):
    __tablename__ = "orders"

    id = db.Column(db.Integer, primary_key=True)
    order_number = db.Column(db.String(30), nullable=False, unique=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    shipping_name = db.Column(db.String(100), nullable=False)
    shipping_phone = db.Column(db.String(20), nullable=False)
    shipping_address = db.Column(db.String(500), nullable=False)
    subtotal = db.Column(db.Numeric(10, 2), nullable=False)
    shipping_fee = db.Column(db.Numeric(10, 2), nullable=False, default=0)
    discount = db.Column(db.Numeric(10, 2), nullable=False, default=0)
    coupon_code = db.Column(db.String(30))
    total = db.Column(db.Numeric(10, 2), nullable=False)
    delivery_method = db.Column(db.Enum("standard", "pickup", name="delivery_method"), nullable=False, default="standard")
    status = db.Column(
        db.Enum("pending", "confirmed", "shipped", "delivered", "cancelled", name="order_status"),
        nullable=False, default="pending",
    )
    payment_method = db.Column(db.Enum("cod", "khqr", "aba", "card", name="payment_method"), nullable=False, default="cod")
    # refund_pending: a paid online order was cancelled and the shop still has to send the money back
    payment_status = db.Column(
        db.Enum("unpaid", "paid", "failed", "refund_pending", "refunded", name="payment_status"),
        nullable=False, default="unpaid",
    )
    note = db.Column(db.String(255))
    cancelled_by = db.Column(db.String(10))  # customer | shop | system (not paid in time)
    cancel_reason = db.Column(db.String(200))
    cancelled_at = db.Column(db.DateTime)
    refunded_at = db.Column(db.DateTime)
    updated_at = db.Column(db.DateTime, nullable=False, default=utcnow, onupdate=utcnow)

    items = db.relationship("OrderItem", backref="order", cascade="all, delete-orphan")

    def __str__(self):
        return self.order_number

    def to_dict(self, with_items=False):
        data = {
            "id": self.id,
            "order_number": self.order_number,
            "status": self.status,
            "payment_method": self.payment_method,
            "payment_status": self.payment_status,
            "subtotal": float(self.subtotal),
            "shipping_fee": float(self.shipping_fee),
            "discount": float(self.discount or 0),
            "coupon_code": self.coupon_code,
            "total": float(self.total),
            "delivery_method": self.delivery_method,
            "item_count": sum(i.quantity for i in self.items),
            "created_at": self.created_at.isoformat(),
            # The customer can cancel until the order is shipped
            "can_cancel": self.status in ("pending", "confirmed"),
            "cancelled_by": self.cancelled_by,
            "cancel_reason": self.cancel_reason,
            "cancelled_at": self.cancelled_at.isoformat() if self.cancelled_at else None,
            "refunded_at": self.refunded_at.isoformat() if self.refunded_at else None,
        }
        if with_items:
            data["shipping"] = {
                "name": self.shipping_name,
                "phone": self.shipping_phone,
                "address": self.shipping_address,
            }
            data["note"] = self.note
            data["items"] = [i.to_dict() for i in self.items]
        return data


class OrderItem(db.Model):
    __tablename__ = "order_items"

    id = db.Column(db.Integer, primary_key=True)
    order_id = db.Column(db.Integer, db.ForeignKey("orders.id", ondelete="CASCADE"), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey("products.id", ondelete="SET NULL"))
    product_name = db.Column(db.String(150), nullable=False)
    unit_price = db.Column(db.Numeric(10, 2), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    subtotal = db.Column(db.Numeric(10, 2), nullable=False)

    product = db.relationship("Product")

    def to_dict(self):
        return {
            "product_id": self.product_id,
            "product_name": self.product_name,
            # Live photo and category (for the placeholder icon); the name and price above are the snapshot
            "image_url": self.product.photo_url if self.product else None,
            "category": self.product.category.to_dict() if self.product else None,
            "unit_price": float(self.unit_price),
            "quantity": self.quantity,
            "subtotal": float(self.subtotal),
        }


class Payment(TimestampMixin, db.Model):
    """One online payment attempt for an order (Bakong KHQR or ABA PayWay). The QR
    (and its md5) is made once and reused for every status check, because a new
    QR is a new transaction. PayWay payments also keep their tran_id and the link
    that opens ABA Mobile."""
    __tablename__ = "payments"

    id = db.Column(db.Integer, primary_key=True)
    order_id = db.Column(db.Integer, db.ForeignKey("orders.id", ondelete="CASCADE"), nullable=False, index=True)
    provider = db.Column(db.Enum("mock", "bakong", "payway", name="payment_provider"), nullable=False)  # "mock": old demo-mode rows
    qr = db.Column(db.Text, nullable=False)
    tran_id = db.Column(db.String(20), unique=True)  # PayWay only
    deeplink = db.Column(db.Text)  # PayWay only: opens ABA Mobile with the amount filled in
    md5 = db.Column(db.String(32), nullable=False, unique=True)
    amount = db.Column(db.Numeric(10, 2), nullable=False)
    currency = db.Column(db.String(3), nullable=False, default="USD")
    status = db.Column(db.Enum("pending", "paid", "expired", name="khqr_status"), nullable=False, default="pending")
    expires_at = db.Column(db.DateTime, nullable=False)
    paid_at = db.Column(db.DateTime)

    order = db.relationship("Order", backref=db.backref("payments", cascade="all, delete-orphan"))

    def to_dict(self):
        return {
            "provider": "payway" if self.provider == "payway" else "bakong",
            "qr": self.qr,
            "deeplink": self.deeplink,
            "amount": float(self.amount),
            "currency": self.currency,
            "status": self.status,
            "expires_at": self.expires_at.isoformat() + "Z",
            "paid_at": self.paid_at.isoformat() + "Z" if self.paid_at else None,
        }


class Notification(TimestampMixin, db.Model):
    __tablename__ = "notifications"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    title = db.Column(db.String(150), nullable=False)
    message = db.Column(db.Text, nullable=False)
    type = db.Column(db.Enum("order", "promo", "system", name="notification_type"), nullable=False, default="system")
    # What happened, so the app can pick the icon and button: placed, paid, confirmed,
    # shipped, delivered, cancelled, welcome, promo, news, support
    event = db.Column(db.String(20))
    order_id = db.Column(db.Integer, db.ForeignKey("orders.id", ondelete="CASCADE"))
    promo_code = db.Column(db.String(30))
    is_read = db.Column(db.Boolean, nullable=False, default=False)

    order = db.relationship("Order")

    def to_dict(self):
        first = self.order.items[0] if self.order is not None and self.order.items else None
        return {
            "id": self.id,
            "title": self.title,
            "message": self.message,
            "type": self.type,
            "event": self.event or self.type,
            "is_read": self.is_read,
            "order": {"id": self.order.id, "number": self.order.order_number} if self.order is not None else None,
            "image_url": first.product.photo_url if first is not None and first.product is not None else None,
            "promo_code": self.promo_code,
            "created_at": self.created_at.isoformat() + "Z",
        }


class ContactMessage(TimestampMixin, db.Model):
    """A question sent from the Contact screen; the shop's reply comes back as a notification."""

    __tablename__ = "contact_messages"

    TOPICS = ("order", "payment", "product", "other")

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    # Only for questions about an order or a payment
    order_id = db.Column(db.Integer, db.ForeignKey("orders.id", ondelete="SET NULL"))
    topic = db.Column(db.Enum(*TOPICS, name="contact_topic"), nullable=False, default="other")
    message = db.Column(db.Text, nullable=False)
    status = db.Column(db.Enum("open", "answered", name="contact_status"), nullable=False, default="open")
    reply = db.Column(db.Text)
    replied_at = db.Column(db.DateTime)

    order = db.relationship("Order")

    def to_dict(self):
        return {
            "id": self.id,
            "topic": self.topic,
            "message": self.message,
            "status": self.status,
            "reply": self.reply,
            "order": {"id": self.order.id, "number": self.order.order_number} if self.order is not None else None,
            "created_at": self.created_at.isoformat() + "Z",
            "replied_at": self.replied_at.isoformat() + "Z" if self.replied_at else None,
        }


REVIEW_TAGS = ("quality", "as_pictured", "packaging", "delivery", "value")


class Review(TimestampMixin, db.Model):
    """A customer's stars (1-5), optional comment and quick tags for a product they
    received. One per customer and product; posting again edits it."""
    __tablename__ = "reviews"
    __table_args__ = (db.UniqueConstraint("user_id", "product_id", name="uq_review_user_product"),)

    id = db.Column(db.Integer, primary_key=True)
    product_id = db.Column(db.Integer, db.ForeignKey("products.id", ondelete="CASCADE"), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    rating = db.Column(db.SmallInteger, nullable=False)
    comment = db.Column(db.Text)
    tags = db.Column(db.JSON)  # some of REVIEW_TAGS
    updated_at = db.Column(db.DateTime)  # set when the customer edits it

    user = db.relationship("User")  # .product comes from Product.reviews

    def to_dict(self, me=None):
        return {
            "id": self.id,
            "product_id": self.product_id,
            "user": self.user.full_name,
            "rating": self.rating,
            "comment": self.comment,
            "tags": [t for t in (self.tags or []) if t in REVIEW_TAGS],
            "created_at": self.created_at.isoformat(),
            "edited": self.updated_at is not None,
            "is_mine": me is not None and self.user_id == me,
        }


class Coupon(TimestampMixin, db.Model):
    """Promo code for the cart, e.g. WELCOME10 (10% off) or ANIME5 ($5 off)."""
    __tablename__ = "coupons"

    id = db.Column(db.Integer, primary_key=True)
    code = db.Column(db.String(30), nullable=False, unique=True)  # stored upper case
    description = db.Column(db.String(150), nullable=False)
    discount_type = db.Column(db.Enum("percent", "fixed", name="coupon_type"), nullable=False)
    value = db.Column(db.Numeric(10, 2), nullable=False)  # 10 = 10% or $10
    min_subtotal = db.Column(db.Numeric(10, 2), nullable=False, default=0)
    max_discount = db.Column(db.Numeric(10, 2))  # cap for percent coupons
    expires_at = db.Column(db.DateTime)
    is_active = db.Column(db.Boolean, nullable=False, default=True)

    def discount_for(self, subtotal):
        """Money off for this subtotal (never more than the subtotal)."""
        subtotal = float(subtotal)
        if self.discount_type == "percent":
            off = subtotal * float(self.value) / 100
            if self.max_discount is not None:
                off = min(off, float(self.max_discount))
        else:
            off = float(self.value)
        return round(min(off, subtotal), 2)


# WAMP's MySQL makes MyISAM tables by default, and MyISAM silently drops every
# foreign key. InnoDB keeps them (and the relationships show in the ERD tools).
for _table in db.metadata.tables.values():
    _table.dialect_kwargs["mysql_engine"] = "InnoDB"
