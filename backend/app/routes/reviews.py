"""Product reviews: anyone can read them; a customer can rate a product once it
has been delivered to them (posting again edits their review)."""
from flask import Blueprint, request
from flask_jwt_extended import get_jwt_identity, jwt_required, verify_jwt_in_request
from sqlalchemy import func

from ..extensions import db
from ..models import REVIEW_TAGS, Order, OrderItem, Product, Review
from ..utils.clock import utcnow
from ..utils.responses import error, success
from ..utils.validators import json_body

bp = Blueprint("reviews", __name__, url_prefix="/api")

MAX_COMMENT = 1000


def current_user_id():
    """The logged-in user's id, or None for a visitor (reading needs no login)."""
    try:
        verify_jwt_in_request(optional=True)
    except Exception:  # noqa: BLE001 - a bad or expired token just reads as a visitor
        return None
    identity = get_jwt_identity()
    return int(identity) if identity else None


def delivered_product_ids(user_id):
    """Products in the user's delivered orders: the ones they may review."""
    return {
        pid for (pid,) in db.session.query(OrderItem.product_id)
        .join(Order).filter(Order.user_id == user_id, Order.status == "delivered", OrderItem.product_id.isnot(None))
    }


def summary(product_id):
    """Average, count, how many of each star, comments and tag counts."""
    rows = Review.query.filter_by(product_id=product_id).with_entities(Review.rating, Review.comment, Review.tags).all()
    stars = {str(n): 0 for n in range(5, 0, -1)}
    tags = {t: 0 for t in REVIEW_TAGS}
    for rating, _, chosen in rows:
        stars[str(rating)] += 1
        for t in chosen or []:
            if t in tags:
                tags[t] += 1
    count = len(rows)
    return {
        "rating": round(sum(r for r, _, _ in rows) / count, 1) if count else 0,
        "count": count,
        "stars": stars,
        "with_comment": sum(1 for _, c, _ in rows if (c or "").strip()),
        "tags": tags,
    }


@bp.get("/products/<int:product_id>/reviews")
def list_reviews(product_id):
    """?rating=5 for one star level, ?with_comment=1 for written ones, plus paging."""
    if not db.session.get(Product, product_id):
        return error("Product not found", 404)
    me = current_user_id()
    args = request.args
    query = Review.query.filter_by(product_id=product_id)
    if (rating := args.get("rating", type=int)) is not None:
        if not 1 <= rating <= 5:
            return error("Validation failed", 422, {"rating": "Must be 1 to 5"})
        query = query.filter(Review.rating == rating)
    if args.get("with_comment") == "1":
        query = query.filter(Review.comment.isnot(None), func.trim(Review.comment) != "")
    # the customer's own review first, then newest
    mine_first = (Review.user_id == me).desc() if me else None
    order = [o for o in (mine_first, Review.created_at.desc(), Review.id.desc()) if o is not None]
    page = max(args.get("page", 1, type=int), 1)
    per_page = min(max(args.get("per_page", 20, type=int), 1), 50)
    result = query.order_by(*order).paginate(page=page, per_page=per_page, error_out=False)
    return success({
        "summary": summary(product_id),
        "items": [r.to_dict(me) for r in result.items],
        "page": result.page,
        "per_page": result.per_page,
        "total": result.total,
        "total_pages": result.pages,
    })


@bp.post("/products/<int:product_id>/reviews")
@jwt_required()
def save_review(product_id):
    """Body: {"rating": 5, "comment": "...", "tags": ["quality", "packaging"]}. Creates or edits."""
    user_id = int(get_jwt_identity())
    if not db.session.get(Product, product_id):
        return error("Product not found", 404)
    if product_id not in delivered_product_ids(user_id):
        return error("You can review a product once it has been delivered to you", 403)

    data = json_body()
    errors = {}
    rating = data.get("rating")
    if not isinstance(rating, int) or isinstance(rating, bool) or not 1 <= rating <= 5:
        errors["rating"] = "Choose 1 to 5 stars"
    comment = data.get("comment")
    if comment is not None and not isinstance(comment, str):
        errors["comment"] = "Comment must be text"
    comment = (comment or "").strip() or None
    if comment and len(comment) > MAX_COMMENT:
        errors["comment"] = f"Keep it under {MAX_COMMENT} characters"
    tags = data.get("tags") or []
    if not isinstance(tags, list) or any(t not in REVIEW_TAGS for t in tags):
        errors["tags"] = f"Tags must be some of: {', '.join(REVIEW_TAGS)}"
    if errors:
        return error("Validation failed", 422, errors)
    tags = [t for t in REVIEW_TAGS if t in tags]  # known order, no repeats

    review = Review.query.filter_by(user_id=user_id, product_id=product_id).first()
    created = review is None
    if created:
        review = Review(user_id=user_id, product_id=product_id)
        db.session.add(review)
    else:
        review.updated_at = utcnow()
    review.rating, review.comment, review.tags = rating, comment, tags
    db.session.commit()
    return success({"review": review.to_dict(user_id), "summary": summary(product_id)},
                   "Thanks for your review!" if created else "Review updated", 201 if created else 200)


@bp.delete("/products/<int:product_id>/reviews/mine")
@jwt_required()
def delete_review(product_id):
    user_id = int(get_jwt_identity())
    review = Review.query.filter_by(user_id=user_id, product_id=product_id).first()
    if not review:
        return error("You have not reviewed this product", 404)
    db.session.delete(review)
    db.session.commit()
    return success({"summary": summary(product_id)}, "Review deleted")


@bp.get("/reviews/to-review")
@jwt_required()
def to_review():
    """Delivered products the customer hasn't rated yet, most recently delivered first."""
    user_id = int(get_jwt_identity())
    reviewed = {r.product_id for r in Review.query.filter_by(user_id=user_id)}
    rows = (
        db.session.query(OrderItem, Order)
        .join(Order)
        .filter(Order.user_id == user_id, Order.status == "delivered", OrderItem.product_id.isnot(None))
        .order_by(Order.created_at.desc())
        .all()
    )
    items, seen = [], set()
    for item, order in rows:
        if item.product_id in reviewed or item.product_id in seen or item.product is None:
            continue
        seen.add(item.product_id)
        items.append({"product": item.product.to_dict(), "order_id": order.id, "order_number": order.order_number})
    return success(items)
