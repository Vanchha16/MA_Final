import click
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

    from .routes import auth, catalog, notifications, orders, profile, shop

    app.register_blueprint(auth.bp)
    app.register_blueprint(catalog.bp)
    app.register_blueprint(profile.bp)
    app.register_blueprint(shop.bp)
    app.register_blueprint(orders.bp)
    app.register_blueprint(notifications.bp)
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

        from .schema_upgrade import add_missing_columns

        db.create_all()
        added = add_missing_columns()
        print("Database tables created." + (f" Added columns: {', '.join(added)}" if added else ""))

    @app.cli.command("seed")
    def seed():
        """Insert sample categories, series, products and demo users."""
        from .seed import seed_data

        seed_data()

    @app.cli.command("import-images")
    @click.option("--dry-run", is_flag=True, help="Only show what would be imported.")
    @click.option("--make-folders", is_flag=True, help="Create an empty photo folder for every product first.")
    def import_images(dry_run, make_folders):
        """Import product photos from uploads/products/<product-slug>/."""
        from . import product_images as pi

        if make_folders:
            print(f"Created {pi.make_folders()} new folders in {pi.source_dir()}")
        report = pi.import_product_images(dry_run=dry_run)
        verb = "Would import" if dry_run else "Imported"
        for slug, count in report.imported.items():
            print(f"  {verb} {count} photo(s) for {slug}")
        for path, reason in report.errors:
            print(f"  Skipped {path}: {reason}")
        for slug in report.unknown_folders:
            print(f"  Unknown folder {slug} (no product with that slug)")
        print(f"{verb} photos for {len(report.imported)} product(s). "
              f"{len(report.missing)} product(s) still have no photo.")

    @app.cli.command("seed-demo")
    def seed_demo():
        """Add the demo customer's sample orders and wishlist (safe to run twice)."""
        from .seed import seed_coupons, seed_demo_notifications, seed_demo_orders

        seed_coupons()
        seed_demo_orders()
        seed_demo_notifications()

    @app.cli.command("advance-orders")
    def advance_orders():
        # For the demo video: moves every open order one step on, like the shop would
        # (cash orders get confirmed, paid orders get shipped) and sends the notification.
        from . import notify
        from .models import Order

        moved = 0
        for order in Order.query.filter(Order.status.in_(["pending", "confirmed"])).all():
            if order.status == "pending" and order.payment_method == "cod":
                order.status = "confirmed"
                notify.order_event(order, "confirmed")
            elif order.status == "confirmed":
                order.status = "shipped"
                notify.order_event(order, "ready" if order.delivery_method == "pickup" else "shipped")
            else:
                continue  # unpaid KHQR orders wait for the payment
            moved += 1
        db.session.commit()
        print(f"Moved {moved} order(s) one step on.")

    return app
