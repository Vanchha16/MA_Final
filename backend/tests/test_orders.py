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


# ---------- KHQR ----------

def _khqr_order(client, h, stock=5):
    p = _product(stock=stock, price=30)
    client.post("/api/cart", json={"product_id": p.id, "quantity": 2}, headers=h)
    address = _address(client, h)
    order = client.post("/api/orders", json={"address_id": address["id"], "delivery_method": "standard",
                                             "payment_method": "khqr"}, headers=h).get_json()["data"]
    return p, order


def test_khqr_is_made_once_and_simulated_payment_confirms(client, user):
    h = _auth(client)
    _, order = _khqr_order(client, h)
    first = client.post(f"/api/orders/{order['id']}/khqr", headers=h).get_json()["data"]["payment"]
    again = client.post(f"/api/orders/{order['id']}/khqr", headers=h).get_json()["data"]["payment"]
    assert first["qr"] == again["qr"] and first["qr"].startswith("0002")
    assert first["amount"] == 60 and first["status"] == "pending" and first["demo"] is True

    assert client.get(f"/api/orders/{order['id']}/payment", headers=h).get_json()["data"]["payment"]["status"] == "pending"
    data = client.post(f"/api/orders/{order['id']}/payment/simulate", headers=h).get_json()["data"]
    assert data["payment"]["status"] == "paid" and data["payment"]["paid_at"]
    assert data["order"]["status"] == "confirmed" and data["order"]["payment_status"] == "paid"


def test_khqr_expiry_cancels_the_order_and_restocks(client, user):
    from app.models import Payment

    h = _auth(client)
    p, order = _khqr_order(client, h, stock=5)
    client.post(f"/api/orders/{order['id']}/khqr", headers=h)
    assert db.session.get(Product, p.id).stock == 3
    payment = Payment.query.one()
    payment.expires_at = payment.expires_at.replace(year=2000)
    db.session.commit()

    data = client.get(f"/api/orders/{order['id']}/payment", headers=h).get_json()["data"]
    assert data["payment"]["status"] == "expired" and data["order"]["status"] == "cancelled"
    assert db.session.get(Product, p.id).stock == 5
    assert client.post(f"/api/orders/{order['id']}/payment/simulate", headers=h).status_code == 409
    assert client.post(f"/api/orders/{order['id']}/khqr", headers=h).status_code == 409


def test_khqr_rules(client, user, app):
    h = _auth(client)
    p = _product()
    client.post("/api/cart", json={"product_id": p.id}, headers=h)
    cod = client.post("/api/orders", json={"delivery_method": "pickup", "payment_method": "cod"}, headers=h).get_json()["data"]
    assert client.post(f"/api/orders/{cod['id']}/khqr", headers=h).status_code == 409
    assert client.get(f"/api/orders/{cod['id']}/payment", headers=h).status_code == 404

    _, order = _khqr_order(client, h)
    client.post(f"/api/orders/{order['id']}/khqr", headers=h)
    app.config["PAYMENT_PROVIDER"] = "bakong"
    try:
        assert client.post(f"/api/orders/{order['id']}/payment/simulate", headers=h).status_code == 403
    finally:
        app.config["PAYMENT_PROVIDER"] = "mock"


def test_khqr_for_an_order_already_paid_is_refused(client, user):
    h = _auth(client)
    _, order = _khqr_order(client, h)
    o = db.session.get(Order, order["id"])
    o.payment_status, o.status = "paid", "delivered"  # e.g. an old demo order
    db.session.commit()
    assert client.post(f"/api/orders/{order['id']}/khqr", headers=h).status_code == 409


def test_orders_list_has_items_and_got_it_marks_delivered(client, user):
    h = _auth(client)
    p = _product(stock=5, price=30)
    client.post("/api/cart", json={"product_id": p.id}, headers=h)
    order = client.post("/api/orders", json={"delivery_method": "pickup", "payment_method": "cod"}, headers=h).get_json()["data"]

    listed = client.get("/api/orders", headers=h).get_json()["data"]
    assert listed[0]["items"][0]["product_name"] == p.name and "image_url" in listed[0]["items"][0]
    assert listed[0]["items"][0]["category"]["slug"] == "scale-figures"

    assert client.post(f"/api/orders/{order['id']}/received", headers=h).status_code == 409  # not shipped yet
    o = db.session.get(Order, order["id"])
    o.status = "shipped"
    db.session.commit()
    data = client.post(f"/api/orders/{order['id']}/received", headers=h).get_json()["data"]
    assert data["status"] == "delivered" and data["payment_status"] == "paid"
    assert client.post("/api/orders/999/received", headers=h).status_code == 404


def test_orders_list_cancels_expired_khqr(client, user):
    from app.models import Payment

    h = _auth(client)
    _, order = _khqr_order(client, h)
    client.post(f"/api/orders/{order['id']}/khqr", headers=h)
    payment = Payment.query.one()
    payment.expires_at = payment.expires_at.replace(year=2000)
    db.session.commit()
    assert client.get("/api/orders", headers=h).get_json()["data"][0]["status"] == "cancelled"
