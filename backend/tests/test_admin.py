import io

import pytest
from conftest import login_token
from PIL import Image

from app.extensions import bcrypt, db
from app.models import Category, Notification, Order, OrderItem, Payment, Product, User


@pytest.fixture()
def admin(app):
    u = User(full_name="Admin", email="admin@shop.com", role="admin", password_hash=bcrypt.generate_password_hash("admin123").decode())
    db.session.add(u)
    db.session.commit()
    return u


def _h(client, email="admin@shop.com", password="admin123"):
    return {"Authorization": f"Bearer {login_token(client, email, password)}"}


@pytest.fixture()
def catalog(app):
    figures = Category(name="Scale Figures", slug="scale-figures")
    luffy = Product(category=figures, name="Luffy Gear 5", slug="luffy-gear-5", price=189, stock=5)
    db.session.add_all([figures, luffy])
    db.session.commit()
    return figures, luffy


def _order(user, product, status="pending", payment="cod", paid="unpaid", qty=2):
    product.stock -= qty
    o = Order(user_id=user.id, order_number=f"AWS-{Order.query.count() + 1:04d}", shipping_name="Demo", shipping_phone="012345678",
              shipping_address="#1 St. 2", subtotal=product.price * qty, total=product.price * qty, status=status,
              payment_method=payment, payment_status=paid)
    o.items.append(OrderItem(product_id=product.id, product_name=product.name, unit_price=product.price, quantity=qty, subtotal=product.price * qty))
    db.session.add(o)
    db.session.commit()
    return o


def test_customers_and_guests_cannot_use_the_admin_api(client, user, admin):
    assert client.get("/api/admin/stats").status_code == 401
    res = client.get("/api/admin/stats", headers=_h(client, "demo@shop.com", "demo123"))
    assert res.status_code == 403 and res.get_json()["message"] == "Admins only"
    assert client.get("/api/admin/stats", headers=_h(client)).status_code == 200


def test_add_edit_and_hide_a_product(client, admin, catalog):
    figures, _ = catalog
    h = _h(client)
    res = client.post("/api/admin/products", json={"name": "Zoro 1/8", "category_id": figures.id, "price": 120, "discount_price": 99, "stock": 4, "brand": "MegaHouse"}, headers=h)
    assert res.status_code == 201
    p = res.get_json()["data"]
    assert p["slug"] == "zoro-1-8" and p["discount_price"] == 99 and p["is_active"] is True

    res = client.put(f"/api/admin/products/{p['id']}", json={"stock": 10, "discount_price": None, "is_featured": True}, headers=h)
    data = res.get_json()["data"]
    assert data["stock"] == 10 and data["discount_price"] is None and data["is_featured"] is True and data["price"] == 120

    assert client.delete(f"/api/admin/products/{p['id']}", headers=h).get_json()["data"]["is_active"] is False
    # Hidden from the shop, still listed for the admin
    assert client.get(f"/api/products/{p['id']}").status_code == 404
    assert client.get("/api/admin/products?active=0", headers=h).get_json()["data"]["total"] == 1


def test_product_validation(client, admin, catalog):
    figures, luffy = catalog
    h = _h(client)
    res = client.post("/api/admin/products", json={"category_id": 999, "price": -1}, headers=h)
    assert res.status_code == 422
    assert set(res.get_json()["errors"]) == {"name", "category_id", "price"}
    res = client.put(f"/api/admin/products/{luffy.id}", json={"discount_price": 500, "stock": -2}, headers=h)
    assert set(res.get_json()["errors"]) == {"discount_price", "stock"}
    assert db.session.get(Product, luffy.id).stock == 5  # nothing saved
    assert Product.query.count() == 1


