"""Staff management: the owner (admin) adds staff, changes roles, disables and resets them;
staff run the shop but cannot reach the owner-only routes."""
import pytest
from conftest import login_token

from app.extensions import bcrypt, db
from app.models import User


def _account(email, role, name="Team Member"):
    u = User(full_name=name, email=email, role=role, password_hash=bcrypt.generate_password_hash("demo123").decode())
    db.session.add(u)
    db.session.commit()
    return u


def _h(client, email):
    return {"Authorization": f"Bearer {login_token(client, email)}"}


@pytest.fixture()
def owner(app):
    return _account("admin@shop.com", "admin", "Owner")


@pytest.fixture()
def owner_h(client, owner):
    return _h(client, "admin@shop.com")


def test_owner_adds_staff_who_can_run_the_shop_but_not_owner_routes(client, owner_h, user):
    res = client.post("/api/admin/staff", json={"full_name": "Sokha Chan", "email": "Sokha@Shop.com", "password": "welcome123", "phone": "012 345 678"},
                      headers=owner_h)
    assert res.status_code == 201
    staff = res.get_json()["data"]
    assert staff["role"] == "staff" and staff["email"] == "sokha@shop.com" and staff["phone"] == "012345678"
    assert staff["is_active"] is True and staff["last_login_at"] is None

    login = client.post("/api/auth/login", json={"email": "sokha@shop.com", "password": "welcome123"})
    assert login.status_code == 200 and login.get_json()["data"]["user"]["role"] == "staff"
    staff_h = {"Authorization": f"Bearer {login.get_json()['data']['token']}"}
    assert db.session.get(User, staff["id"]).last_login_at is not None

    # shop work: yes
    for url in ("/api/admin/stats", "/api/admin/orders", "/api/admin/products", "/api/admin/categories", "/api/admin/customers",
                f"/api/admin/customers/{user.id}", "/api/admin/contact-messages", "/api/admin/reviews"):
        assert client.get(url, headers=staff_h).status_code == 200, url
    # owner only: no
    assert client.get("/api/admin/staff", headers=staff_h).status_code == 403
    assert client.post("/api/admin/staff", json={}, headers=staff_h).status_code == 403
    assert client.get("/api/admin/coupons", headers=staff_h).status_code == 403
    assert client.put(f"/api/admin/customers/{user.id}", json={"is_active": False}, headers=staff_h).status_code == 403
    # and customers get nowhere
    customer_h = _h(client, "demo@shop.com")
    assert client.get("/api/admin/orders", headers=customer_h).get_json()["message"] == "Shop staff only"


def test_add_staff_checks_fields(client, owner_h, user):
    res = client.post("/api/admin/staff", json={"full_name": "x", "email": "demo@shop.com", "password": "short", "role": "boss"}, headers=owner_h)
    assert res.status_code == 422
    assert set(res.get_json()["errors"]) == {"full_name", "email", "password", "role"}
    assert res.get_json()["errors"]["email"] == "Email is already registered"


def test_list_puts_admins_first_and_hides_customers(client, owner_h, user):
    _account("zara@shop.com", "staff", "Zara")
    _account("bopha@shop.com", "staff", "Bopha")
    data = client.get("/api/admin/staff", headers=owner_h).get_json()["data"]
    assert [s["full_name"] for s in data] == ["Owner", "Bopha", "Zara"]
    assert [s["full_name"] for s in client.get("/api/admin/staff?q=zar", headers=owner_h).get_json()["data"]] == ["Zara"]
    assert client.put(f"/api/admin/staff/{user.id}", json={"role": "admin"}, headers=owner_h).status_code == 404


def test_disable_promote_and_reset_sign_the_person_out(client, owner_h):
    sid = _account("sokha@shop.com", "staff").id
    old = _h(client, "sokha@shop.com")

    res = client.put(f"/api/admin/staff/{sid}", json={"role": "admin", "full_name": "Sokha Chan"}, headers=owner_h)
    assert res.status_code == 200 and res.get_json()["data"]["role"] == "admin"
    assert client.get("/api/admin/stats", headers=old).status_code == 401  # signed out
    assert client.get("/api/admin/staff", headers=_h(client, "sokha@shop.com")).status_code == 200  # now an owner

    assert client.put(f"/api/admin/staff/{sid}", json={"password": "newpass123"}, headers=owner_h).status_code == 200
    assert login_token(client, "sokha@shop.com") is None
    assert login_token(client, "sokha@shop.com", "newpass123")

    assert client.put(f"/api/admin/staff/{sid}", json={"is_active": False}, headers=owner_h).get_json()["data"]["is_active"] is False
    assert client.post("/api/auth/login", json={"email": "sokha@shop.com", "password": "newpass123"}).status_code == 403
    assert client.put(f"/api/admin/staff/{sid}", json={"is_active": True}, headers=owner_h).status_code == 200
    assert login_token(client, "sokha@shop.com", "newpass123")

    assert client.put(f"/api/admin/staff/{sid}", json={"is_active": "no", "password": "x"}, headers=owner_h).status_code == 422


def test_owner_cannot_lock_the_shop_out(client, owner, owner_h):
    me = f"/api/admin/staff/{owner.id}"
    assert client.put(me, json={"role": "staff"}, headers=owner_h).get_json()["message"] == "You can't change your own role"
    assert client.put(me, json={"is_active": False}, headers=owner_h).status_code == 409
    assert client.put(me, json={"full_name": "Shop Owner"}, headers=owner_h).status_code == 200

    # a second admin may demote the first, but not the last one standing
    other = _account("co@shop.com", "admin", "Co Owner")
    co_h = _h(client, "co@shop.com")
    assert client.put(me, json={"role": "staff"}, headers=co_h).status_code == 200
    db.session.refresh(owner)
    assert owner.role == "staff"
    assert client.put(f"/api/admin/staff/{other.id}", json={"is_active": False}, headers=co_h).status_code == 409
