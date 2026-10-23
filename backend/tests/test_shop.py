from conftest import login_token

from app.extensions import db
from app.models import Category, Favorite, Product


def _auth(client):
    return {"Authorization": f"Bearer {login_token(client)}"}


def _product(stock=5, price=20, discount=None, active=True):
    cat = Category.query.first() or Category(name="Scale Figures", slug="scale-figures")
    p = Product(category=cat, name=f"Figure {Product.query.count() + 1}", slug=f"fig-{Product.query.count() + 1}",
                price=price, discount_price=discount, stock=stock, is_active=active)
    db.session.add(p)
    db.session.commit()
    return p


def test_wishlist_requires_login(client):
    assert client.get("/api/wishlist").status_code == 401


def test_wishlist_add_is_idempotent_and_remove_works(client, user):
    p = _product()
    h = _auth(client)
    for _ in range(2):
        res = client.post(f"/api/wishlist/{p.id}", headers=h)
        assert res.status_code == 200
    data = client.get("/api/wishlist", headers=h).get_json()["data"]
    assert data["ids"] == [p.id]
    assert data["items"][0]["name"] == p.name

    assert client.delete(f"/api/wishlist/{p.id}", headers=h).status_code == 200
    assert client.get("/api/wishlist", headers=h).get_json()["data"]["ids"] == []


def test_wishlist_add_at_the_same_moment_is_not_an_error(client, user, monkeypatch):
    """Two taps arrive together: both see "not saved yet", the second insert hits the
    unique key and is treated as already saved instead of a 500."""
    from sqlalchemy.orm import Query

    p = _product()
    h = _auth(client)
    db.session.add(Favorite(user_id=user.id, product_id=p.id))  # the other request just saved it
    db.session.commit()
    real_first = Query.first
    monkeypatch.setattr(Query, "first", lambda q: None if q.column_descriptions[0]["entity"] is Favorite else real_first(q))
    res = client.post(f"/api/wishlist/{p.id}", headers=h)
    assert res.status_code == 200 and res.get_json()["data"]["in_wishlist"] is True
    monkeypatch.undo()
    assert client.get("/api/wishlist", headers=h).get_json()["data"]["ids"] == [p.id]


def test_wishlist_unknown_product_is_404(client, user):
    assert client.post("/api/wishlist/999", headers=_auth(client)).status_code == 404


def test_add_to_cart_merges_lines_and_totals(client, user):
    a, b = _product(price=20, discount=15), _product(price=10)
    h = _auth(client)
    assert client.post("/api/cart", json={"product_id": a.id}, headers=h).status_code == 201
    client.post("/api/cart", json={"product_id": a.id, "quantity": 2}, headers=h)
    res = client.post("/api/cart", json={"product_id": b.id}, headers=h)
    data = res.get_json()["data"]
    assert data["count"] == 4
    assert data["subtotal"] == 15 * 3 + 10
    assert len(data["items"]) == 2
    assert client.get("/api/cart", headers=h).get_json()["data"]["count"] == 4


def test_add_to_cart_respects_stock(client, user):
    sold_out, low = _product(stock=0), _product(stock=2)
    h = _auth(client)
    res = client.post("/api/cart", json={"product_id": sold_out.id}, headers=h)
    assert res.status_code == 409
    assert res.get_json()["message"] == "This item is sold out"

    assert client.post("/api/cart", json={"product_id": low.id, "quantity": 2}, headers=h).status_code == 201
    res = client.post("/api/cart", json={"product_id": low.id}, headers=h)
    assert res.status_code == 409
    assert "Only 2" in res.get_json()["message"]


def test_add_to_cart_validates_body(client, user):
    h = _auth(client)
    assert client.post("/api/cart", json={}, headers=h).get_json()["errors"]["product_id"]
    p = _product()
    assert client.post("/api/cart", json={"product_id": p.id, "quantity": 0}, headers=h).status_code == 422
    inactive = _product(active=False)
    assert client.post("/api/cart", json={"product_id": inactive.id}, headers=h).status_code == 404


# ---------- quantity, remove, clear, delivery, promo codes ----------

def _coupons():
    from app.seed import seed_coupons
    seed_coupons()


def test_update_quantity_respects_stock_and_owner(client, user):
    p = _product(stock=3, price=10)
    h = _auth(client)
    item_id = client.post("/api/cart", json={"product_id": p.id}, headers=h).get_json()["data"]["items"][0]["id"]

    data = client.put(f"/api/cart/{item_id}", json={"quantity": 3}, headers=h).get_json()["data"]
    assert data["count"] == 3
    res = client.put(f"/api/cart/{item_id}", json={"quantity": 4}, headers=h)
    assert res.status_code == 409 and "Only 3" in res.get_json()["message"]
    assert client.put(f"/api/cart/{item_id}", json={"quantity": 0}, headers=h).status_code == 422
    assert client.put("/api/cart/9999", json={"quantity": 1}, headers=h).status_code == 404


