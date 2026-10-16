"""Input checks found missing in the validation review: wrong types, too-long text,
admin product rules, filters, attempt limits, signing out after a password change,
fake photos and overselling the last item."""
import io

import pytest
from conftest import TestConfig, login_token

from app import create_app
from app.extensions import bcrypt, db, limiter
from app.models import Address, Category, ContactMessage, Order, Product, User


def _auth(client, email="demo@shop.com", password="demo123"):
    return {"Authorization": f"Bearer {login_token(client, email, password)}"}


def _product(stock=5, price=87, discount=None, name="Luffy"):
    cat = Category.query.first() or Category(name="Scale Figures", slug="scale-figures")
    p = Product(category=cat, name=name, slug=name.lower(), price=price, discount_price=discount, stock=stock)
    db.session.add(p)
    db.session.commit()
    return p


@pytest.fixture()
def admin(app):
    a = User(full_name="Admin", email="admin@shop.com", role="admin", password_hash=bcrypt.generate_password_hash("demo123").decode())
    db.session.add(a)
    db.session.commit()
    return a


# ---------- 1. wrong types answer 422, never "Internal server error" ----------

@pytest.mark.parametrize("path,body", [
    ("/api/auth/register", {"full_name": "Sok Dara", "email": 123, "password": "secret1"}),
    ("/api/auth/register", {"full_name": "Sok Dara", "email": "dara@shop.com", "password": 123456}),
    ("/api/auth/login", {"email": 123, "password": "x"}),
    ("/api/auth/login", {"email": "demo@shop.com", "password": 123}),
    ("/api/auth/forgot-password", {"email": 5}),
    ("/api/auth/verify-otp", {"email": 5, "code": "123456"}),
    ("/api/auth/verify-otp", {"email": "demo@shop.com", "code": "12ab"}),
    ("/api/auth/reset-password", {"reset_token": ["x"], "new_password": "secret1"}),
])
def test_auth_wrong_types_are_422(client, user, path, body):
    res = client.post(path, json=body)
    assert res.status_code == 422, res.get_json()


def test_body_that_is_not_an_object_is_422(client, user):
    res = client.post("/api/auth/register", json=["not", "an", "object"])
    assert res.status_code == 422
    assert set(res.get_json()["errors"]) == {"full_name", "email", "password"}


def test_profile_and_cart_wrong_types_are_422(client, user):
    h = _auth(client)
    assert client.put("/api/profile", json={"full_name": ["xy"]}, headers=h).status_code == 422
    assert client.put("/api/profile/password", json={"current_password": "demo123", "new_password": 1234567}, headers=h).status_code == 422
    assert client.post("/api/cart/coupon", json={"code": 5}, headers=h).status_code == 422
    assert client.post("/api/cart", json={"product_id": True}, headers=h).status_code == 422
    p = _product()
    assert client.post("/api/cart", json={"product_id": p.id, "quantity": True}, headers=h).status_code == 422


def test_order_with_bad_coupon_or_note_is_422(client, user):
    h = _auth(client)
    p = _product()
    client.post("/api/cart", json={"product_id": p.id}, headers=h)
    base = {"delivery_method": "pickup", "payment_method": "cod"}
    for extra, field in (({"coupon": 5}, "coupon"), ({"note": "x" * 256}, "note"), ({"delivery_method": []}, "delivery_method")):
        res = client.post("/api/orders", json={**base, **extra}, headers=h)
        assert res.status_code == 422 and field in res.get_json()["errors"], extra


def test_admin_wrong_types_are_422(client, admin):
    h = _auth(client, "admin@shop.com")
    p = _product()
    order = Order(order_number="AWS-0001", user_id=admin.id, shipping_name="A", shipping_phone="012345678",
                  shipping_address="Shop", subtotal=1, total=1)
    db.session.add(order)
    db.session.commit()
    res = client.put(f"/api/admin/orders/{order.id}/status", json={"status": ["shipped"]}, headers=h)
    assert res.status_code == 409 and "Unknown status" in res.get_json()["message"]
    assert client.post("/api/admin/categories", json={"name": 7}, headers=h).status_code == 422
    msg = ContactMessage(user_id=admin.id, topic="other", message="Hi")
    db.session.add(msg)
    db.session.commit()
    assert client.post(f"/api/admin/contact-messages/{msg.id}/reply", json={"reply": 5}, headers=h).status_code == 422
    assert client.post(f"/api/admin/contact-messages/{msg.id}/reply", json={"reply": "x" * 2001}, headers=h).status_code == 422
    assert client.put(f"/api/admin/products/{p.id}", json={"price": "nan"}, headers=h).status_code == 422


