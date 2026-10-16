from conftest import login_token

from app.extensions import db
from app.models import Category, Coupon, Order, Product


def _auth(client):
    return {"Authorization": f"Bearer {login_token(client)}"}


def _product(stock=5, price=20, discount=None):
    cat = Category.query.first() or Category(name="Scale Figures", slug="scale-figures")
    n = Product.query.count() + 1
    p = Product(category=cat, name=f"Figure {n}", slug=f"fig-{n}", price=price, discount_price=discount, stock=stock)
    db.session.add(p)
    db.session.commit()
    return p


ADDRESS = {"label": "Home", "recipient_name": "Demo Customer", "phone": "012 345 678",
           "street": "#24 St. 271", "city": "Chamkar Mon", "province": "Phnom Penh"}


def _address(client, h, **extra):
    return client.post("/api/addresses", json={**ADDRESS, **extra}, headers=h).get_json()["data"]


def test_addresses_crud_and_default(client, user):
    h = _auth(client)
    first = _address(client, h)
    assert first["is_default"] is True  # the first one becomes the default
    assert first["one_line"] == "#24 St. 271, Chamkar Mon, Phnom Penh"
    second = _address(client, h, label="Work", is_default=True)
    ids = [a["id"] for a in client.get("/api/addresses", headers=h).get_json()["data"]]
    assert ids == [second["id"], first["id"]]  # default first

    res = client.put(f"/api/addresses/{first['id']}", json={**ADDRESS, "street": "#9 St. 63"}, headers=h)
    assert res.get_json()["data"]["street"] == "#9 St. 63"

    left = client.delete(f"/api/addresses/{second['id']}", headers=h).get_json()["data"]
    assert [a["id"] for a in left] == [first["id"]] and left[0]["is_default"] is True


def test_address_validation(client, user):
    res = client.post("/api/addresses", json={"recipient_name": "", "phone": "abc"}, headers=_auth(client))
    assert res.status_code == 422
    assert set(res.get_json()["errors"]) == {"recipient_name", "phone", "street", "city"}


def test_checkout_preview_pickup_is_free(client, user):
    h = _auth(client)
    p = _product(price=20)
    client.post("/api/cart", json={"product_id": p.id}, headers=h)
    data = client.get("/api/checkout", headers=h).get_json()["data"]
    assert data["shipping_fee"] == 2 and data["total"] == 22
    assert [o["id"] for o in data["delivery_options"]] == ["standard", "pickup"]
    pickup = client.get("/api/checkout?delivery=pickup", headers=h).get_json()["data"]
    assert pickup["shipping_fee"] == 0 and pickup["total"] == 20


def test_place_order_with_coupon_lowers_stock_and_empties_cart(client, user):
    db.session.add(Coupon(code="WELCOME10", description="10% off", discount_type="percent", value=10, max_discount=20, min_subtotal=0))
    db.session.commit()
    h = _auth(client)
    a, b = _product(stock=5, price=40), _product(stock=3, price=15)
    client.post("/api/cart", json={"product_id": a.id, "quantity": 2}, headers=h)
    client.post("/api/cart", json={"product_id": b.id}, headers=h)
    address = _address(client, h)

    res = client.post("/api/orders", json={"address_id": address["id"], "delivery_method": "standard",
                                           "payment_method": "khqr", "coupon": "welcome10", "note": "Call first"}, headers=h)
    assert res.status_code == 201
    order = res.get_json()["data"]
    assert order["subtotal"] == 95 and order["discount"] == 9.5 and order["shipping_fee"] == 0 and order["total"] == 85.5
    assert order["coupon_code"] == "WELCOME10" and order["payment_method"] == "khqr" and order["payment_status"] == "unpaid"
    assert order["shipping"]["address"] == "#24 St. 271, Chamkar Mon, Phnom Penh"
    assert order["order_number"].startswith("AWS-") and order["item_count"] == 3
    assert db.session.get(Product, a.id).stock == 3 and db.session.get(Product, b.id).stock == 2
    assert client.get("/api/cart", headers=h).get_json()["data"]["count"] == 0

    assert [o["id"] for o in client.get("/api/orders", headers=h).get_json()["data"]] == [order["id"]]
    assert client.get(f"/api/orders/{order['id']}", headers=h).get_json()["data"]["note"] == "Call first"


def test_place_order_checks(client, user):
    h = _auth(client)
    assert client.post("/api/orders", json={"delivery_method": "standard", "payment_method": "cod"}, headers=h).status_code == 422
    address = _address(client, h)
    body = {"address_id": address["id"], "delivery_method": "standard", "payment_method": "cod"}
    assert client.post("/api/orders", json=body, headers=h).status_code == 409  # empty cart

    p = _product(stock=2)
    client.post("/api/cart", json={"product_id": p.id, "quantity": 2}, headers=h)
    p.stock = 1
    db.session.commit()
    res = client.post("/api/orders", json=body, headers=h)
    assert res.status_code == 409 and "Only 1 left" in res.get_json()["message"]

    p.stock = 5
    db.session.commit()
    bad = client.post("/api/orders", json={**body, "coupon": "NOPE"}, headers=h)
    assert bad.status_code == 422 and "coupon" in bad.get_json()["errors"]

    pickup = client.post("/api/orders", json={"delivery_method": "pickup", "payment_method": "cod"}, headers=h).get_json()["data"]
    assert pickup["shipping_fee"] == 0 and pickup["shipping"]["address"].startswith("Store pickup")
    assert Order.query.count() == 1
