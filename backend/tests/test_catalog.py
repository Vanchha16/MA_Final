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


def test_products_filter_by_several_brands(client):
    cat = Category(name="Figures", slug="figures")
    for name, brand in [("A", "Bandai"), ("B", "SEGA"), ("C", "Konami")]:
        db.session.add(Product(name=name, slug=name.lower(), category=cat, brand=brand, price=10, stock=1))
    db.session.commit()
    data = client.get("/api/products?brand=Bandai&brand=SEGA").get_json()["data"]
    assert sorted(p["name"] for p in data["items"]) == ["A", "B"]
    assert client.get("/api/products?brand=Konami").get_json()["data"]["total"] == 1


def test_search_suggestions_products_keywords_and_total(client):
    _setup()  # Zoro, Luffy (featured), hidden, OP Box (One Piece), PK Box (Pokemon)
    data = client.get("/api/search/suggestions?q=luf").get_json()["data"]
    assert [p["name"] for p in data["products"]] == ["Luffy"]
    assert data["keywords"] == ["luffy"]
    assert data["total"] == 1

    data = client.get("/api/search/suggestions?q=one").get_json()["data"]
    assert data["total"] == 3  # by series name; the hidden product is not counted
    assert data["products"][0]["name"] == "Luffy"  # featured first
    assert "one piece" in data["keywords"]


def test_search_suggestions_empty_query(client):
    data = client.get("/api/search/suggestions?q=").get_json()["data"]
    assert data == {"products": [], "keywords": [], "total": 0}
