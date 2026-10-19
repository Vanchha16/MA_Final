import pytest

from app import create_app
from app.config import Config
from app.extensions import bcrypt, db
from app.models import User


class TestConfig(Config):
    TESTING = True
    SQLALCHEMY_DATABASE_URI = "sqlite://"
    MAIL_MODE = "console"
    RESET_RESEND_SECONDS = 0  # tests may request several codes in a row
    RATELIMIT_ENABLED = False  # test_validation.py turns the limits on where it tests them
    BAKONG_TOKEN = ""  # never the real token from .env
    BAKONG_ACCOUNT_ID = "test_shop@devb"
    PAYWAY_MERCHANT_ID = "ec000000"
    PAYWAY_API_KEY = "test-key"


@pytest.fixture()
def app():
    app = create_app(TestConfig)
    with app.app_context():
        db.create_all()
        yield app
        db.session.remove()
        db.drop_all()


@pytest.fixture(autouse=True)
def bank(monkeypatch):
    """Stands in for Bakong and ABA PayWay: a payment is paid once its md5 is in the set,
    and a PayWay purchase gets a made-up QR without calling ABA."""
    from app import payments, payway

    paid = set()
    monkeypatch.setattr(payments, "_is_paid", lambda payment: payment.md5 in paid)
    monkeypatch.setattr(payway, "purchase", lambda order, tran_id, callback: {
        "qr": f"00020101021230510016abaakhppxxx@abaa{tran_id}6304ABCD",
        "deeplink": f"abamobilebank://ababank.com?type=payway&qrcode={tran_id}",
    })
    return paid


@pytest.fixture()
def client(app):
    return app.test_client()


@pytest.fixture()
def user(app):
    u = User(
        full_name="Demo Customer",
        email="demo@shop.com",
        password_hash=bcrypt.generate_password_hash("demo123").decode(),
    )
    db.session.add(u)
    db.session.commit()
    return u


def login_token(client, email="demo@shop.com", password="demo123"):
    res = client.post("/api/auth/login", json={"email": email, "password": password})
    return res.get_json()["data"]["token"] if res.status_code == 200 else None