# ---------- 2. too-long text is refused, not cut ----------

def test_long_text_is_refused(client, user):
    long_name = {"full_name": "N" * 101, "email": "new@shop.com", "password": "secret1"}
    res = client.post("/api/auth/register", json=long_name)
    assert res.status_code == 422 and "under 100" in res.get_json()["errors"]["full_name"]
    res = client.post("/api/auth/register", json={"full_name": "Sok Dara", "email": "e" * 150 + "@shop.com", "password": "secret1"})
    assert res.status_code == 422 and "email" in res.get_json()["errors"]
    res = client.post("/api/auth/register", json={"full_name": "Sok Dara", "email": "dara@shop.com", "password": "p" * 73})
    assert res.status_code == 422 and "password" in res.get_json()["errors"]
    h = _auth(client)
    assert client.put("/api/profile", json={"full_name": "D" * 101}, headers=h).status_code == 422

    address = {"recipient_name": "Demo", "phone": "012 345 678", "street": "St. 271", "city": "Chamkar Mon"}
    for field, size in (("province", 101), ("postal_code", 21), ("label", 51), ("street", 256), ("recipient_name", 101)):
        res = client.post("/api/addresses", json={**address, field: "x" * size}, headers=h)
        assert res.status_code == 422 and field in res.get_json()["errors"], field
    assert Address.query.count() == 0


# ---------- 3. wrong results ----------

def test_names_need_letters_and_phones_are_cambodian(client, user):
    res = client.post("/api/auth/register", json={"full_name": ".", "email": "dot@shop.com", "password": "secret1"})
    assert res.status_code == 422 and "full_name" in res.get_json()["errors"]
    res = client.post("/api/auth/register", json={"full_name": "12345", "email": "num@shop.com", "password": "secret1"})
    assert res.get_json()["errors"]["full_name"] == "Name needs letters"
    # Khmer names are fine
    assert client.post("/api/auth/register", json={"full_name": "សុខ ដារា", "email": "km@shop.com", "password": "secret1"}).status_code == 201

    h = _auth(client)
    address = {"recipient_name": "Demo", "street": "St. 271", "city": "Chamkar Mon"}
    assert client.post("/api/addresses", json={**address, "phone": "12345678"}, headers=h).status_code == 422
    saved = client.post("/api/addresses", json={**address, "phone": "012 345-678"}, headers=h)
    assert saved.status_code == 201 and saved.get_json()["data"]["phone"] == "012345678"


def test_admin_product_rules(client, admin):
    h = _auth(client, "admin@shop.com")
    p = _product(price=87, discount=80)

    def put(body):
        return client.put(f"/api/admin/products/{p.id}", json=body, headers=h)

    res = put({"is_active": "false"})
    assert res.status_code == 422 and db.session.get(Product, p.id).is_active is True
    assert put({"is_active": False}).get_json()["data"]["is_active"] is False
    assert put({"price": 1e12}).status_code == 422
    assert put({"price": "inf"}).status_code == 422
    assert put({"stock": 2.9}).get_json()["errors"]["stock"] == "Stock must be a whole number"
    assert put({"stock": 100_001}).status_code == 422
    assert put({"stock": "7"}).get_json()["data"]["stock"] == 7
    # lowering only the price below the sale price is refused
    res = put({"price": 50})
    assert res.status_code == 422 and res.get_json()["errors"]["discount_price"] == "Sale price must be lower than the price"
    assert float(db.session.get(Product, p.id).price) == 87
    assert put({"price": 99.999}).get_json()["data"]["price"] == 100.0  # rounded to cents
    assert put({"brand": "B" * 101}).status_code == 422


def test_product_price_filters(client):
    _product()
    assert client.get("/api/products?min_price=50&max_price=10").status_code == 422
    assert client.get("/api/products?min_price=-5").status_code == 422
    assert client.get("/api/products?max_price=abc").status_code == 422
    assert client.get("/api/products?min_price=10&max_price=100").get_json()["data"]["total"] == 1


# ---------- 4. limits, sessions and photos ----------

@pytest.fixture()
def limited_client():
    """An app with the attempt limits on (they are off in the other tests)."""
    class Limited(TestConfig):
        RATELIMIT_ENABLED = True

    app = create_app(Limited)
    with app.app_context():
        db.create_all()
        db.session.add(User(full_name="Demo Customer", email="demo@shop.com", password_hash=bcrypt.generate_password_hash("demo123").decode()))
        db.session.commit()
        limiter.reset()
        yield app.test_client()
        limiter.reset()
        db.session.remove()
        db.drop_all()


