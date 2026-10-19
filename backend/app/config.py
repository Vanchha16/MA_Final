import os
from datetime import timedelta

from dotenv import load_dotenv

load_dotenv()


class Config:
    SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-change-me-in-production-0001")
    SQLALCHEMY_DATABASE_URI = os.getenv(
        "DATABASE_URL", "mysql+pymysql://root:@localhost:3306/ecommerce_db"
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "dev-jwt-secret-change-me-in-production-01")
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(days=7)

    # Uploaded files (avatars, product photos) - served at /uploads/<path>
    UPLOAD_FOLDER = os.getenv("UPLOAD_FOLDER", os.path.join(os.path.dirname(os.path.dirname(__file__)), "uploads"))
    MAX_CONTENT_LENGTH = 6 * 1024 * 1024  # reject bigger request bodies

    # Forgot password
    RESET_CODE_MINUTES = 10          # 6-digit code lifetime
    RESET_TOKEN_MINUTES = 15         # token returned by verify-otp, used by reset-password
    RESET_RESEND_SECONDS = 60        # wait before asking for another code
    RESET_MAX_PER_HOUR = 5           # code requests per user per hour
    RESET_MAX_ATTEMPTS = 5           # wrong codes before a code is locked

    # Attempt limits (Flask-Limiter); tests turn them off except where they test them
    RATELIMIT_ENABLED = True
    RATELIMIT_HEADERS_ENABLED = True

    # Email: "console" prints codes to the server log (development);
    # "smtp" sends real email using the MAIL_* settings below.
    MAIL_MODE = os.getenv("MAIL_MODE", "console")
    MAIL_SERVER = os.getenv("MAIL_SERVER", "smtp.gmail.com")
    MAIL_PORT = int(os.getenv("MAIL_PORT", "587"))
    MAIL_USERNAME = os.getenv("MAIL_USERNAME", "")
    MAIL_PASSWORD = os.getenv("MAIL_PASSWORD", "")
    MAIL_FROM = os.getenv("MAIL_FROM", "Anime World Shop <no-reply@animeworld.shop>")

    # KHQR payments: the QR pays BAKONG_ACCOUNT_ID, and the Bakong API (with
    # BAKONG_TOKEN) tells us when it is paid.
    BAKONG_TOKEN = os.getenv("BAKONG_TOKEN", "")
    BAKONG_ACCOUNT_ID = os.getenv("BAKONG_ACCOUNT_ID", "")
    KHQR_MERCHANT_NAME = os.getenv("KHQR_MERCHANT_NAME", "Anime World Shop")
    KHQR_MERCHANT_CITY = os.getenv("KHQR_MERCHANT_CITY", "Phnom Penh")
    KHQR_MINUTES = 15                # an unpaid KHQR / ABA PayWay order is cancelled after this

    # ABA PayWay: the merchant id and API key ("public key") from ABA. PayWay
    # posts the result to PAYWAY_CALLBACK_URL (needs a public address, e.g. an
    # ngrok URL + /api/payments/payway/callback); without one the app's
    # status checks still find the payment.
    PAYWAY_MERCHANT_ID = os.getenv("PAYWAY_MERCHANT_ID", "")
    PAYWAY_API_KEY = os.getenv("PAYWAY_API_KEY", "")
    PAYWAY_BASE = os.getenv("PAYWAY_BASE", "https://checkout-sandbox.payway.com.kh")
    PAYWAY_CALLBACK_URL = os.getenv("PAYWAY_CALLBACK_URL", "")