def test_upload_and_remove_product_photos(app, client, admin, catalog, tmp_path):
    app.config["UPLOAD_FOLDER"] = str(tmp_path)
    _, luffy = catalog
    h = _h(client)

    def png(color):
        buf = io.BytesIO()
        Image.new("RGB", (40, 20), color).save(buf, "PNG")
        buf.seek(0)
        return buf

    first = client.post(f"/api/admin/products/{luffy.id}/images", data={"file": (png("red"), "a.png")}, headers=h, content_type="multipart/form-data")
    assert first.status_code == 201
    client.post(f"/api/admin/products/{luffy.id}/images", data={"file": (png("blue"), "b.png")}, headers=h, content_type="multipart/form-data")
    photos = client.get(f"/api/admin/products/{luffy.id}", headers=h).get_json()["data"]["photos"]
    assert [p["is_primary"] for p in photos] == [True, False]
    assert all(p["url"].endswith(".webp") for p in photos)
    assert len(list((tmp_path / "catalog").iterdir())) == 2

    res = client.delete(f"/api/admin/products/{luffy.id}/images/{photos[0]['id']}", headers=h)
    left = res.get_json()["data"]["photos"]
    assert len(left) == 1 and left[0]["is_primary"] is True
    assert len(list((tmp_path / "catalog").iterdir())) == 1

    bad = client.post(f"/api/admin/products/{luffy.id}/images", data={"file": (io.BytesIO(b"not an image"), "x.png")}, headers=h, content_type="multipart/form-data")
    assert bad.status_code == 422


def test_categories(client, admin, catalog):
    figures, _ = catalog
    h = _h(client)
    res = client.post("/api/admin/categories", json={"name": "Plush & Merch", "description": "Soft toys"}, headers=h)
    assert res.status_code == 201 and res.get_json()["data"]["slug"] == "plush-merch"
    plush = res.get_json()["data"]
    assert client.post("/api/admin/categories", json={"name": "plush & merch"}, headers=h).status_code == 422
    assert client.put(f"/api/admin/categories/{plush['id']}", json={"name": "Plushies"}, headers=h).get_json()["data"]["name"] == "Plushies"
    listed = {c["name"]: c["product_count"] for c in client.get("/api/admin/categories", headers=h).get_json()["data"]}
    assert listed == {"Scale Figures": 1, "Plushies": 0}

    res = client.delete(f"/api/admin/categories/{figures.id}", headers=h)
    assert res.status_code == 409 and "still has 1 product" in res.get_json()["message"]
    assert client.delete(f"/api/admin/categories/{plush['id']}", headers=h).status_code == 200


def test_block_a_customer(client, user, admin):
    customer_h = _h(client, "demo@shop.com", "demo123")
    h = _h(client)
    found = client.get("/api/admin/customers?q=demo", headers=h).get_json()["data"]
    assert found["total"] == 1 and found["items"][0]["email"] == "demo@shop.com"

    assert client.put(f"/api/admin/customers/{user.id}", json={"is_active": False}, headers=h).get_json()["data"]["is_active"] is False
    # The token they already have stops working, and they cannot log in again
    res = client.get("/api/auth/me", headers=customer_h)
    assert res.status_code == 403 and res.get_json()["message"] == "This account has been disabled"
    assert login_token(client, "demo@shop.com", "demo123") is None

    client.put(f"/api/admin/customers/{user.id}", json={"is_active": True}, headers=h)
    assert login_token(client, "demo@shop.com", "demo123") is not None
    # Admins are not customers here
    assert client.put(f"/api/admin/customers/{admin.id}", json={"is_active": False}, headers=h).status_code == 404
    assert client.put(f"/api/admin/customers/{user.id}", json={"is_active": "no"}, headers=h).status_code == 422


def test_order_steps_notify_and_cancel_restocks(client, user, admin, catalog):
    _, luffy = catalog
    order = _order(user, luffy)
    h = _h(client)
    listed = client.get("/api/admin/orders?status=pending", headers=h).get_json()["data"]
    assert listed["items"][0]["next_statuses"] == ["confirmed", "cancelled"]
    assert listed["items"][0]["customer"]["email"] == "demo@shop.com"

    for status in ("confirmed", "shipped", "delivered"):
        res = client.put(f"/api/admin/orders/{order.id}/status", json={"status": status}, headers=h)
        assert res.status_code == 200, res.get_json()
    data = res.get_json()["data"]
    assert data["status"] == "delivered" and data["payment_status"] == "paid"  # cash collected
    assert [n.event for n in Notification.query.order_by(Notification.id)] == ["confirmed", "shipped", "delivered"]
    assert client.put(f"/api/admin/orders/{order.id}/status", json={"status": "cancelled"}, headers=h).status_code == 409

    second = _order(user, luffy, qty=1)
    assert db.session.get(Product, luffy.id).stock == 2
    client.put(f"/api/admin/orders/{second.id}/status", json={"status": "cancelled"}, headers=h)
    assert db.session.get(Product, luffy.id).stock == 3


