from flask import Flask, send_from_directory

from .config import Config
from .errors import register_error_handlers
from .extensions import bcrypt, cors, db, jwt
from .utils.responses import success


def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)
    app.json.sort_keys = False

    db.init_app(app)
    jwt.init_app(app)
    bcrypt.init_app(app)
    cors.init_app(app)

    from .routes import auth, catalog, profile

    app.register_blueprint(auth.bp)
    app.register_blueprint(catalog.bp)
    app.register_blueprint(profile.bp)
    register_error_handlers(app)

    @app.get("/api/health")
    def health():
        return success({"status": "up"})

    @app.get("/uploads/<path:filename>")
    def uploads(filename):
        return send_from_directory(app.config["UPLOAD_FOLDER"], filename)

    @app.cli.command("init-db")
    def init_db():
        """Create all tables from the models (alternative to running schema.sql)."""
        from . import models  # noqa: F401

        db.create_all()
        print("Database tables created.")

    @app.cli.command("seed")
    def seed():
        """Insert sample categories, series, products and demo users."""
        from .seed import seed_data

        seed_data()

    @app.cli.command("seed-demo")
    def seed_demo():
        """Add the demo customer's sample orders and wishlist (safe to run twice)."""
        from .seed import seed_demo_orders

        seed_demo_orders()

    return app
