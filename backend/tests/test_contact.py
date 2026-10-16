from conftest import login_token

from app.extensions import bcrypt, db
from app.models import ContactMessage, Order, User


def _auth(client, email="demo@shop.com", password="demo123"):
    return {"Authorization": f"Bearer {login_token(client, email, password)}"}


def _order(user_id, number="AWS-0001"):
    o = Order(user_id=user_id, order_number=number, shipping_name="Demo", shipping_phone="012345678", shipping_address="Shop pickup", subtotal=30, total=30)
    db.session.add(o)
    db.session.commit()
    return o


def test_send_a_message_about_an_order(client, user):
    order = _order(user.id)
    res = client.post("/api/contact", json={"topic": "order", "order_id": order.id, "message": "  When will it arrive?  "}, headers=_auth(client))
    assert res.status_code == 201
    data = res.get_json()["data"]
    assert data["topic"] == "order" and data["status"] == "open"
    assert data["message"] == "When will it arrive?"
    assert data["order"] == {"id": order.id, "number": "AWS-0001"}
    assert [m["id"] for m in client.get("/api/contact", headers=_auth(client)).get_json()["data"]] == [data["id"]]


def test_the_order_is_dropped_for_other_topics(client, user):
    order = _order(user.id)
    res = client.post("/api/contact", json={"topic": "product", "order_id": order.id, "message": "Restock Gojo?"}, headers=_auth(client))
    assert res.status_code == 201 and res.get_json()["data"]["order"] is None


def test_bad_messages_are_refused(client, user):
    h = _auth(client)
    res = client.post("/api/contact", json={"topic": "gossip", "message": " "}, headers=h)
    assert res.status_code == 422
    assert set(res.get_json()["errors"]) == {"topic", "message"}
    assert client.post("/api/contact", json={"message": "x" * 1001}, headers=h).status_code == 422
    assert client.post("/api/contact", json={"message": "hi"}).status_code == 401


def test_someone_elses_order_is_not_found(client, user):
    other = User(full_name="Other", email="other@shop.com", password_hash=bcrypt.generate_password_hash("secret123").decode())
    db.session.add(other)
    db.session.commit()
    order = _order(other.id)
    res = client.post("/api/contact", json={"topic": "payment", "order_id": order.id, "message": "Paid?"}, headers=_auth(client))
    assert res.status_code == 404
    assert ContactMessage.query.count() == 0


def test_reply_command_answers_and_notifies(app, client, user):
    h = _auth(client)
    client.post("/api/contact", json={"topic": "other", "message": "Do you sell posters?"}, headers=h)
    result = app.test_cli_runner().invoke(args=["reply-contact", "Not yet, maybe next month!"])
    assert "Answered message" in result.output

    msg = ContactMessage.query.one()
    assert msg.status == "answered" and msg.reply == "Not yet, maybe next month!" and msg.replied_at is not None
    note = client.get("/api/notifications", headers=h).get_json()["data"]["items"][0]
    assert note["event"] == "support" and note["message"] == "Not yet, maybe next month!"
    assert "No open message" in app.test_cli_runner().invoke(args=["reply-contact", "again"]).output
