import base64
import hashlib
import hmac
import json

from test_orders import _address, _auth, _product

from app import payway
from app.extensions import db
from app.models import Order, Payment
from app.payway import PURCHASE_FIELDS, PaywayError
from app.payway import purchase as real_purchase  # the `bank` fixture swaps payway.purchase for a fake
from app.payway import is_paid as real_is_paid


def _aba_order(client, h, stock=5):
    p = _product(stock=stock, price=30)
    client.post("/api/cart", json={"product_id": p.id, "quantity": 2}, headers=h)
    address = _address(client, h)
    order = client.post("/api/orders", json={"address_id": address["id"], "delivery_method": "standard",
                                             "payment_method": "aba"}, headers=h).get_json()["data"]
    return p, order


def test_aba_payway_is_made_once_and_confirms_when_payway_says_paid(client, user, bank):
    h = _auth(client)
    _, order = _aba_order(client, h)
    assert order["payment_method"] == "aba"
    first = client.post(f"/api/orders/{order['id']}/payway", headers=h).get_json()["data"]["payment"]
    again = client.post(f"/api/orders/{order['id']}/payway", headers=h).get_json()["data"]["payment"]
    assert first == again
    assert first["provider"] == "payway" and first["amount"] == 60 and first["status"] == "pending"
    assert first["deeplink"].startswith("abamobilebank://")
    payment = Payment.query.one()
    assert payment.provider == "payway" and len(payment.tran_id) <= 20
    assert payment.md5 == hashlib.md5(payment.qr.encode()).hexdigest()

    # The KHQR route is only for Bakong orders
    assert client.post(f"/api/orders/{order['id']}/khqr", headers=h).status_code == 409

    bank.add(payment.md5)
    data = client.get(f"/api/orders/{order['id']}/payment", headers=h).get_json()["data"]
    assert data["payment"]["status"] == "paid" and data["order"]["status"] == "confirmed"
    messages = client.get("/api/notifications", headers=h).get_json()["data"]["items"]
    assert "by ABA PayWay" in messages[0]["message"]
    assert "ABA PayWay" in messages[1]["message"]  # placed


def test_payway_route_refuses_other_orders(client, user):
    h = _auth(client)
    p = _product()
    client.post("/api/cart", json={"product_id": p.id}, headers=h)
    cod = client.post("/api/orders", json={"delivery_method": "pickup", "payment_method": "cod"}, headers=h).get_json()["data"]
    assert client.post(f"/api/orders/{cod['id']}/payway", headers=h).status_code == 409
    assert client.post("/api/orders/999/payway", headers=h).status_code == 404


def test_payway_down_is_a_502_and_keeps_the_order(client, user, monkeypatch):
    def refuse(order, tran_id, callback):
        raise PaywayError("Wrong Hash.")

    monkeypatch.setattr(payway, "purchase", refuse)
    h = _auth(client)
    _, order = _aba_order(client, h)
    res = client.post(f"/api/orders/{order['id']}/payway", headers=h)
    assert res.status_code == 502 and "ABA PayWay" in res.get_json()["message"]
    assert Payment.query.count() == 0 and db.session.get(Order, order["id"]).status == "pending"


def test_callback_only_trusts_payway_itself(client, user, bank):
    h = _auth(client)
    _, order = _aba_order(client, h)
    client.post(f"/api/orders/{order['id']}/payway", headers=h)
    payment = Payment.query.one()

    # A forged "paid" pushback changes nothing while PayWay says it is not paid
    res = client.post("/api/payments/payway/callback", data={"tran_id": payment.tran_id, "status": "0"})
    assert res.status_code == 200 and res.get_data(as_text=True) == "OK"
    assert db.session.get(Payment, payment.id).status == "pending"

    bank.add(payment.md5)
    client.post("/api/payments/payway/callback", data={"tran_id": payment.tran_id, "status": "0"})
    assert db.session.get(Payment, payment.id).status == "paid"
    assert client.post("/api/payments/payway/callback", data={"tran_id": "nope"}).get_data(as_text=True) == "OK"


class _Res:
    def __init__(self, body):
        self.body = body

    def json(self):
        return self.body


def test_purchase_request_is_signed_in_payway_order(app, client, user, monkeypatch):
    h = _auth(client)
    _, placed = _aba_order(client, h)
    order = db.session.get(Order, placed["id"])
    sent = {}

    def post(url, timeout, data=None, json=None):
        sent.update(url=url, data=data)
        return _Res({"status": {"code": "00"}, "qrString": "000201KHQR", "abapay_deeplink": "abamobilebank://x"})

    monkeypatch.setattr(payway.requests, "post", post)
    made = real_purchase(order, "AWS2026101900001ab12", "https://shop.example/api/payments/payway/callback")
    assert made == {"qr": "000201KHQR", "deeplink": "abamobilebank://x"}

    f = sent["data"]
    assert sent["url"].endswith("/api/payment-gateway/v1/payments/purchase")
    assert f["merchant_id"] == "ec000000" and f["amount"] == "60.00" and f["shipping"] == "0" and f["lifetime"] == "15"
    assert f["payment_option"] == "abapay_khqr_deeplink" and f["currency"] == "USD"
    assert base64.b64decode(f["return_url"]).decode() == "https://shop.example/api/payments/payway/callback"
    assert json_loads_b64(f["items"]) == [{"name": order.items[0].product_name, "quantity": 2, "price": 30.0}]
    expected = base64.b64encode(hmac.new(b"test-key", "".join(f[k] for k in PURCHASE_FIELDS).encode(), hashlib.sha512).digest()).decode()
    assert f["hash"] == expected


def json_loads_b64(text):
    return json.loads(base64.b64decode(text))


def test_purchase_refused_and_status_answers(app, monkeypatch):
    monkeypatch.setattr(payway.requests, "post", lambda url, timeout, **kw: _Res({"status": {"code": 1, "message": "Wrong Hash."}}))
    try:
        real_purchase(type("O", (), {"user": type("U", (), {"full_name": "A B", "email": "a@b.c", "phone": None})(),
                                     "items": [], "total": 1})(), "T1", "https://x")
        raise AssertionError("expected PaywayError")
    except PaywayError as exc:
        assert "Wrong Hash." in str(exc)

    approved = {"status": {"code": "00"}, "data": {"payment_status": "APPROVED"}}
    pending = {"status": {"code": "00"}, "data": {"payment_status": "PENDING"}}
    monkeypatch.setattr(payway.requests, "post", lambda url, timeout, **kw: _Res(approved))
    assert real_is_paid("T1") is True
    monkeypatch.setattr(payway.requests, "post", lambda url, timeout, **kw: _Res(pending))
    assert real_is_paid("T1") is False