def test_unpaid_khqr_orders_can_only_be_cancelled(client, user, admin, catalog):
    _, luffy = catalog
    order = _order(user, luffy, payment="khqr")
    db.session.add(Payment(order_id=order.id, provider="mock", qr="x", md5="0" * 32, amount=order.total, expires_at=order.created_at))
    db.session.commit()
    h = _h(client)
    res = client.put(f"/api/admin/orders/{order.id}/status", json={"status": "confirmed"}, headers=h)
    assert res.status_code == 409
    client.put(f"/api/admin/orders/{order.id}/status", json={"status": "cancelled"}, headers=h)
    assert Payment.query.one().status == "expired"


def test_reply_to_a_contact_message(client, user, admin):
    client.post("/api/contact", json={"topic": "other", "message": "Do you sell posters?"}, headers=_h(client, "demo@shop.com", "demo123"))
    h = _h(client)
    msg = client.get("/api/admin/contact-messages?status=open", headers=h).get_json()["data"]["items"][0]
    assert msg["customer"]["full_name"] == "Demo Customer"
    assert client.post(f"/api/admin/contact-messages/{msg['id']}/reply", json={"reply": " "}, headers=h).status_code == 422
    res = client.post(f"/api/admin/contact-messages/{msg['id']}/reply", json={"reply": "Not yet!"}, headers=h)
    assert res.get_json()["data"]["status"] == "answered"
    assert Notification.query.filter_by(event="support").one().message == "Not yet!"


def test_stats(client, user, admin, catalog):
    _, luffy = catalog
    _order(user, luffy, status="confirmed", paid="paid")
    data = client.get("/api/admin/stats", headers=_h(client)).get_json()["data"]
    assert data["products"] == 1 and data["customers"] == 1 and data["orders_to_handle"] == 1
    assert data["revenue"] == 378.0 and data["low_stock"] == 1


def test_activity_feed_and_week_revenue(client, user, admin, catalog):
    from app.models import ContactMessage
    from app.utils.clock import utcnow

    _, luffy = catalog
    cash = _order(user, luffy, qty=1)
    khqr = _order(user, luffy, status="confirmed", payment="khqr", paid="paid", qty=1)
    db.session.add(Payment(order_id=khqr.id, provider="mock", qr="x", md5="1" * 32, amount=khqr.total, status="paid",
                           expires_at=utcnow(), paid_at=utcnow()))
    db.session.add(ContactMessage(user_id=user.id, topic="other", message="Posters?"))
    luffy.stock = 0
    db.session.commit()
    h = _h(client)

    events = {e["id"]: e for e in client.get("/api/admin/activity", headers=h).get_json()["data"]}
    assert events[f"order-{cash.id}"]["action"] == "confirm"
    assert events[f"paid-{khqr.id}"]["action"] == "ship" and events[f"paid-{khqr.id}"]["kind"] == "paid"
    assert events[f"order-{khqr.id}"]["action"] is None  # the payment event carries Ship
    assert next(e for e in events.values() if e["kind"] == "message")["action"] == "reply"
    assert events[f"stock-{luffy.id}"]["action"] == "restock"

    client.put(f"/api/admin/orders/{khqr.id}/status", json={"status": "shipped"}, headers=h)
    events = {e["id"]: e for e in client.get("/api/admin/activity", headers=h).get_json()["data"]}
    assert events[f"paid-{khqr.id}"]["action"] is None and events[f"paid-{khqr.id}"]["status"] == "shipped"

    stats = client.get("/api/admin/stats", headers=h).get_json()["data"]
    assert len(stats["week"]) == 7 and stats["week"][-1]["date"] == utcnow().date().isoformat()
    assert stats["week"][-1]["revenue"] == 189.0 and stats["week_revenue"] == 189.0
