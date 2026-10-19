from conftest import login_token

from app.extensions import db
from app.models import Category, Notification, Order, Product


def _auth(client):
    return {"Authorization": f"Bearer {login_token(client)}"}


def _order(client, h, payment="cod"):
    cat = Category.query.first() or Category(name="Scale Figures", slug="scale-figures")
    p = Product(category=cat, name=f"Figure {Product.query.count() + 1}", slug=f"fig-{Product.query.count() + 1}", price=30, stock=5)
    db.session.add(p)
    db.session.commit()
    client.post("/api/cart", json={"product_id": p.id}, headers=h)
    return client.post("/api/orders", json={"delivery_method": "pickup", "payment_method": payment}, headers=h).get_json()["data"]


def test_register_sends_a_welcome_code(client):
    res = client.post("/api/auth/register", json={"full_name": "New Fan", "email": "fan@shop.com", "password": "secret123"})
    token = res.get_json()["data"]["token"]
    data = client.get("/api/notifications", headers={"Authorization": f"Bearer {token}"}).get_json()["data"]
    assert data["unread"] == 1
    assert data["items"][0]["event"] == "welcome" and data["items"][0]["promo_code"] == "WELCOME10"


def test_order_steps_send_messages_and_read_delete(client, user, bank):
    from app.models import Payment

    h = _auth(client)
    order = _order(client, h, "khqr")
    client.post(f"/api/orders/{order['id']}/khqr", headers=h)
    bank.add(Payment.query.one().md5)
    client.get(f"/api/orders/{order['id']}/payment", headers=h)
    o = db.session.get(Order, order["id"])
    o.status = "shipped"
    db.session.commit()
    client.post(f"/api/orders/{order['id']}/received", headers=h)

    data = client.get("/api/notifications", headers=h).get_json()["data"]
    assert [n["event"] for n in data["items"]] == ["delivered", "paid", "placed"]
    assert data["items"][0]["order"]["number"] == order["order_number"]
    assert "image_url" in data["items"][0]
    assert data["unread"] == 3

    first = data["items"][0]["id"]
    assert client.post(f"/api/notifications/{first}/read", headers=h).get_json()["data"]["unread"] == 2
    assert client.delete(f"/api/notifications/{first}", headers=h).get_json()["data"]["unread"] == 2
    assert client.post("/api/notifications/read-all", headers=h).get_json()["data"]["unread"] == 0
    assert client.get("/api/notifications/unread-count", headers=h).get_json()["data"]["unread"] == 0
    assert client.delete("/api/notifications/9999", headers=h).status_code == 404


def test_advance_orders_command(app, client, user):
    h = _auth(client)
    order = _order(client, h, "cod")
    runner = app.test_cli_runner()
    runner.invoke(args=["advance-orders"])
    assert db.session.get(Order, order["id"]).status == "confirmed"
    runner.invoke(args=["advance-orders"])
    assert db.session.get(Order, order["id"]).status == "shipped"
    events = [n.event for n in Notification.query.order_by(Notification.id)]
    assert events == ["placed", "confirmed", "shipped"]
    assert Notification.query.order_by(Notification.id.desc()).first().title == "Ready to pick up"


def test_preferences_turn_messages_off(client, user):
    h = _auth(client)
    assert client.get("/api/profile/preferences", headers=h).get_json()["data"] == {
        "notify_orders": True, "notify_offers": True, "notify_news": True}
    res = client.put("/api/profile/preferences", json={"notify_orders": False, "notify_news": False}, headers=h)
    assert res.get_json()["data"] == {"notify_orders": False, "notify_offers": True, "notify_news": False}
    assert client.put("/api/profile/preferences", json={"notify_offers": "no"}, headers=h).status_code == 422

    _order(client, h, "cod")  # no "Order placed" message now
    assert Notification.query.count() == 0
