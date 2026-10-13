from conftest import login_token


def test_register_logs_in_and_normalizes(client):
    res = client.post("/api/auth/register", json={
        "full_name": " Dara ", "email": "Dara@Example.com", "password": "secret1", "phone": "012 345 678",
    })
    body = res.get_json()
    assert res.status_code == 201
    assert body["data"]["token"]
    assert body["data"]["user"]["email"] == "dara@example.com"
    assert body["data"]["user"]["phone"] == "012345678"


def test_register_validation(client, user):
    res = client.post("/api/auth/register", json={"email": "bad", "password": "123", "phone": "99"})
    errors = res.get_json()["errors"]
    assert res.status_code == 422
    assert set(errors) == {"full_name", "email", "password", "phone"}

    dup = client.post("/api/auth/register", json={"full_name": "X", "email": "DEMO@shop.com", "password": "secret1"})
    assert dup.status_code == 422
    assert dup.get_json()["errors"]["email"] == "Email is already registered"


def test_login_and_me(client, user):
    assert client.post("/api/auth/login", json={"email": "demo@shop.com", "password": "nope"}).status_code == 401
    token = login_token(client)
    me = client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.get_json()["data"]["email"] == "demo@shop.com"
    assert client.get("/api/auth/me").status_code == 401
