"""Import product photos from folders into the catalog.

Put photos in   backend/uploads/products/<product-slug>/   (jpg, png or webp).
Files are used in name order: the first one is the main photo.
Run:            flask --app run import-images
Each photo is made square (padded with its own edge color, never cropped),
saved as a phone-friendly WebP (max 1000 px) in backend/uploads/catalog/,
and the product's images are replaced.
Products without a photo folder keep what they have.
"""
import hashlib
import os
import re
from dataclasses import dataclass, field

from flask import current_app
from PIL import Image, ImageOps, ImageStat, UnidentifiedImageError

from .extensions import db
from .models import Product, ProductImage

PHOTO_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
MAX_SIDE = 1000
WEBP_QUALITY = 82
MARGIN = 0.04  # space around the product, as a share of the photo's longer side
NOTE_FILE = "_PUT_PHOTOS_HERE.txt"


@dataclass
class ImportReport:
    imported: dict = field(default_factory=dict)  # slug -> number of photos
    unknown_folders: list = field(default_factory=list)  # folders with no matching product
    missing: list = field(default_factory=list)  # products that still have no photo
    errors: list = field(default_factory=list)  # (file, reason)


def source_dir():
    return os.path.join(current_app.config["UPLOAD_FOLDER"], "products")


def output_dir():
    return os.path.join(current_app.config["UPLOAD_FOLDER"], "catalog")


def _natural_key(name):
    # "2.jpg" before "10.jpg"
    return [int(part) if part.isdigit() else part.lower() for part in re.split(r"(\d+)", name)]


def _photo_files(folder):
    names = [n for n in os.listdir(folder) if os.path.splitext(n)[1].lower() in PHOTO_EXTENSIONS]
    return [os.path.join(folder, n) for n in sorted(names, key=_natural_key)]


def _edge_color(img):
    """Average color of the photo's outer border, used to extend its background."""
    w, h = img.size
    strips = [img.crop((0, 0, w, 1)), img.crop((0, h - 1, w, h)), img.crop((0, 0, 1, h)), img.crop((w - 1, 0, w, h))]
    stats = [ImageStat.Stat(strip) for strip in strips]
    count = sum(st.count[0] for st in stats)
    return tuple(round(sum(st.sum[i] for st in stats) / count) for i in range(3))


def _square(img):
    """Center the photo on a square canvas so cards and tiles never have to crop it."""
    w, h = img.size
    side = round(max(w, h) * (1 + 2 * MARGIN))
    canvas = Image.new("RGB", (side, side), _edge_color(img))
    canvas.paste(img, ((side - w) // 2, (side - h) // 2))
    return canvas


def _to_webp(path):
    """Open any photo, fix its rotation, put transparency on white, make it square and shrink it."""
    with Image.open(path) as img:
        img = ImageOps.exif_transpose(img)
        if img.mode in ("RGBA", "LA", "P"):
            rgba = img.convert("RGBA")
            white = Image.new("RGB", rgba.size, (255, 255, 255))
            white.paste(rgba, mask=rgba.getchannel("A"))
            img = white
        else:
            img = img.convert("RGB")
        img = _square(img)
        img.thumbnail((MAX_SIDE, MAX_SIDE), Image.LANCZOS)
        return img


def make_folders():
    """Create an empty photo folder for every product, with a note saying which product it is."""
    os.makedirs(source_dir(), exist_ok=True)
    created = 0
    for p in Product.query.filter_by(is_active=True).order_by(Product.id):
        folder = os.path.join(source_dir(), p.slug)
        if not os.path.isdir(folder):
            os.makedirs(folder)
            created += 1
        with open(os.path.join(folder, NOTE_FILE), "w", encoding="utf-8") as f:
            f.write(f"{p.name}\nBrand: {p.brand or '-'}\n\nPut 1-2 photos here (jpg, png or webp).\n"
                    "The first file by name is the main photo, e.g. 1.jpg, 2.jpg.\n")
    return created


def _remove_unused_files():
    """Delete catalog photos no product points to (e.g. after a product was renamed)."""
    used = {os.path.basename(i.image_url) for i in ProductImage.query if i.image_url.startswith("/uploads/catalog/")}
    for name in os.listdir(output_dir()):
        if name.endswith(".webp") and name not in used:
            os.remove(os.path.join(output_dir(), name))


def import_product_images(dry_run=False):
    report = ImportReport()
    products = {p.slug: p for p in Product.query.filter_by(is_active=True)}
    src = source_dir()
    folders = sorted(n for n in os.listdir(src) if os.path.isdir(os.path.join(src, n))) if os.path.isdir(src) else []

    if not dry_run:
        os.makedirs(output_dir(), exist_ok=True)

    for slug in folders:
        product = products.get(slug)
        if product is None:
            report.unknown_folders.append(slug)
            continue

        photos = []
        for path in _photo_files(os.path.join(src, slug)):
            try:
                photos.append(_to_webp(path))
            except (UnidentifiedImageError, OSError) as e:
                report.errors.append((os.path.relpath(path, src), f"not a readable image ({e.__class__.__name__})"))
        if not photos:
            continue
        report.imported[slug] = len(photos)
        if dry_run:
            continue

        # Replace this product's images; the content hash in the name makes apps reload a changed photo
        for old in os.listdir(output_dir()):
            if old.startswith(f"{slug}-"):
                os.remove(os.path.join(output_dir(), old))
        ProductImage.query.filter_by(product_id=product.id).delete()
        for n, img in enumerate(photos, start=1):
            digest = hashlib.sha1(img.tobytes()).hexdigest()[:8]
            name = f"{slug}-{n}-{digest}.webp"
            img.save(os.path.join(output_dir(), name), "WEBP", quality=WEBP_QUALITY, method=6)
            db.session.add(ProductImage(product_id=product.id, image_url=f"/uploads/catalog/{name}",
                                        is_primary=n == 1, sort_order=n - 1))

    if not dry_run:
        db.session.commit()
        _remove_unused_files()

    with_photos = {slug for slug, p in products.items() if p.images} | set(report.imported)
    report.missing = sorted(set(products) - with_photos, key=lambda s: products[s].id)
    return report
