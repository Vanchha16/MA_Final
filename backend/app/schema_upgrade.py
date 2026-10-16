"""Adds columns that newer models have to a database created by an older version.

db.create_all() only creates missing tables, so `flask init-db` calls this too.
Safe to run any number of times (MySQL or SQLite).
"""
from sqlalchemy import inspect, text

from .extensions import db
from .models import Notification, Order

# table -> columns added after the first release
NEW_COLUMNS = {
    Order.__table__: ("discount", "coupon_code", "delivery_method"),
    Notification.__table__: ("event", "order_id", "promo_code"),
}


def add_missing_columns():
    inspector = inspect(db.engine)
    added = []
    for table, names in NEW_COLUMNS.items():
        have = {c["name"] for c in inspector.get_columns(table.name)}
        for name in names:
            if name in have:
                continue
            column = table.c[name]
            ddl = column.type.compile(dialect=db.engine.dialect)
            default = column.default.arg if column.default is not None else None
            sql = f"ALTER TABLE {table.name} ADD COLUMN {name} {ddl}"
            if default is not None:
                sql += f" NOT NULL DEFAULT '{default}'" if isinstance(default, str) else f" NOT NULL DEFAULT {default}"
            db.session.execute(text(sql))
            added.append(f"{table.name}.{name}")
    db.session.commit()
    return added
