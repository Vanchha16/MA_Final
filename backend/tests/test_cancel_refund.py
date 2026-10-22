"""Customers cancel orders that have not shipped; paid online orders then wait for a refund
that the shop marks as sent."""
from conftest import login_token
from test_orders import _address, _auth, _khqr_order, _product

from app.extensions import bcrypt, db
from app.models import Notification, Order, Payment, Product, User


def _staff_h(client):
    db.session.add(User(full_name="Shop Staff", email="staff@shop.com", role="staff", password_hash=bcrypt.generate_password_hash("demo123").decode()))
    db.session.commit()
    return {"Authorization": f"Bearer {login_token(client, 'staff@shop.com')}"}


def _cash_order(client, h, stock=5):
    p = _product(stock=stock, price=25)
    client.post("/api/cart", json={"product_id": p.id, "quantity": 2}, headers=h)
    address = _address(client, h)
    order = client.post("/api/orders", json={"address_id": address["id"], "delivery_method": "standard", "payment_method": "cod"},
                        headers=h).get_json()["data"]
    return p, order


def _paid_khqr_order(client, h, bank):
    p, order = _khqr_order(client, h)
    client.post(f"/api/orders/{order['id']}/khqr", headers=h)
    bank.add(Payment.query.filter_by(order_id=order["id"]).one().md5)
    order = client.get(f"/api/orders/{order['id']}/payment", headers=h).get_json()["data"]["order"]
    assert order["status"] == "confirmed" and order["payment_status"] == "paid"
    return p, order


def test_customer_cancels_a_cash_order_and_the_stock_comes_back(client, user):
    h = _auth(client)
    p, order = _cash_order(client, h)
    assert order["can_cancel"] is True and db.session.get(Product, p.id).stock == 3

    res = client.post(f"/api/orders/{order['id']}/cancel", json={"reason": "Changed my mind"}, headers=h)
    assert res.status_code == 200 and res.get_json()["message"] == "Order cancelled"
    data = res.get_json()["data"]
    assert data["status"] == "cancelled" and data["cancelled_by"] == "customer" and data["cancel_reason"] == "Changed my mind"
    assert data["payment_status"] == "unpaid" and data["can_cancel"] is False and data["cancelled_at"]
    assert db.session.get(Product, p.id).stock == 5
    note = Notification.query.filter_by(order_id=order["id"]).order_by(Notification.id.desc()).first()
    assert note.event == "cancelled" and note.message == f"You cancelled order {order['order_number']}."

    again = client.post(f"/api/orders/{order['id']}/cancel", headers=h)
    assert again.status_code == 409 and again.get_json()["message"] == "This order is already cancelled"


def test_paid_online_order_cancel_leaves_a_refund_for_the_shop(client, user, bank):
    h = _auth(client)
    _, order = _paid_khqr_order(client, h, bank)

    res = client.post(f"/api/orders/{order['id']}/cancel", json={}, headers=h)
    data = res.get_json()["data"]
    assert data["payment_status"] == "refund_pending" and data["cancel_reason"] is None
    assert "refund you within 3 working days" in res.get_json()["message"]
    note = Notification.query.filter_by(order_id=order["id"]).order_by(Notification.id.desc()).first()
    assert "We will send $60 back to you within 3 working days." in note.message

    staff = _staff_h(client)
    stats = client.get("/api/admin/stats", headers=staff).get_json()["data"]
    assert stats["refunds_to_send"] == 1 and stats["revenue"] == 0  # refunded money is not revenue
    waiting = client.get("/api/admin/orders?refund=1", headers=staff).get_json()["data"]["items"]
    assert [o["id"] for o in waiting] == [order["id"]]
    event = next(e for e in client.get("/api/admin/activity", headers=staff).get_json()["data"] if e["kind"] == "cancelled")
    assert event["action"] == "refund" and "Demo Customer cancelled it" in event["message"]

    done = client.post(f"/api/admin/orders/{order['id']}/refund", headers=staff)
    assert done.status_code == 200 and done.get_json()["data"]["payment_status"] == "refunded" and done.get_json()["data"]["refunded_at"]
    assert Notification.query.filter_by(order_id=order["id"], event="refunded").count() == 1
    assert client.post(f"/api/admin/orders/{order['id']}/refund", headers=staff).status_code == 409
    assert client.get("/api/admin/stats", headers=staff).get_json()["data"]["refunds_to_send"] == 0
    event = next(e for e in client.get("/api/admin/activity", headers=staff).get_json()["data"] if e["kind"] == "cancelled")
    assert event["action"] is None


def test_shop_cancel_with_reason_and_refund(client, user, bank):
    h = _auth(client)
    _, order = _paid_khqr_order(client, h, bank)
    staff = _staff_h(client)
    res = client.put(f"/api/admin/orders/{order['id']}/status", json={"status": "cancelled", "reason": "Sold out at the supplier"}, headers=staff)
    data = res.get_json()["data"]
    assert data["cancelled_by"] == "shop" and data["payment_status"] == "refund_pending"
    note = Notification.query.filter_by(order_id=order["id"]).order_by(Notification.id.desc()).first()
    assert note.title == "Order cancelled by the shop" and "Reason: Sold out at the supplier." in note.message


def test_cannot_cancel_once_shipped_or_someone_elses(client, user):
    h = _auth(client)
    _, order = _cash_order(client, h)
    o = db.session.get(Order, order["id"])
    o.status = "shipped"
    db.session.commit()
    res = client.post(f"/api/orders/{order['id']}/cancel", headers=h)
    assert res.status_code == 409 and "on its way" in res.get_json()["message"]
    assert client.get(f"/api/orders/{order['id']}", headers=h).get_json()["data"]["can_cancel"] is False

    db.session.add(User(full_name="Other", email="other@shop.com", password_hash=bcrypt.generate_password_hash("demo123").decode()))
    db.session.commit()
    other = {"Authorization": f"Bearer {login_token(client, 'other@shop.com')}"}
    assert client.post(f"/api/orders/{order['id']}/cancel", headers=other).status_code == 404
    assert client.post(f"/api/orders/{order['id']}/cancel", json={"reason": 5}, headers=h).status_code in (409, 422)


def test_not_paid_in_time_is_still_a_system_cancel_without_refund(client, user):
    h = _auth(client)
    _, order = _khqr_order(client, h)
    from app import payments
    from app.models import Payment as P

    client.post(f"/api/orders/{order['id']}/khqr", headers=h)
    o = db.session.get(Order, order["id"])
    payments.expire(o, P.query.filter_by(order_id=o.id).one())
    assert o.status == "cancelled" and o.cancelled_by == "system" and o.payment_status == "unpaid"
    note = Notification.query.filter_by(order_id=o.id).order_by(Notification.id.desc()).first()
    assert "was not paid in time" in note.message
