"""The upgraded /admin dashboard and its one-click actions (Confirm, Ship, +5, Reply)."""
import re

import pytest

from app.extensions import bcrypt, db
from app.models import Category, ContactMessage, Notification, Order, OrderItem, Product, User


@pytest.fixture()
def shop(app, user):
    admin = User(full_name="Admin", email="admin@shop.com", role="admin", password_hash=bcrypt.generate_password_hash("admin123").decode())
    cat = Category(name="Scale Figures", slug="scale-figures")
    p = Product(category=cat, name="Makima", slug="makima", price=245, stock=0)
    o = Order(user_id=user.id, order_number="AWS-20261016-00001", shipping_name="Demo", shipping_phone="012345678", shipping_address="#1",
              subtotal=245, total=245, payment_method="cod")
    o.items.append(OrderItem(product=p, product_name="Makima", unit_price=245, quantity=1, subtotal=245))
    msg = ContactMessage(user_id=user.id, topic="order", message="When will it arrive?")
    db.session.add_all([admin, cat, p, o, msg])
    db.session.commit()
    return {"product": p, "order": o, "message": msg}


def _csrf(html):
    return re.search(r'name="csrf_token" type="hidden" value="([^"]+)"', html).group(1)


def _login(client):
    page = client.get("/admin/login").get_data(as_text=True)
    client.post("/admin/login", data={"email": "admin@shop.com", "password": "admin123", "csrf_token": _csrf(page)})
    return client.get("/admin/").get_data(as_text=True)


def test_dashboard_shows_the_new_layout(client, shop):
    page = _login(client)
    for text in ("Revenue · last 7 days", "Orders to handle", "Live activity", "Low stock", "AWS-20261016-00001", "Confirm",
                 "When will it arrive?", "Sold out", 'id="revenue"', "chart.umd.min.js"):
        assert text in page, text


def test_quick_actions_need_a_valid_token(client, shop):
    _login(client)
    res = client.post(f"/admin/quick/order/{shop['order'].id}", data={"status": "confirmed", "csrf_token": "forged"}, follow_redirects=True)
    assert "Please try again" in res.get_data(as_text=True)
    assert db.session.get(Order, shop["order"].id).status == "pending"


def test_confirm_restock_and_reply_from_the_dashboard(client, shop, user):
    token = _csrf(_login(client))
    res = client.post(f"/admin/quick/order/{shop['order'].id}", data={"status": "confirmed", "csrf_token": token}, follow_redirects=True)
    assert "marked confirmed. The customer was told." in res.get_data(as_text=True)
    assert db.session.get(Order, shop["order"].id).status == "confirmed"
    assert Notification.query.filter_by(user_id=user.id, event="confirmed").count() == 1

    res = client.post(f"/admin/quick/restock/{shop['product'].id}", data={"csrf_token": token}, follow_redirects=True)
    assert "Makima restocked: 5 in stock." in res.get_data(as_text=True)
    assert db.session.get(Product, shop["product"].id).stock == 5

    res = client.post(f"/admin/quick/reply/{shop['message'].id}", data={"reply": "Tomorrow!", "csrf_token": token}, follow_redirects=True)
    assert "Reply sent" in res.get_data(as_text=True)
    m = db.session.get(ContactMessage, shop["message"].id)
    assert m.status == "answered" and m.reply == "Tomorrow!"

    # a step that is not allowed is explained, not done
    res = client.post(f"/admin/quick/order/{shop['order'].id}", data={"status": "delivered", "csrf_token": token}, follow_redirects=True)
    assert "cannot be marked delivered" in res.get_data(as_text=True)


def test_list_pages_have_row_buttons_that_come_back(client, shop):
    _login(client)
    orders = client.get("/admin/admin_orders/").get_data(as_text=True)
    assert f'action="/admin/quick/order/{shop["order"].id}"' in orders and ">Confirm</button>" in orders
    products = client.get("/admin/admin_products/").get_data(as_text=True)
    assert f'action="/admin/quick/restock/{shop["product"].id}"' in products

    token = _csrf(products)
    res = client.post(f"/admin/quick/restock/{shop['product'].id}", data={"csrf_token": token, "next": "/admin/admin_products/"})
    assert res.headers["Location"] == "/admin/admin_products/"
    # never back to another site
    res = client.post(f"/admin/quick/restock/{shop['product'].id}", data={"csrf_token": token, "next": "https://evil.example/"})
    assert res.headers["Location"] == "/admin/"
