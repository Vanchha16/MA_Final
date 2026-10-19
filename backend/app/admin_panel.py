"""Web admin panel at /admin (Flask-Admin) for the shop owner. It uses the same
actions as the admin API (admin_ops), so notifications and stock stay right.
Sign in with an admin account, e.g. admin@shop.com."""
from datetime import datetime

from flask import flash, redirect, request, url_for
from flask_admin import Admin, AdminIndexView, expose
from flask_admin.actions import action
from flask_admin.model import typefmt
from flask_admin.contrib.sqla import ModelView
from flask_admin.form import SecureForm
from flask_admin.menu import MenuLink
from flask_admin.theme import Bootstrap4Theme
from flask_login import LoginManager, current_user, login_user, logout_user
from markupsafe import Markup, escape
from PIL import UnidentifiedImageError
from slugify import slugify
from wtforms import EmailField, HiddenField, MultipleFileField, PasswordField, TextAreaField
from wtforms.validators import DataRequired, ValidationError

from . import admin_ops
from .extensions import bcrypt, db
from .models import Category, ContactMessage, Coupon, Order, Product, Review, Series, User
from .product_images import add_uploaded_photo

login_manager = LoginManager()


@login_manager.user_loader
def _load_user(user_id):
    return db.session.get(User, int(user_id))


def _is_admin():
    return current_user.is_authenticated and current_user.role == "admin" and current_user.is_active


class LoginForm(SecureForm):
    email = EmailField("Email", validators=[DataRequired()])
    password = PasswordField("Password", validators=[DataRequired()])


class QuickForm(SecureForm):
    """The one-click buttons (Confirm, Ship, +5, Reply). SecureForm adds the CSRF token."""
    status = HiddenField()
    reply = TextAreaField()


def quick_token():
    """CSRF token for the small button forms drawn inside list columns."""
    return QuickForm().csrf_token.current_token


STEP_LABEL = {"confirmed": "Confirm", "shipped": "Ship", "delivered": "Delivered"}


def _next_step(order):
    return next((s for s in admin_ops.next_statuses(order) if s != "cancelled"), None)


def _back(default):
    """Where to go after a quick action: the page it came from, if it is an admin page."""
    nxt = request.form.get("next") or request.args.get("next") or ""
    return redirect(nxt if nxt.startswith("/admin") else default)


class ShopIndexView(AdminIndexView):
    """Dashboard, plus the sign-in page."""

    @expose("/")
    def index(self):
        if not _is_admin():
            return redirect(url_for(".login", next=request.full_path))
        orders = (
            Order.query.filter(Order.status.in_(["pending", "confirmed", "shipped"]))
            .order_by(Order.created_at.desc()).limit(8).all()
        )
        messages = {m.id: m for m in ContactMessage.query.filter_by(status="open")}
        low = Product.query.filter(Product.is_active.is_(True), Product.stock <= 3).order_by(Product.stock).limit(6).all()
        stats = admin_ops.stats()
        week = [{"day": datetime.fromisoformat(d["date"]).strftime("%a"), "revenue": d["revenue"]} for d in stats["week"]]
        return self.render("admin/dashboard.html", stats=stats, week=week, orders=orders, messages=messages, low=low,
                           events=admin_ops.activity(8), next_step=_next_step, step_label=STEP_LABEL, pay_names={**admin_ops.PAY_NAMES, "cod": "Cash"},
                           quick=QuickForm(), greeting=_greeting(), now=datetime.now())

    # ---------- one-click actions (also used by the Orders and Products lists) ----------

    def _quick_form(self):
        form = QuickForm(request.form)
        if not _is_admin():
            return None
        if not form.validate():
            flash("That page was open too long. Please try again.", "error")
            return None
        return form

    @expose("/quick/order/<int:order_id>", methods=("POST",))
    def quick_order(self, order_id):
        form = self._quick_form()
        order = db.session.get(Order, order_id)
        if form and order:
            try:
                admin_ops.set_order_status(order, form.status.data)
                flash(f"{order.order_number} marked {order.status}. The customer was told.", "success")
            except admin_ops.AdminError as e:
                flash(str(e), "error")
        return _back(url_for(".index"))

    @expose("/quick/restock/<int:product_id>", methods=("POST",))
    def quick_restock(self, product_id):
        form = self._quick_form()
        product = db.session.get(Product, product_id)
        if form and product:
            product.stock = max(product.stock, 0) + 5
            db.session.commit()
            flash(f"{product.name} restocked: {product.stock} in stock.", "success")
        return _back(url_for(".index"))

    @expose("/quick/reply/<int:message_id>", methods=("POST",))
    def quick_reply(self, message_id):
        form = self._quick_form()
        message = db.session.get(ContactMessage, message_id)
        if form and message:
            try:
                admin_ops.reply_contact(message, form.reply.data)
                flash("Reply sent to the customer's Notifications.", "success")
            except admin_ops.AdminError as e:
                flash(str(e), "error")
        return _back(url_for(".index"))

    @expose("/login", methods=("GET", "POST"))
    def login(self):
        form = LoginForm(request.form)
        if request.method == "POST" and form.validate():
            user = User.query.filter_by(email=form.email.data.strip().lower()).first()
            if user and user.role == "admin" and user.is_active and bcrypt.check_password_hash(user.password_hash, form.password.data):
                login_user(user)
                nxt = request.args.get("next", "")
                return redirect(nxt if nxt.startswith("/admin") else url_for(".index"))
            flash("Wrong email or password, or this is not an admin account.", "error")
        return self.render("admin/login.html", form=form)

    @expose("/logout")
    def logout(self):
        logout_user()
        return redirect(url_for(".login"))


