from conftest import login_token

from app.models import Order
from app.seed import seed_data, seed_demo_orders


def test_seed_gives_demo_customer_a_real_profile(client):
    seed_data()
    seed_demo_orders()  # second run must not duplicate anything
    assert Order.query.count() == 6

    token = login_token(client)
    data = client.get("/api/profile/summary", headers={"Authorization": f"Bearer {token}"}).get_json()["data"]
    assert data["points"] == 926
    assert data["tier"]["name"] == "Silver"
    assert data["tier"]["points_to_next"] == 1074
    assert data["order_status"] == {"to_pay": 0, "to_ship": 1, "to_receive": 2, "to_review": 2}
    assert data["stats"]["wishlist"] == 6
