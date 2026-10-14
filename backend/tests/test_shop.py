from conftest import login_token

from app.extensions import db
from app.models import Category, Product


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
