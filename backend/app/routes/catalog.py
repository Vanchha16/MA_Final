from flask import Blueprint, request
from sqlalchemy import func, or_
from sqlalchemy.orm import selectinload

from ..extensions import db
from ..models import Category, Product, Series
from ..utils.responses import error, success

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


@bp.get("/categories")
def list_categories():
    counts = dict(
        db.session.query(Product.category_id, func.count(Product.id))
        .filter(Product.is_active.is_(True))
        .group_by(Product.category_id)
        .all()
    )
    categories = Category.query.order_by(Category.id).all()
    return success([{**c.to_dict(), "product_count": counts.get(c.id, 0)} for c in categories])


@bp.get("/series")
def list_series():
    return success([s.to_dict() for s in Series.query.order_by(Series.name).all()])


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


@bp.get("/products")
def list_products():
    """Search + filter + sort + paginate.

    Query params (all optional):
      q, category_id, series_id, brand, min_price, max_price,
      in_stock=1, featured=1, sort=newest|price_asc|price_desc|name, page, per_page
    """
    args = request.args
    query = Product.query.filter(Product.is_active.is_(True))
    final_price = func.coalesce(Product.discount_price, Product.price)

    if q := args.get("q", "").strip():
        like = f"%{q}%"
        query = query.outerjoin(Series).filter(
            or_(Product.name.ilike(like), Product.brand.ilike(like), Series.name.ilike(like))
        )
    if category_id := args.get("category_id", type=int):
        query = query.filter(Product.category_id == category_id)
    if series_id := args.get("series_id", type=int):
        query = query.filter(Product.series_id == series_id)
    if brand := args.get("brand"):
        query = query.filter(Product.brand == brand)
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

    data = product.to_dict()
    data["reviews"] = [
        {"id": r.id, "user": r.user.full_name, "rating": r.rating,
         "comment": r.comment, "created_at": r.created_at.isoformat()}
        for r in sorted(product.reviews, key=lambda r: r.created_at, reverse=True)
    ]
    data["related"] = [p.to_dict() for p in related]
    return success(data)
