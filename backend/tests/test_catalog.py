from app.extensions import db
from app.models import Category, Product, ProductImage, Series


def _setup():
    figures = Category(name="Scale Figures", slug="scale-figures")
    cards = Category(name="TCG Boosters", slug="tcg-boosters")
    op, pk, empty = Series(name="One Piece", slug="one-piece"), Series(name="Pokemon", slug="pokemon"), Series(name="Gundam", slug="gundam")
    db.session.add_all([figures, cards, op, pk, empty])

    def product(name, cat, ser, featured=False, photo=None, active=True):
        p = Product(name=name, slug=name.lower().replace(" ", "-"), category=cat, series=ser, price=10, stock=1,
                    is_featured=featured, is_active=active)
        if photo:
            p.images = [ProductImage(image_url=photo, is_primary=True)]
        db.session.add(p)

    product("Zoro", figures, op, photo="/uploads/catalog/zoro.webp")
    product("Luffy", figures, op, featured=True, photo="/uploads/catalog/luffy.webp")
    product("Hidden", figures, op, featured=True, photo="/uploads/catalog/hidden.webp", active=False)
    product("OP Box", cards, op)
    product("PK Box", cards, pk, photo="/uploads/catalog/pk.webp")
    db.session.commit()


def test_categories_have_active_counts_and_featured_cover(client):
    _setup()
    data = {c["slug"]: c for c in client.get("/api/categories").get_json()["data"]}
    assert data["scale-figures"]["product_count"] == 2  # the inactive product is not counted
    assert data["scale-figures"]["cover_image"] == "http://localhost/uploads/catalog/luffy.webp"  # featured first
    assert data["tcg-boosters"]["cover_image"].endswith("/pk.webp")  # first product with a photo


def test_series_skip_empty_and_most_products_first(client):
    _setup()
    data = client.get("/api/series").get_json()["data"]
    assert [s["name"] for s in data] == ["One Piece", "Pokemon"]
    assert data[0]["product_count"] == 3
    assert data[0]["cover_image"].endswith("/luffy.webp")
