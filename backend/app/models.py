"""SQLAlchemy models. These mirror docs/database/schema.sql - keep the two in sync."""
from flask import has_request_context, request

from .extensions import db
from .utils.clock import utcnow


def absolute_url(path):
    """Turn a stored "/uploads/..." path into a full URL for the current host."""
    if path and path.startswith("/") and has_request_context():
        return request.host_url.rstrip("/") + path
    return path


class TimestampMixin:
    created_at = db.Column(db.DateTime, nullable=False, default=utcnow)


class User(TimestampMixin, db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True)
    full_name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(150), nullable=False, unique=True)
    password_hash = db.Column(db.String(255), nullable=False)
    phone = db.Column(db.String(20))
    avatar_url = db.Column(db.String(255))
    role = db.Column(db.Enum("customer", "admin", name="user_role"), nullable=False, default="customer")
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    updated_at = db.Column(db.DateTime, nullable=False, default=utcnow, onupdate=utcnow)

    addresses = db.relationship("Address", backref="user", cascade="all, delete-orphan")
    cart_items = db.relationship("CartItem", backref="user", cascade="all, delete-orphan")
    favorites = db.relationship("Favorite", backref="user", cascade="all, delete-orphan")
    orders = db.relationship("Order", backref="user")
    notifications = db.relationship("Notification", backref="user", cascade="all, delete-orphan")

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
        }


class Category(TimestampMixin, db.Model):
    __tablename__ = "categories"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    slug = db.Column(db.String(120), nullable=False, unique=True)
    description = db.Column(db.Text)
    image_url = db.Column(db.String(255))

    products = db.relationship("Product", backref="category")

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

    def to_dict(self):
        primary = next((i for i in self.images if i.is_primary), self.images[0] if self.images else None)
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
            "image_url": absolute_url(primary.image_url) if primary else None,
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
    total = db.Column(db.Numeric(10, 2), nullable=False)
    status = db.Column(
        db.Enum("pending", "confirmed", "shipped", "delivered", "cancelled", name="order_status"),
        nullable=False, default="pending",
    )
    payment_method = db.Column(db.Enum("cod", "khqr", "card", name="payment_method"), nullable=False, default="cod")
    payment_status = db.Column(
        db.Enum("unpaid", "paid", "failed", "refunded", name="payment_status"),
        nullable=False, default="unpaid",
    )
    note = db.Column(db.String(255))
    updated_at = db.Column(db.DateTime, nullable=False, default=utcnow, onupdate=utcnow)

    items = db.relationship("OrderItem", backref="order", cascade="all, delete-orphan")

    def to_dict(self, with_items=False):
        data = {
            "id": self.id,
            "order_number": self.order_number,
            "status": self.status,
            "payment_method": self.payment_method,
            "payment_status": self.payment_status,
            "subtotal": float(self.subtotal),
            "shipping_fee": float(self.shipping_fee),
            "total": float(self.total),
            "item_count": sum(i.quantity for i in self.items),
            "created_at": self.created_at.isoformat(),
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

    def to_dict(self):
        return {
            "product_id": self.product_id,
            "product_name": self.product_name,
            "unit_price": float(self.unit_price),
            "quantity": self.quantity,
            "subtotal": float(self.subtotal),
        }


class Notification(TimestampMixin, db.Model):
    __tablename__ = "notifications"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    title = db.Column(db.String(150), nullable=False)
    message = db.Column(db.Text, nullable=False)
    type = db.Column(db.Enum("order", "promo", "system", name="notification_type"), nullable=False, default="system")
    is_read = db.Column(db.Boolean, nullable=False, default=False)

    def to_dict(self):
        return {
            "id": self.id,
            "title": self.title,
            "message": self.message,
            "type": self.type,
            "is_read": self.is_read,
            "created_at": self.created_at.isoformat(),
        }


class Review(TimestampMixin, db.Model):
    __tablename__ = "reviews"
    __table_args__ = (db.UniqueConstraint("user_id", "product_id", name="uq_review_user_product"),)

    id = db.Column(db.Integer, primary_key=True)
    product_id = db.Column(db.Integer, db.ForeignKey("products.id", ondelete="CASCADE"), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    rating = db.Column(db.SmallInteger, nullable=False)
    comment = db.Column(db.Text)

    user = db.relationship("User")


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