def test_remove_and_clear(client, user):
    a, b = _product(price=10), _product(price=20)
    h = _auth(client)
    client.post("/api/cart", json={"product_id": a.id}, headers=h)
    items = client.post("/api/cart", json={"product_id": b.id}, headers=h).get_json()["data"]["items"]

    data = client.delete(f"/api/cart/{items[0]['id']}", headers=h).get_json()["data"]
    assert len(data["items"]) == 1
    assert client.delete("/api/cart", headers=h).get_json()["data"]["count"] == 0


def test_delivery_is_free_from_50(client, user):
    small, big = _product(price=20), _product(price=60)
    h = _auth(client)
    data = client.post("/api/cart", json={"product_id": small.id}, headers=h).get_json()["data"]
    assert (data["subtotal"], data["shipping_fee"], data["total"]) == (20, 2, 22)
    data = client.post("/api/cart", json={"product_id": big.id}, headers=h).get_json()["data"]
    assert (data["shipping_fee"], data["total"], data["free_shipping_min"]) == (0, 80, 50)


def test_percent_coupon_with_cap_and_sale_savings(client, user):
    _coupons()
    p = _product(price=300, discount=250, stock=5)
    h = _auth(client)
    client.post("/api/cart", json={"product_id": p.id}, headers=h)

    data = client.post("/api/cart/coupon", json={"code": "welcome10"}, headers=h).get_json()["data"]
    assert data["coupon"]["code"] == "WELCOME10"
    assert data["discount"] == 20  # 10% of 250 = 25, capped at 20
    assert data["total"] == 230
    assert data["savings"] == 70  # 50 sale + 20 promo
    # The app passes the applied code when it reloads the cart
    assert client.get("/api/cart?coupon=WELCOME10", headers=h).get_json()["data"]["discount"] == 20


def test_coupon_errors(client, user):
    _coupons()
    p = _product(price=10)
    h = _auth(client)
    client.post("/api/cart", json={"product_id": p.id}, headers=h)

    for code, message in [("NOPE", "does not exist"), ("OLDCODE", "expired"), ("ANIME5", "Spend $30")]:
        res = client.post("/api/cart/coupon", json={"code": code}, headers=h)
        assert res.status_code == 422 and message in res.get_json()["message"], code
    # A code that stops applying (cart got smaller) comes back as coupon_error, not a failure
    data = client.get("/api/cart?coupon=ANIME5", headers=h).get_json()["data"]
    assert data["discount"] == 0 and "Spend $30" in data["coupon_error"]


def test_wishlist_batch_remove_and_add_back_keeps_order(client, user):
    a, b, c = _product(), _product(), _product()
    h = _auth(client)
    for p in (a, b, c):
        client.post(f"/api/wishlist/{p.id}", headers=h)
    res = client.post("/api/wishlist/batch-remove", json={"product_ids": [c.id, a.id]}, headers=h)
    assert res.status_code == 200
    assert res.get_json()["data"]["ids"] == [b.id]

    res = client.post("/api/wishlist/batch-add", json={"product_ids": [c.id, a.id, 999]}, headers=h)
    assert res.get_json()["data"]["ids"] == [c.id, a.id, b.id]


def test_wishlist_batch_needs_ids(client, user):
    h = _auth(client)
    for body in ({}, {"product_ids": []}, {"product_ids": ["1"]}):
        assert client.post("/api/wishlist/batch-remove", json=body, headers=h).status_code == 422
        assert client.post("/api/wishlist/move-to-cart", json=body, headers=h).status_code == 422


def test_move_to_cart_skips_sold_out_and_full_lines(client, user):
    ok, sold_out, full = _product(stock=5), _product(stock=0), _product(stock=1)
    h = _auth(client)
    for p in (ok, sold_out, full):
        client.post(f"/api/wishlist/{p.id}", headers=h)
    client.post("/api/cart", json={"product_id": full.id}, headers=h)  # already 1 of 1 in the cart

    data = client.post("/api/wishlist/move-to-cart", json={"product_ids": [ok.id, sold_out.id, full.id]}, headers=h).get_json()["data"]
    assert data["moved"] == [ok.id]
    assert data["skipped"] == [sold_out.id, full.id]
    assert set(data["ids"]) == {sold_out.id, full.id}
    assert data["cart_count"] == 2
    lines = client.get("/api/cart", headers=h).get_json()["data"]["items"]
    assert {line["product"]["id"]: line["quantity"] for line in lines} == {ok.id: 1, full.id: 1}
