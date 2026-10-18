"""Admin endpoints added for the web admin (coupons, reviews, review events) and /dashboard."""
import pytest
from conftest import login_token

from app.extensions import bcrypt, db
from app.models import Category, Coupon, Product, Review, User


@pytest.fixture()
def admin_h(app, client):
    db.session.add(User(full_name="Admin", email="admin@shop.com", role="admin", password_hash=bcrypt.generate_password_hash("demo123").decode()))
    db.session.commit()
    return {"Authorization": f"Bearer {login_token(client, 'admin@shop.com')}"}


def test_coupons_crud_and_rules(client, admin_h, user):
    res = client.post("/api/admin/coupons", json={"code": "anime5", "description": "$5 off", "discount_type": "fixed", "value": 5}, headers=admin_h)
    assert res.status_code == 201
    c = res.get_json()["data"]
    assert c["code"] == "ANIME5" and c["is_active"] is True and c["min_subtotal"] == 0 and c["used"] == 0

    bad = client.post("/api/admin/coupons", json={"code": "ANIME5", "description": "x", "discount_type": "percent", "value": 150}, headers=admin_h)
    assert bad.status_code == 422 and set(bad.get_json()["errors"]) == {"code", "value"}
    assert client.post("/api/admin/coupons", json={"code": "NO WAY!", "description": "x", "discount_type": "fixed", "value": 1}, headers=admin_h).status_code == 422

    res = client.put(f"/api/admin/coupons/{c['id']}", json={"is_active": False, "expires_at": "2026-12-31", "min_subtotal": 30}, headers=admin_h)
    data = res.get_json()["data"]
    assert data["is_active"] is False and data["expires_at"].startswith("2026-12-31") and data["min_subtotal"] == 30
    assert client.put(f"/api/admin/coupons/{c['id']}", json={"expires_at": "soon"}, headers=admin_h).status_code == 422

    assert [x["code"] for x in client.get("/api/admin/coupons", headers=admin_h).get_json()["data"]] == ["ANIME5"]
    assert client.delete(f"/api/admin/coupons/{c['id']}", headers=admin_h).status_code == 200
    assert Coupon.query.count() == 0
    # customers can't manage coupons
    assert client.get("/api/admin/coupons", headers={"Authorization": f"Bearer {login_token(client)}"}).status_code == 403


def test_reviews_list_filter_delete_and_activity(client, admin_h, user):
    cat = Category(name="Figures", slug="figures")
    luffy, gojo = Product(category=cat, name="Luffy", slug="luffy", price=87, stock=3), Product(category=cat, name="Gojo", slug="gojo", price=149, stock=0)
    db.session.add_all([luffy, gojo])
    db.session.flush()
    db.session.add_all([Review(product_id=luffy.id, user_id=user.id, rating=5, comment="Great"), Review(product_id=gojo.id, user_id=user.id, rating=2)])
    db.session.commit()

    page = client.get("/api/admin/reviews", headers=admin_h).get_json()["data"]
    assert page["total"] == 2 and page["items"][0]["customer"]["full_name"] == "Demo Customer"
    assert [r["product"]["name"] for r in client.get("/api/admin/reviews?rating=2", headers=admin_h).get_json()["data"]["items"]] == ["Gojo"]
    assert client.get("/api/admin/reviews?q=luff", headers=admin_h).get_json()["data"]["total"] == 1

    kinds = {e["kind"] for e in client.get("/api/admin/activity", headers=admin_h).get_json()["data"]}
    assert {"review", "sold_out"} <= kinds

    rid = page["items"][0]["id"]
    assert client.delete(f"/api/admin/reviews/{rid}", headers=admin_h).status_code == 200
    assert client.delete(f"/api/admin/reviews/{rid}", headers=admin_h).status_code == 404
    assert Review.query.count() == 1


def test_dashboard_serves_the_built_web_admin(app, client, tmp_path):
    app.config["WEB_ADMIN_DIR"] = str(tmp_path / "web-admin")
    assert client.get("/dashboard").status_code == 404  # not built yet
    (tmp_path / "web-admin" / "assets").mkdir(parents=True)
    (tmp_path / "web-admin" / "index.html").write_text("<div id=root></div>")
    (tmp_path / "web-admin" / "assets" / "app.js").write_text("console.log(1)")
    assert client.get("/dashboard").data == b"<div id=root></div>"
    assert client.get("/dashboard/orders/12").data == b"<div id=root></div>"  # the app's own pages
    assert client.get("/dashboard/assets/app.js").data == b"console.log(1)"
