from conftest import login_token

from app.extensions import bcrypt, db
from app.models import Category, Order, OrderItem, Product, Review, User


def _auth(client, email="demo@shop.com"):
    return {"Authorization": f"Bearer {login_token(client, email)}"}


def _product(name="Luffy Gear 5"):
    cat = Category.query.first() or Category(name="Scale Figures", slug="scale-figures")
    p = Product(category=cat, name=name, slug=name.lower().replace(" ", "-"), price=87, stock=5)
    db.session.add(p)
    db.session.commit()
    return p


def _order(user, product, status="delivered"):
    n = Order.query.count() + 1
    o = Order(order_number=f"AWS-20261016-{n:04d}", user_id=user.id, status=status, payment_method="cod",
              subtotal=87, shipping_fee=0, total=87, shipping_name="Demo", shipping_phone="012345678", shipping_address="Phnom Penh")
    o.items.append(OrderItem(product_id=product.id, product_name=product.name, unit_price=87, quantity=1, subtotal=87))
    db.session.add(o)
    db.session.commit()
    return o


def _other_user(email="dara@shop.com", name="Sok Dara"):
    u = User(full_name=name, email=email, password_hash=bcrypt.generate_password_hash("demo123").decode())
    db.session.add(u)
    db.session.commit()
    return u


def test_only_delivered_products_can_be_reviewed(client, user):
    p = _product()
    _order(user, p, status="shipped")
    res = client.post(f"/api/products/{p.id}/reviews", json={"rating": 5}, headers=_auth(client))
    assert res.status_code == 403
    assert "delivered" in res.get_json()["message"]


def test_review_validation(client, user):
    p = _product()
    _order(user, p)
    h = _auth(client)
    res = client.post(f"/api/products/{p.id}/reviews", json={"rating": 6, "tags": ["shiny"], "comment": "x" * 1001}, headers=h)
    assert res.status_code == 422
    assert set(res.get_json()["errors"]) == {"rating", "tags", "comment"}
    assert client.post(f"/api/products/{p.id}/reviews", json={"rating": True}, headers=h).status_code == 422
    assert client.post("/api/products/999/reviews", json={"rating": 5}, headers=h).status_code == 404


def test_post_then_edit_a_review(client, user):
    p = _product()
    _order(user, p)
    h = _auth(client)
    res = client.post(f"/api/products/{p.id}/reviews",
                      json={"rating": 4, "comment": "  Great paint  ", "tags": ["packaging", "quality", "quality"]}, headers=h)
    assert res.status_code == 201
    data = res.get_json()["data"]
    assert data["review"]["comment"] == "Great paint"
    assert data["review"]["tags"] == ["quality", "packaging"]  # known order, no repeats
    assert data["review"]["is_mine"] is True and data["review"]["edited"] is False
    assert data["summary"]["rating"] == 4 and data["summary"]["count"] == 1

    res = client.post(f"/api/products/{p.id}/reviews", json={"rating": 5}, headers=h)
    assert res.status_code == 200 and res.get_json()["message"] == "Review updated"
    review = res.get_json()["data"]["review"]
    assert review["rating"] == 5 and review["comment"] is None and review["edited"] is True
    assert Review.query.count() == 1  # still one review per customer and product


def test_list_reviews_summary_filters_and_mine_first(client, user):
    p = _product()
    dara = _other_user()
    db.session.add_all([
        Review(product_id=p.id, user_id=dara.id, rating=5, comment="Perfect", tags=["quality", "packaging"]),
        Review(product_id=p.id, user_id=user.id, rating=3, comment=None, tags=["quality"]),
    ])
    db.session.commit()

    data = client.get(f"/api/products/{p.id}/reviews").get_json()["data"]
    assert data["summary"] == {"rating": 4.0, "count": 2, "stars": {"5": 1, "4": 0, "3": 1, "2": 0, "1": 0},
                               "with_comment": 1, "tags": {"quality": 2, "as_pictured": 0, "packaging": 1, "delivery": 0, "value": 0}}
    assert all(r["is_mine"] is False for r in data["items"])  # a visitor

    mine = client.get(f"/api/products/{p.id}/reviews", headers=_auth(client)).get_json()["data"]["items"]
    assert mine[0]["user"] == "Demo Customer" and mine[0]["is_mine"] is True

    five = client.get(f"/api/products/{p.id}/reviews?rating=5").get_json()["data"]
    assert [r["user"] for r in five["items"]] == ["Sok Dara"] and five["total"] == 1
    written = client.get(f"/api/products/{p.id}/reviews?with_comment=1").get_json()["data"]
    assert [r["comment"] for r in written["items"]] == ["Perfect"]
    assert client.get(f"/api/products/{p.id}/reviews?rating=0").status_code == 422


def test_product_details_know_my_review(client, user):
    p = _product()
    h = _auth(client)
    assert client.get(f"/api/products/{p.id}", headers=h).get_json()["data"]["can_review"] is False
    _order(user, p)
    detail = client.get(f"/api/products/{p.id}", headers=h).get_json()["data"]
    assert detail["can_review"] is True and detail["my_review"] is None
    client.post(f"/api/products/{p.id}/reviews", json={"rating": 5, "tags": ["value"]}, headers=h)
    detail = client.get(f"/api/products/{p.id}", headers=h).get_json()["data"]
    assert detail["my_review"]["rating"] == 5
    assert detail["rating"] == 5 and detail["review_count"] == 1
    assert detail["review_summary"]["tags"]["value"] == 1
    visitor = client.get(f"/api/products/{p.id}").get_json()["data"]
    assert visitor["can_review"] is False and visitor["my_review"] is None


def test_orders_show_my_rating_and_to_review_list(client, user):
    luffy, pochita = _product("Luffy Gear 5"), _product("Pochita Plush")
    order = _order(user, luffy)
    order.items.append(OrderItem(product_id=pochita.id, product_name=pochita.name, unit_price=13, quantity=1, subtotal=13))
    db.session.commit()
    h = _auth(client)

    todo = client.get("/api/reviews/to-review", headers=h).get_json()["data"]
    assert {t["product"]["name"] for t in todo} == {"Luffy Gear 5", "Pochita Plush"}
    assert todo[0]["order_number"] == order.order_number

    client.post(f"/api/products/{luffy.id}/reviews", json={"rating": 4}, headers=h)
    items = client.get(f"/api/orders/{order.id}", headers=h).get_json()["data"]["items"]
    assert {i["product_name"]: i["my_rating"] for i in items} == {"Luffy Gear 5": 4, "Pochita Plush": None}
    assert [t["product"]["name"] for t in client.get("/api/reviews/to-review", headers=h).get_json()["data"]] == ["Pochita Plush"]
    assert client.get("/api/profile/summary", headers=h).get_json()["data"]["order_status"]["to_review"] == 1


def test_delete_my_review(client, user):
    p = _product()
    _order(user, p)
    h = _auth(client)
    assert client.delete(f"/api/products/{p.id}/reviews/mine", headers=h).status_code == 404
    client.post(f"/api/products/{p.id}/reviews", json={"rating": 2}, headers=h)
    res = client.delete(f"/api/products/{p.id}/reviews/mine", headers=h)
    assert res.status_code == 200 and res.get_json()["data"]["summary"]["count"] == 0
