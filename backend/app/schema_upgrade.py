"""Adds columns that newer models have to a database created by an older version.

db.create_all() only creates missing tables, so `flask init-db` calls this too.
Safe to run any number of times (MySQL or SQLite).
"""
from sqlalchemy import inspect, text
from sqlalchemy.schema import AddConstraint

from .extensions import db
from .models import Notification, Order, Payment, Review, User

# table -> columns added after the first release
NEW_COLUMNS = {
    Order.__table__: ("discount", "coupon_code", "delivery_method"),
    Notification.__table__: ("event", "order_id", "promo_code"),
    User.__table__: ("notify_orders", "notify_offers", "notify_news", "token_version", "last_login_at"),
    Review.__table__: ("tags", "updated_at"),
    Payment.__table__: ("tran_id", "deeplink"),
}

# MySQL ENUM columns that got new values later (SQLite stores them as text)
WIDER_ENUMS = {
    User.__table__: ("role",),
    Order.__table__: ("payment_method",),
    Payment.__table__: ("provider",),
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
            if isinstance(default, bool):
                sql += f" NOT NULL DEFAULT {int(default)}"
            elif default is not None:
                sql += f" NOT NULL DEFAULT '{default}'" if isinstance(default, str) else f" NOT NULL DEFAULT {default}"
            db.session.execute(text(sql))
            added.append(f"{table.name}.{name}")
    if db.engine.dialect.name == "mysql":
        for table, names in WIDER_ENUMS.items():
            have = {c["name"]: c for c in inspector.get_columns(table.name)}
            for name in names:
                column = table.c[name]
                if set(getattr(have[name]["type"], "enums", ())) >= set(column.type.enums):
                    continue
                ddl = column.type.compile(dialect=db.engine.dialect)
                default = column.default.arg if column.default is not None and column.default.is_scalar else None
                ddl += f" NOT NULL DEFAULT '{default}'" if isinstance(default, str) else " NOT NULL"
                db.session.execute(text(f"ALTER TABLE {table.name} MODIFY COLUMN {name} {ddl}"))
                added.append(f"{table.name}.{name} (new values)")
    db.session.commit()
    return added


def use_innodb_and_foreign_keys():
    """MySQL only: turns MyISAM tables (WAMP's default engine) into InnoDB and adds
    the foreign keys the models define but the database is missing. A key is
    skipped, and reported, while rows still point to something that is gone."""
    if db.engine.dialect.name != "mysql":
        return []
    done = []
    schema = db.session.execute(text("SELECT DATABASE()")).scalar()
    engines = dict(db.session.execute(text(
        "SELECT TABLE_NAME, ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA = :s"), {"s": schema}).all())
    for table in db.metadata.sorted_tables:
        if engines.get(table.name, "InnoDB").lower() != "innodb":
            db.session.execute(text(f"ALTER TABLE {table.name} ENGINE=InnoDB"))
            done.append(f"{table.name} -> InnoDB")
    have = {tuple(r) for r in db.session.execute(text(
        "SELECT TABLE_NAME, COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE "
        "WHERE TABLE_SCHEMA = :s AND REFERENCED_TABLE_NAME IS NOT NULL"), {"s": schema})}
    for table in db.metadata.sorted_tables:
        for fk in table.foreign_key_constraints:
            column, target = fk.columns[0], fk.elements[0].column
            if (table.name, column.name) in have:
                continue
            orphans = db.session.execute(text(
                f"SELECT COUNT(*) FROM {table.name} c LEFT JOIN {target.table.name} p ON c.{column.name} = p.{target.name} "
                f"WHERE c.{column.name} IS NOT NULL AND p.{target.name} IS NULL")).scalar()
            if orphans:
                done.append(f"skipped {table.name}.{column.name}: {orphans} row(s) point to a missing {target.table.name}")
                continue
            if fk.name is None:
                fk.name = f"fk_{table.name}_{column.name}"
            db.session.execute(AddConstraint(fk))
            done.append(f"{table.name}.{column.name} -> {target.table.name}.{target.name}")
    db.session.commit()
    return done
