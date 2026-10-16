import re

from flask import Blueprint, request
from sqlalchemy import func, or_
from sqlalchemy.orm import selectinload

from ..extensions import db
from ..models import Category, Product, Series, absolute_url
from ..utils.responses import error, success
from .reviews import current_user_id, delivered_product_ids
from .reviews import summary as review_summary

bp = Blueprint("catalog", __name__, url_prefix="/api")

SORTS = {
    "newest": Product.created_at.desc(),
    "price_asc": func.coalesce(Product.discount_price, Product.price).asc(),
    "price_desc": func.coalesce(Product.discount_price, Product.price).desc(),
    "name": Product.name.asc(),
}


def _with_relations(query):
    # load related rows in a few queries instead of one query per product
    return query.options(
        selectinload(Product.category),
        selectinload(Product.series),
        selectinload(Product.images),
        selectinload(Product.reviews),
    )


def _counts_and_covers(group_column):
    """Active product count per group, and a cover photo: the main photo of the
    group's first featured product, else its first product that has a photo."""
    products = (
        _with_relations(Product.query)
        .filter(Product.is_active.is_(True), group_column.isnot(None))
        .order_by(Product.is_featured.desc(), Product.id)
        .all()
    )
    counts, covers = {}, {}
    for p in products:
        key = getattr(p, group_column.key)
        counts[key] = counts.get(key, 0) + 1
        if key not in covers and p.images:
            primary = next((i for i in p.images if i.is_primary), p.images[0])
            covers[key] = absolute_url(primary.image_url)
    return counts, covers


@bp.get("/categories")
def list_categories():
    counts, covers = _counts_and_covers(Product.category_id)
    categories = Category.query.order_by(Category.id).all()
    return success([
        {**c.to_dict(), "product_count": counts.get(c.id, 0), "cover_image": covers.get(c.id) or c.image_url}
        for c in categories
    ])


@bp.get("/series")
def list_series():
    """Series that have products, most products first."""
    counts, covers = _counts_and_covers(Product.series_id)
    rows = [s for s in Series.query.order_by(Series.name).all() if counts.get(s.id)]
    rows.sort(key=lambda s: -counts[s.id])
    return success([
        {**s.to_dict(), "product_count": counts[s.id], "cover_image": covers.get(s.id) or s.image_url}
        for s in rows
    ])


@bp.get("/brands")
def list_brands():
    rows = (
        db.session.query(Product.brand)
        .filter(Product.brand.isnot(None), Product.is_active.is_(True))
        .distinct()
        .order_by(Product.brand)
        .all()
    )
    return success([r[0] for r in rows])


def _search_filter(query, q):
    """Products whose name, brand or series contains q (case-insensitive)."""
    like = f"%{q}%"
    return query.outerjoin(Series).filter(or_(Product.name.ilike(like), Product.brand.ilike(like), Series.name.ilike(like)))


def _keywords(texts, q, limit=5):
    """Search phrases that start at the word matching q, e.g. 'luf' -> 'luffy', 'luffy gear 5'."""
    q = q.lower()
    found = []
    for text in texts:
        words = re.findall(r"[\w][\w.'!-]*", text or "")
        for i in range(len(words)):
            tail = " ".join(words[i:]).lower()
            if q in words[i].lower() or tail.startswith(q):
                for size in (1, 3):
                    phrase = " ".join(words[i:i + size]).lower().strip(".-")
                    if q in phrase and phrase not in found:
                        found.append(phrase)
                break
    return sorted(found, key=len)[:limit]


@bp.get("/search/suggestions")
def search_suggestions():
    """While typing: up to 5 matching products, search phrases and the total match count."""
    q = request.args.get("q", "").strip()
    if not q:
        return success({"products": [], "keywords": [], "total": 0})
    matches = _search_filter(Product.query.filter(Product.is_active.is_(True)), q)
    total = matches.count()
    products = _with_relations(matches).order_by(Product.is_featured.desc(), Product.id).limit(5).all()
    names = [p.name for p in _with_relations(matches).limit(40).all()]
    series = [s.name for s in Series.query.filter(Series.name.ilike(f"%{q}%")).all()]
    brands = [b for (b,) in db.session.query(Product.brand).filter(Product.brand.ilike(f"%{q}%")).distinct()]
    return success({
        "products": [p.to_dict() for p in products],
        "keywords": _keywords(series + brands + names, q),
        "total": total,
    })


@bp.get("/products")
def list_products():
    """Search + filter + sort + paginate.

    Query params (all optional):
      q, category_id, series_id, brand (repeatable), min_price, max_price,
      in_stock=1, featured=1, sort=newest|price_asc|price_desc|name, page, per_page
    """
    args = request.args
    query = Product.query.filter(Product.is_active.is_(True))
    final_price = func.coalesce(Product.discount_price, Product.price)

    if q := args.get("q", "").strip():
        query = _search_filter(query, q)
    if category_id := args.get("category_id", type=int):
        query = query.filter(Product.category_id == category_id)
    if series_id := args.get("series_id", type=int):
        query = query.filter(Product.series_id == series_id)
    # brand can repeat: ?brand=Bandai&brand=SEGA
    if brands := [b for b in args.getlist("brand") if b]:
        query = query.filter(Product.brand.in_(brands))
    if (min_price := args.get("min_price", type=float)) is not None:
        query = query.filter(final_price >= min_price)
    if (max_price := args.get("max_price", type=float)) is not None:
        query = query.filter(final_price <= max_price)
    if args.get("in_stock") == "1":
        query = query.filter(Product.stock > 0)
    if args.get("featured") == "1":
        query = query.filter(Product.is_featured.is_(True))

    sort = args.get("sort", "newest")
    if sort not in SORTS:
        return error("Validation failed", 422, {"sort": f"Must be one of: {', '.join(SORTS)}"})
    query = query.order_by(SORTS[sort], Product.id.desc())

    page = max(args.get("page", 1, type=int), 1)
    per_page = min(max(args.get("per_page", 20, type=int), 1), 50)
    result = _with_relations(query).paginate(page=page, per_page=per_page, error_out=False)

    return success({
        "items": [p.to_dict() for p in result.items],
        "page": result.page,
        "per_page": result.per_page,
        "total": result.total,
        "total_pages": result.pages,
    })


@bp.get("/products/<int:product_id>")
def get_product(product_id):
    product = _with_relations(Product.query).filter_by(id=product_id, is_active=True).first()
    if not product:
        return error("Product not found", 404)

    related = []
    if product.series_id:
        related = (
            _with_relations(Product.query)
            .filter(Product.series_id == product.series_id, Product.id != product.id,
                    Product.is_active.is_(True))
            .limit(6)
            .all()
        )

    me = current_user_id()
    data = product.to_dict()
    newest = sorted(product.reviews, key=lambda r: r.created_at, reverse=True)
    data["reviews"] = [r.to_dict(me) for r in newest]
    data["review_summary"] = review_summary(product.id)
    # for a logged-in customer: their review, and whether they may write one
    mine = next((r for r in newest if r.user_id == me), None) if me else None
    data["my_review"] = mine.to_dict(me) if mine else None
    data["can_review"] = bool(me) and product.id in delivered_product_ids(me)
    data["related"] = [p.to_dict() for p in related]
    return success(data)
