import re

import pytest

from app.extensions import bcrypt, db
from app.models import Category, Notification, Order, OrderItem, Product, User


@pytest.fixture()
def admin(app):
    u = User(full_name="Admin", email="admin@shop.com", role="admin", password_hash=bcrypt.generate_password_hash("admin123").decode())
    db.session.add(u)
    db.session.commit()
    return u


def _csrf(html):
    return re.search(r'name="csrf_token" type="hidden" value="([^"]+)"', html).group(1)


def _login(client, email="admin@shop.com", password="admin123"):
    page = client.get("/admin/login").get_data(as_text=True)
    return client.post("/admin/login", data={"email": email, "password": password, "csrf_token": _csrf(page)})


def test_the_panel_needs_an_admin_login(client, user, admin):
    assert client.get("/admin/").headers["Location"].startswith("/admin/login")
    assert client.get("/admin/admin_orders/").status_code == 302

    page = _login(client, "demo@shop.com", "demo123").get_data(as_text=True)
    assert "not an admin account" in page
    assert client.get("/admin/admin_orders/").status_code == 302

    assert _login(client).status_code == 302
    dashboard = client.get("/admin/").get_data(as_text=True)
    assert "Orders to handle" in dashboard and "admin@shop.com" in dashboard
    client.get("/admin/logout")
    assert client.get("/admin/").status_code == 302


def test_every_page_opens(client, admin):
    _login(client)
    for page in ("admin_products", "admin_categories", "admin_series", "admin_orders", "admin_customers", "admin_messages", "admin_coupons", "admin_reviews"):
        assert client.get(f"/admin/{page}/").status_code == 200, page
    assert client.get("/admin/admin_products/new/").status_code == 200


def test_order_actions_move_orders_and_notify(client, user, admin):
    cat = Category(name="Scale Figures", slug="scale-figures")
    p = Product(category=cat, name="Luffy", slug="luffy", price=100, stock=3)
    o = Order(user_id=user.id, order_number="AWS-0001", shipping_name="Demo", shipping_phone="012345678", shipping_address="#1",
              subtotal=100, total=100, payment_method="cod")
    o.items.append(OrderItem(product=p, product_name="Luffy", unit_price=100, quantity=1, subtotal=100))
    db.session.add_all([cat, p, o])
    db.session.commit()
    _login(client)
    page = client.get("/admin/admin_orders/").get_data(as_text=True)

    res = client.post("/admin/admin_orders/action/", data={"action": "confirmed", "rowid": [str(o.id)], "csrf_token": _csrf(page)}, follow_redirects=True)
    assert "1 order(s) marked confirmed" in res.get_data(as_text=True)
    assert db.session.get(Order, o.id).status == "confirmed"
    assert Notification.query.one().event == "confirmed"

    # A step that is not allowed is skipped, not forced
    res = client.post("/admin/admin_orders/action/", data={"action": "delivered", "rowid": [str(o.id)], "csrf_token": _csrf(page)}, follow_redirects=True)
    assert "Not changed" in res.get_data(as_text=True)
    assert db.session.get(Order, o.id).status == "confirmed"


def test_block_a_customer_from_the_panel(client, user, admin):
    _login(client)
    page = client.get("/admin/admin_customers/").get_data(as_text=True)
    assert "demo@shop.com" in page
    assert page.count("admin@shop.com") == 1  # only in the top bar: admins are not listed
    client.post("/admin/admin_customers/action/", data={"action": "block", "rowid": [str(user.id)], "csrf_token": _csrf(page)})
    assert db.session.get(User, user.id).is_active is False


def test_deleting_a_product_hides_it(client, admin):
    cat = Category(name="Scale Figures", slug="scale-figures")
    p = Product(category=cat, name="Luffy", slug="luffy", price=100, stock=3)
    db.session.add_all([cat, p])
    db.session.commit()
    _login(client)
    page = client.get("/admin/admin_products/").get_data(as_text=True)
    client.post("/admin/admin_products/delete/", data={"id": str(p.id), "csrf_token": _csrf(page)})
    assert db.session.get(Product, p.id).is_active is False


def test_add_a_product_with_a_photo(app, client, admin, tmp_path):
    import io

    from PIL import Image

    app.config["UPLOAD_FOLDER"] = str(tmp_path)
    cat = Category(name="Scale Figures", slug="scale-figures")
    db.session.add(cat)
    db.session.commit()
    _login(client)
    page = client.get("/admin/admin_products/new/").get_data(as_text=True)
    photo = io.BytesIO()
    Image.new("RGB", (30, 40), "green").save(photo, "PNG")
    photo.seek(0)
    client.post("/admin/admin_products/new/", content_type="multipart/form-data", data={
        "csrf_token": _csrf(page), "name": "Zoro 1/8", "category": str(cat.id), "price": "120", "stock": "4",
        "is_active": "y", "new_photos": (photo, "zoro.png"),
    })
    p = Product.query.one()
    assert p.slug == "zoro-1-8" and p.photo_url.endswith(".webp") and p.images[0].is_primary