def test_login_attempts_are_limited(limited_client):
    c = limited_client
    for _ in range(10):
        assert c.post("/api/auth/login", json={"email": "demo@shop.com", "password": "wrong"}).status_code == 401
    res = c.post("/api/auth/login", json={"email": "demo@shop.com", "password": "demo123"})
    assert res.status_code == 429
    assert "Too many" in res.get_json()["message"] and res.get_json()["success"] is False


def test_contact_messages_are_limited(limited_client):
    c = limited_client
    h = _auth(c)
    for _ in range(5):
        assert c.post("/api/contact", json={"topic": "other", "message": "Hello"}, headers=h).status_code == 201
    res = c.post("/api/contact", json={"topic": "other", "message": "Hello again"}, headers=h)
    assert res.status_code == 429 and ContactMessage.query.count() == 5


def test_changing_the_password_signs_out_other_devices(client, user):
    phone = _auth(client)
    laptop = _auth(client)
    res = client.put("/api/profile/password", json={"current_password": "demo123", "new_password": "newpass1"}, headers=laptop)
    assert res.status_code == 200
    fresh = {"Authorization": f"Bearer {res.get_json()['data']['token']}"}
    assert client.get("/api/auth/me", headers=fresh).status_code == 200  # this device stays in
    old = client.get("/api/auth/me", headers=phone)
    assert old.status_code == 401 and old.get_json()["message"] == "Your password was changed. Please log in again."
    assert client.get("/api/auth/me", headers=laptop).status_code == 401


def test_fake_photo_is_refused(app, client, user, tmp_path):
    app.config["UPLOAD_FOLDER"] = str(tmp_path)
    fake = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64  # right first bytes, not a picture
    res = client.post("/api/profile/avatar", headers=_auth(client),
                      data={"file": (io.BytesIO(fake), "me.png")}, content_type="multipart/form-data")
    assert res.status_code == 422 and res.get_json()["errors"]["file"] == "This photo could not be opened"


# ---------- 5. two customers, one last item ----------

def test_last_item_cannot_be_sold_twice(client, user):
    p = _product(stock=1)
    dara = User(full_name="Sok Dara", email="dara@shop.com", password_hash=bcrypt.generate_password_hash("demo123").decode())
    db.session.add(dara)
    db.session.commit()
    demo, other = _auth(client), _auth(client, "dara@shop.com")
    # both put the last one in their cart
    for h in (demo, other):
        assert client.post("/api/cart", json={"product_id": p.id}, headers=h).status_code == 201
    order = {"delivery_method": "pickup", "payment_method": "cod"}
    first = client.post("/api/orders", json=order, headers=demo)
    assert first.status_code == 201
    second = client.post("/api/orders", json=order, headers=other)
    assert second.status_code == 409
    assert db.session.get(Product, p.id).stock == 0
    assert Order.query.count() == 1


def test_stock_taken_between_the_check_and_the_sale(client, user, monkeypatch):
    """The other buyer pays for the last one after our cart was checked but before our
    stock update: the conditional UPDATE matches no row, so nothing is sold twice."""
    from app.routes import orders as orders_route

    p = _product(stock=1)
    h = _auth(client)
    client.post("/api/cart", json={"product_id": p.id}, headers=h)
    real = orders_route._cart_items

    def cart_then_someone_else_buys(user_id):
        items = real(user_id)  # loaded with stock = 1
        db.session.execute(db.text("UPDATE products SET stock = 0 WHERE id = :id"), {"id": p.id})
        return items

    monkeypatch.setattr(orders_route, "_cart_items", cart_then_someone_else_buys)
    res = client.post("/api/orders", json={"delivery_method": "pickup", "payment_method": "cod"}, headers=h)
    assert res.status_code == 409 and "sold out" in res.get_json()["message"]
    assert Order.query.count() == 0


def test_order_numbers_come_from_the_order_id(client, user):
    p = _product(stock=5)
    h = _auth(client)
    numbers = []
    for _ in range(2):
        client.post("/api/cart", json={"product_id": p.id}, headers=h)
        numbers.append(client.post("/api/orders", json={"delivery_method": "pickup", "payment_method": "cod"}, headers=h).get_json()["data"]["order_number"])
    ids = [o.id for o in Order.query.order_by(Order.id)]
    assert [n.rsplit("-", 1)[1] for n in numbers] == [f"{i:05d}" for i in ids]
    assert len(set(numbers)) == 2