class SecureView(ModelView):
    """Only signed-in admins; CSRF-protected forms; 20 rows a page."""

    form_base_class = SecureForm
    page_size = 20
    # Times are stored in UTC; show them to the minute
    column_type_formatters = {**typefmt.BASE_FORMATTERS, datetime: lambda view, value, name=None: value.strftime("%Y-%m-%d %H:%M UTC")}
    column_type_formatters_detail = column_type_formatters
    can_view_details = True
    can_export = True

    def is_accessible(self):
        return _is_admin()

    def inaccessible_callback(self, name, **kwargs):
        return redirect(url_for("admin.login", next=request.full_path))


def _greeting():
    hour = datetime.now().hour
    return "Good morning" if hour < 12 else "Good afternoon" if hour < 18 else "Good evening"


def _button_form(action, label, *, status=None, kind="primary"):
    """A one-button POST form for a list row (CSRF-protected), returning to this page."""
    status_input = f'<input type="hidden" name="status" value="{escape(status)}">' if status else ""
    return Markup(
        f'<form method="post" action="{escape(action)}" class="d-inline m-0">'
        f'<input type="hidden" name="csrf_token" value="{escape(quick_token())}">{status_input}'
        f'<input type="hidden" name="next" value="{escape(request.full_path)}">'
        f'<button type="submit" class="btn btn-sm btn-{kind} py-0 px-3">{escape(label)}</button></form>'
    )


def _money(view, context, model, name):
    value = getattr(model, name)
    return "" if value is None else f"${float(value):,.2f}"


def _badge(text, kind):
    return Markup(f'<span class="badge badge-{kind}">{escape(text)}</span>')


STATUS_KIND = {"pending": "warning", "confirmed": "info", "shipped": "primary", "delivered": "success", "cancelled": "secondary"}


class ProductView(SecureView):
    column_list = ("photo", "name", "category", "series", "price", "discount_price", "stock", "restock", "is_featured", "is_active")
    column_labels = {"discount_price": "Sale price", "is_featured": "Featured", "is_active": "In shop", "photo": "", "restock": ""}
    column_searchable_list = ("name", "brand")
    column_filters = ("category.name", "series.name", "brand", "is_active", "is_featured", "stock")
    column_editable_list = ("price", "discount_price", "stock", "is_featured", "is_active")
    column_default_sort = ("id", True)
    form_columns = ("name", "category", "series", "brand", "description", "price", "discount_price", "stock", "is_featured", "is_active", "new_photos")
    form_extra_fields = {"new_photos": MultipleFileField("Add photos (JPG, PNG or WebP; made square, first one is the main photo)")}
    column_formatters = {
        "photo": lambda v, c, m, n: Markup(f'<img src="{escape(m.photo_url)}" class="thumb" alt="">') if m.photo_url else "",
        "price": _money,
        "discount_price": _money,
        "restock": lambda v, c, m, n: _button_form(url_for("admin.quick_restock", product_id=m.id), "+5", kind="outline-primary"),
    }
    column_details_list = ("name", "slug", "category", "series", "brand", "description", "price", "discount_price", "stock",
                           "is_featured", "is_active", "photos", "created_at", "updated_at")
    column_formatters_detail = {
        "photos": lambda v, c, m, n: Markup("".join(f'<img src="{escape(i)}" class="thumb lg" alt="">' for i in m.to_dict()["images"])),
        "price": _money,
        "discount_price": _money,
    }

    def on_model_change(self, form, model, is_created):
        if model.discount_price is not None and model.price is not None and model.discount_price >= model.price:
            raise ValidationError("The sale price must be lower than the price.")
        if model.stock is not None and model.stock < 0:
            raise ValidationError("Stock must be 0 or more.")
        base = slugify(model.name)[:160] or "product"
        slug, n = base, 2
        with db.session.no_autoflush:  # the new product has no slug yet
            while (other := Product.query.filter_by(slug=slug).first()) is not None and other is not model:
                slug, n = f"{base}-{n}", n + 1
        model.slug = slug
        for file in getattr(form, "new_photos", None).data or []:
            if not getattr(file, "filename", ""):
                continue
            try:
                add_uploaded_photo(model, file.stream)
            except (UnidentifiedImageError, OSError):
                raise ValidationError(f"{file.filename} is not a JPG, PNG or WebP image.")

    def delete_model(self, model):
        # Past orders point to products, so "delete" hides it from the shop instead
        model.is_active = False
        model.is_featured = False
        db.session.commit()
        flash(f"{model.name} is hidden from the shop. Tick In shop to bring it back.", "info")
        return True


