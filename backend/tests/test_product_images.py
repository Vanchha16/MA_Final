import os

import pytest
from PIL import Image

from app.extensions import db
from app.models import Category, Product
from app.product_images import NOTE_FILE, import_product_images, make_folders


@pytest.fixture()
def uploads(app, tmp_path):
    app.config["UPLOAD_FOLDER"] = str(tmp_path)
    return tmp_path


def _product(slug="luffy-gear-5", active=True):
    cat = Category.query.first() or Category(name="Scale Figures", slug="scale-figures")
    p = Product(category=cat, name=slug.replace("-", " ").title(), slug=slug, price=10, stock=1, is_active=active)
    db.session.add(p)
    db.session.commit()
    return p


def _photo(folder, name, size=(1600, 1200), mode="RGB"):
    folder.mkdir(parents=True, exist_ok=True)
    Image.new(mode, size, (200, 30, 30, 128) if mode == "RGBA" else (200, 30, 30)).save(folder / name)


def test_imports_photos_in_name_order_as_small_webp(app, uploads, client):
    p = _product()
    src = uploads / "products" / p.slug
    _photo(src, "10.jpg")
    _photo(src, "2.png", mode="RGBA")
    (src / "notes.txt").write_text("not a photo")

    report = import_product_images()
    assert report.imported == {p.slug: 2}
    assert report.missing == []

    images = sorted(p.images, key=lambda i: i.sort_order)
    assert [i.is_primary for i in images] == [True, False]
    assert images[0].image_url.startswith(f"/uploads/catalog/{p.slug}-1-")  # 2.png comes before 10.jpg
    files = sorted(os.listdir(uploads / "catalog"))
    assert len(files) == 2 and all(f.endswith(".webp") for f in files)
    with Image.open(uploads / "catalog" / files[0]) as img:
        assert max(img.size) == 1000

    # The API returns full URLs the app can load
    data = client.get(f"/api/products/{p.id}").get_json()["data"]
    assert data["image_url"].startswith("http://localhost/uploads/catalog/")


def test_reimport_replaces_old_photos(app, uploads):
    p = _product()
    src = uploads / "products" / p.slug
    _photo(src, "1.jpg")
    _photo(src, "2.jpg")
    import_product_images()
    os.remove(src / "2.jpg")

    import_product_images()
    assert len(db.session.get(Product, p.id).images) == 1
    assert len(os.listdir(uploads / "catalog")) == 1


def test_photos_of_a_renamed_product_are_cleaned_up(app, uploads):
    p = _product("old-name")
    _photo(uploads / "products" / "old-name", "1.jpg")
    import_product_images()
    p.slug = "new-name"
    db.session.commit()
    os.rename(uploads / "products" / "old-name", uploads / "products" / "new-name")

    import_product_images()
    files = os.listdir(uploads / "catalog")
    assert len(files) == 1 and files[0].startswith("new-name-1-")


def test_reports_unknown_folders_bad_files_and_missing_products(app, uploads):
    with_photo, without = _product("with-photo"), _product("without-photo")
    _photo(uploads / "products" / with_photo.slug, "1.jpg")
    (uploads / "products" / with_photo.slug / "broken.jpg").write_bytes(b"not an image")
    _photo(uploads / "products" / "typo-folder", "1.jpg")

    report = import_product_images()
    assert report.imported == {"with-photo": 1}
    assert report.unknown_folders == ["typo-folder"]
    assert report.errors[0][0].endswith("broken.jpg")
    assert report.missing == [without.slug]


def test_dry_run_changes_nothing(app, uploads):
    p = _product()
    _photo(uploads / "products" / p.slug, "1.jpg")
    report = import_product_images(dry_run=True)
    assert report.imported == {p.slug: 1}
    assert db.session.get(Product, p.id).images == []
    assert not (uploads / "catalog").exists()


def test_make_folders_creates_one_named_folder_per_active_product(app, uploads):
    p = _product()
    _product("hidden", active=False)
    assert make_folders() == 1
    assert make_folders() == 0  # safe to run again
    assert (uploads / "products" / p.slug / NOTE_FILE).read_text(encoding="utf-8").startswith(p.name)
    assert not (uploads / "products" / "hidden").exists()
