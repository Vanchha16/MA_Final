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


@pytest.fixture()
def app():
    app = create_app(TestConfig)
    with app.app_context():
        db.create_all()
        yield app
        db.session.remove()
        db.drop_all()


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