class CategoryView(SecureView):
    column_list = ("name", "slug", "description", "product_count")
    column_labels = {"product_count": "Products"}
    column_searchable_list = ("name",)
    form_columns = ("name", "description")
    column_formatters = {"product_count": lambda v, c, m, n: len(m.products)}

    def on_model_change(self, form, model, is_created):
        if is_created or not model.slug:
            model.slug = slugify(model.name)[:120]

    def delete_model(self, model):
        try:
            admin_ops.delete_category(model)
        except admin_ops.AdminError as e:
            flash(f"{e}. Move or hide them first.", "error")
            return False
        return True


class SeriesView(CategoryView):
    column_list = ("name", "slug", "product_count")
    form_columns = ("name",)

    def delete_model(self, model):
        if model.products:
            flash(f"{model.name} still has {len(model.products)} product(s).", "error")
            return False
        db.session.delete(model)
        db.session.commit()
        return True


class CustomerView(SecureView):
    """Customers only. The owner can block or unblock; account details are the customer's."""

    can_create = False
    can_delete = False
    column_list = ("full_name", "email", "phone", "is_active", "order_count", "created_at")
    column_labels = {"full_name": "Name", "is_active": "Active", "order_count": "Orders", "created_at": "Joined"}
    column_searchable_list = ("full_name", "email", "phone")
    column_filters = ("is_active", "created_at")
    column_default_sort = ("id", True)
    form_columns = ("is_active",)
    column_details_list = ("full_name", "email", "phone", "is_active", "created_at", "addresses", "orders")
    column_formatters = {"order_count": lambda v, c, m, n: len(m.orders)}
    column_formatters_detail = {
        "addresses": lambda v, c, m, n: Markup("<br>".join(escape(f"{a.label}: {a.recipient_name}, {a.one_line}") for a in m.addresses)),
        "orders": lambda v, c, m, n: Markup("<br>".join(
            f'<a href="{url_for("admin_orders.details_view", id=o.id)}">{escape(o.order_number)}</a> · {o.status} · ${float(o.total):,.2f}' for o in m.orders)),
    }

    def get_query(self):
        return super().get_query().filter(User.role == "customer")

    def get_count_query(self):
        return super().get_count_query().filter(User.role == "customer")

    def update_model(self, form, model):
        try:
            admin_ops.set_customer_active(model, form.is_active.data)
        except admin_ops.AdminError as e:
            flash(str(e), "error")
            return False
        return True

    def _set_active(self, ids, active):
        for user in User.query.filter(User.id.in_(ids), User.role == "customer"):
            admin_ops.set_customer_active(user, active)
        flash(f"{len(ids)} customer(s) {'unblocked' if active else 'blocked'}.", "success")

    @action("block", "Block", "Block these customers? They are signed out and cannot log in.")
    def action_block(self, ids):
        self._set_active(ids, False)

    @action("unblock", "Unblock")
    def action_unblock(self, ids):
        self._set_active(ids, True)


