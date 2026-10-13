from datetime import timedelta

from conftest import login_token

from app.extensions import db
from app.utils.clock import utcnow
from app.models import PasswordReset


def request_code(client, email="demo@shop.com"):
    return client.post("/api/auth/forgot-password", json={"email": email})


def verify(client, code, email="demo@shop.com"):
    return client.post("/api/auth/verify-otp", json={"email": email, "code": code})


def test_full_reset_flow(client, user):
    res = request_code(client)
    data = res.get_json()["data"]
    assert res.status_code == 200
    code = data["dev_code"]
    assert len(code) == 6 and code.isdigit()
    assert data["expires_in"] == 600

    res = verify(client, code)
    assert res.status_code == 200
    reset_token = res.get_json()["data"]["reset_token"]

    res = client.post("/api/auth/reset-password", json={"reset_token": reset_token, "new_password": "newpass1"})
    assert res.status_code == 200

    assert login_token(client, password="demo123") is None
    assert login_token(client, password="newpass1")

    # The reset token is single-use
    again = client.post("/api/auth/reset-password", json={"reset_token": reset_token, "new_password": "other12"})
    assert again.status_code == 400


def test_unknown_email_gets_same_answer(client, user):
    known = request_code(client).get_json()
    unknown = request_code(client, "nobody@shop.com").get_json()
    assert known["message"] == unknown["message"]
    assert "dev_code" not in unknown["data"]


def test_code_is_stored_hashed(client, user):
    code = request_code(client).get_json()["data"]["dev_code"]
    row = PasswordReset.query.one()
    assert row.code_hash != code
    assert code not in row.code_hash


def test_wrong_code_and_lockout(client, user):
    request_code(client)
    for _ in range(4):
        res = verify(client, "000000")
        assert res.status_code == 400
        assert res.get_json()["errors"]["code"]
    assert verify(client, "000000").status_code == 429  # 5th wrong attempt locks the code
    assert PasswordReset.query.one().used is True


def test_expired_code(client, user):
    code = request_code(client).get_json()["data"]["dev_code"]
    row = PasswordReset.query.one()
    row.expires_at = utcnow() - timedelta(seconds=1)
    db.session.commit()
    assert verify(client, code).status_code == 400


def test_new_code_replaces_old(client, user):
    old = request_code(client).get_json()["data"]["dev_code"]
    new = request_code(client).get_json()["data"]["dev_code"]
    if old != new:
        assert verify(client, old).status_code == 400
    assert verify(client, new).status_code == 200


def test_resend_cooldown_and_hourly_limit(app, client, user):
    app.config["RESET_RESEND_SECONDS"] = 60
    assert request_code(client).status_code == 200
    res = request_code(client)
    assert res.status_code == 429
    assert res.get_json()["errors"]["retry_after"] > 0

    app.config["RESET_RESEND_SECONDS"] = 0
    for _ in range(4):
        assert request_code(client).status_code == 200
    assert request_code(client).status_code == 429  # 6th request within an hour


def test_reset_token_cannot_be_used_to_log_in(client, user):
    code = request_code(client).get_json()["data"]["dev_code"]
    reset_token = verify(client, code).get_json()["data"]["reset_token"]
    me = client.get("/api/auth/me", headers={"Authorization": f"Bearer {reset_token}"})
    assert me.status_code == 401


def test_login_token_cannot_reset_password(client, user):
    token = login_token(client)
    res = client.post("/api/auth/reset-password", json={"reset_token": token, "new_password": "hacked1"})
    assert res.status_code == 400


def test_reset_validation(client):
    assert request_code(client, "not-an-email").status_code == 422
    res = client.post("/api/auth/reset-password", json={"reset_token": "x", "new_password": "123"})
    assert res.status_code == 422
    assert "new_password" in res.get_json()["errors"]
