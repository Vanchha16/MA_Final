import io

import pytest
from conftest import login_token

from app.extensions import db
from app.models import Category, Favorite, Order, OrderItem, Product, Review

PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64


@pytest.fixture()
def auth(client, user):
    return {"Authorization": f"Bearer {login_token(client)}"}


def make_order(user, number, status, total, method="cod", paid="unpaid", product=None):
    o = Order(order_number=number, user_id=user.id, shipping_name="D", shipping_phone="012345678",
              shipping_address="Phnom Penh", subtotal=total, total=total, status=status,
              payment_method=method, payment_status=paid)
    db.session.add(o)
    db.session.flush()
    if product:
        db.session.add(OrderItem(order_id=o.id, product_id=product.id, product_name=product.name,
                                 unit_price=total, quantity=1, subtotal=total))
    return o


def test_summary_counts_points_and_tier(client, user, auth):
    cat = Category(name="Figures", slug="figures")
    p1 = Product(name="Luffy", slug="luffy", category=cat, price=100, stock=5)
    p2 = Product(name="Zoro", slug="zoro", category=cat, price=50, stock=5)
    db.session.add_all([cat, p1, p2])
    db.session.flush()
    make_order(user, "A-1", "pending", 20, method="khqr")              # to pay
    make_order(user, "A-2", "pending", 30, method="cod")               # to ship
    make_order(user, "A-3", "confirmed", 40, method="khqr", paid="paid")  # to ship
    make_order(user, "A-4", "shipped", 50)                             # to receive
    make_order(user, "A-5", "delivered", 400, product=p1)
    make_order(user, "A-6", "delivered", 300, product=p2)
    make_order(user, "A-7", "cancelled", 999)
    db.session.add(Review(product_id=p1.id, user_id=user.id, rating=5))
    db.session.add(Favorite(user_id=user.id, product_id=p1.id))
    db.session.commit()

    data = client.get("/api/profile/summary", headers=auth).get_json()["data"]
    assert data["stats"] == {"orders": 6, "wishlist": 1, "reviews": 1}
    assert data["order_status"] == {"to_pay": 1, "to_ship": 2, "to_receive": 1, "to_review": 1}
    assert data["points"] == 700  # delivered only
    assert data["tier"]["name"] == "Silver"
    assert data["tier"]["next_name"] == "Gold"
    assert data["tier"]["points_to_next"] == 1300


def test_summary_for_new_user(client, user, auth):
    data = client.get("/api/profile/summary", headers=auth).get_json()["data"]
    assert data["points"] == 0
    assert data["tier"] == {"name": "Bronze", "next_name": "Silver", "points_to_next": 500, "progress": 0.0}
    assert client.get("/api/profile/summary").status_code == 401


def test_update_profile(client, auth):
    res = client.put("/api/profile", json={"full_name": " Dara Sok ", "phone": "096-123-4567"}, headers=auth)
    assert res.status_code == 200
    assert res.get_json()["data"]["full_name"] == "Dara Sok"
    assert res.get_json()["data"]["phone"] == "0961234567"

    bad = client.put("/api/profile", json={"full_name": "D", "phone": "12"}, headers=auth)
    assert bad.status_code == 422
    assert set(bad.get_json()["errors"]) == {"full_name", "phone"}

    # Phone is optional and can be cleared
    cleared = client.put("/api/profile", json={"full_name": "Dara", "phone": ""}, headers=auth)
    assert cleared.get_json()["data"]["phone"] is None


def test_change_password(client, auth):
    wrong = client.put("/api/profile/password", json={"current_password": "nope", "new_password": "newpass1"}, headers=auth)
    assert wrong.status_code == 422
    assert "current_password" in wrong.get_json()["errors"]

    same = client.put("/api/profile/password", json={"current_password": "demo123", "new_password": "demo123"}, headers=auth)
    assert same.status_code == 422

    ok = client.put("/api/profile/password", json={"current_password": "demo123", "new_password": "newpass1"}, headers=auth)
    assert ok.status_code == 200
    assert login_token(client, password="newpass1")
    assert login_token(client, password="demo123") is None


def test_avatar_upload(app, client, auth, tmp_path):
    app.config["UPLOAD_FOLDER"] = str(tmp_path)
    res = client.post("/api/profile/avatar", headers=auth,
                      data={"file": (io.BytesIO(PNG), "me.png")}, content_type="multipart/form-data")
    assert res.status_code == 200
    url = res.get_json()["data"]["avatar_url"]
    assert url.startswith("http://localhost/uploads/avatars/") and url.endswith(".png")
    assert len(list((tmp_path / "avatars").iterdir())) == 1

    # The file is served back
    path = url.removeprefix("http://localhost")
    assert client.get(path).status_code == 200

    # Uploading again replaces (and deletes) the old photo
    client.post("/api/profile/avatar", headers=auth,
                data={"file": (io.BytesIO(PNG), "me2.png")}, content_type="multipart/form-data")
    assert len(list((tmp_path / "avatars").iterdir())) == 1


def test_avatar_rejects_non_images(app, client, auth, tmp_path):
    app.config["UPLOAD_FOLDER"] = str(tmp_path)
    res = client.post("/api/profile/avatar", headers=auth,
                      data={"file": (io.BytesIO(b"<script>alert(1)</script>"), "x.png")}, content_type="multipart/form-data")
    assert res.status_code == 422
    assert client.post("/api/profile/avatar", headers=auth).status_code == 422