class OrderView(SecureView):
    """Orders are placed in the app. Tick orders and pick an action to move them on;
    the customer gets the same notification as from the admin API."""

    can_create = False
    can_edit = False
    can_delete = False
    column_list = ("order_number", "user", "total", "payment_method", "payment_status", "delivery_method", "status", "created_at", "step")
    column_labels = {"order_number": "Order", "user": "Customer", "payment_method": "Pay by", "payment_status": "Payment",
                     "delivery_method": "Delivery", "created_at": "Placed", "shipping_name": "Name", "shipping_phone": "Phone",
                     "next": "Can be marked", "lines": "Items", "step": ""}
    column_searchable_list = ("order_number", "shipping_name", "shipping_phone")
    column_filters = ("status", "payment_method", "payment_status", "delivery_method", "created_at")
    column_default_sort = ("created_at", True)
    column_formatters = {
        "user": lambda v, c, m, n: m.user.full_name,
        "payment_method": lambda v, c, m, n: m.payment_method.upper(),
        "total": _money,
        "status": lambda v, c, m, n: _badge(m.status, STATUS_KIND[m.status]),
        "payment_status": lambda v, c, m, n: _badge(m.payment_status, "success" if m.payment_status == "paid" else "light"),
        "step": lambda v, c, m, n: _button_form(url_for("admin.quick_order", order_id=m.id), STEP_LABEL[step], status=step)
        if (step := _next_step(m)) else "",
    }
    column_details_list = ("order_number", "user", "status", "next", "payment_method", "payment_status", "delivery_method",
                           "shipping_name", "shipping_phone", "shipping_address", "note", "lines", "subtotal", "shipping_fee",
                           "discount", "coupon_code", "total", "created_at")
    column_formatters_detail = {
        **column_formatters,
        "next": lambda v, c, m, n: ", ".join(admin_ops.next_statuses(m)) or "- (finished)",
        "lines": lambda v, c, m, n: Markup("<br>".join(f"{i.quantity} x {escape(i.product_name)} (${float(i.unit_price):,.2f})" for i in m.items)),
        "subtotal": _money,
        "shipping_fee": _money,
        "discount": _money,
    }

    def _move(self, ids, status):
        done, skipped = 0, []
        for order in Order.query.filter(Order.id.in_(ids)):
            try:
                admin_ops.set_order_status(order, status)
                done += 1
            except admin_ops.AdminError:
                skipped.append(order.order_number)
        if done:
            flash(f"{done} order(s) marked {status}. Customers were notified.", "success")
        if skipped:
            flash(f"Not changed (that step is not allowed): {', '.join(skipped)}", "warning")

    @action("confirmed", "Mark confirmed")
    def action_confirm(self, ids):
        self._move(ids, "confirmed")

    @action("shipped", "Mark shipped / ready to pick up")
    def action_ship(self, ids):
        self._move(ids, "shipped")

    @action("delivered", "Mark delivered")
    def action_deliver(self, ids):
        self._move(ids, "delivered")

    @action("cancelled", "Cancel", "Cancel these orders? Their items go back on sale.")
    def action_cancel(self, ids):
        self._move(ids, "cancelled")


class ContactMessageView(SecureView):
    """Write a reply and save: the customer gets it in Notifications."""

    can_create = False
    column_list = ("created_at", "user", "topic", "order", "message", "status")
    column_labels = {"created_at": "Sent", "user": "Customer"}
    column_filters = ("status", "topic", "created_at")
    column_searchable_list = ("message",)
    column_default_sort = ("created_at", True)
    form_columns = ("reply",)
    column_formatters = {
        "user": lambda v, c, m, n: db.session.get(User, m.user_id).full_name,
        "order": lambda v, c, m, n: m.order.order_number if m.order else "",
        "status": lambda v, c, m, n: _badge(m.status, "warning" if m.status == "open" else "success"),
    }

    def update_model(self, form, model):
        try:
            admin_ops.reply_contact(model, form.reply.data)
        except admin_ops.AdminError as e:
            flash(str(e), "error")
            return False
        flash("Reply sent to the customer's Notifications.", "success")
        return True


class CouponView(SecureView):
    column_default_sort = ("id", True)


class ReviewView(SecureView):
    can_create = False
    column_list = ("created_at", "product", "user", "rating", "comment")
    column_formatters = {"product": lambda v, c, m, n: m.product.name, "user": lambda v, c, m, n: m.user.full_name}
    form_columns = ("rating", "comment")


def init_admin(app):
    login_manager.init_app(app)
    login_manager.login_view = "admin.login"
    admin = Admin(
        app,
        name="Anime World Shop",
        index_view=ShopIndexView(name="Dashboard", url="/admin"),
        theme=Bootstrap4Theme(base_template="admin/shop_base.html", swatch="cerulean", fluid=True),
    )
    admin.add_view(ProductView(Product, db, name="Products", endpoint="admin_products", category="Catalog"))
    admin.add_view(CategoryView(Category, db, name="Categories", endpoint="admin_categories", category="Catalog"))
    admin.add_view(SeriesView(Series, db, name="Series", endpoint="admin_series", category="Catalog"))
    admin.add_view(OrderView(Order, db, name="Orders", endpoint="admin_orders"))
    admin.add_view(CustomerView(User, db, name="Customers", endpoint="admin_customers"))
    admin.add_view(ContactMessageView(ContactMessage, db, name="Messages", endpoint="admin_messages"))
    admin.add_view(CouponView(Coupon, db, name="Coupons", endpoint="admin_coupons", category="More"))
    admin.add_view(ReviewView(Review, db, name="Reviews", endpoint="admin_reviews", category="More"))
    admin.add_link(MenuLink(name="API docs", url="/api/docs", category="More"))
    return admin
