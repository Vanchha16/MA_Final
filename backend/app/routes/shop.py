from flask import Blueprint, request
from flask_jwt_extended import get_jwt_identity, jwt_required
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import selectinload

from ..extensions import db
from ..models import CartItem, Favorite, Product
from ..pricing import find_coupon, summarize
from ..utils.responses import error, success
from ..utils.validators import json_body

bp = Blueprint("shop", __name__, url_prefix="/api")

MAX_QTY_PER_ITEM = 20


def _user_id():
    return int(get_jwt_identity())


def _active_product(product_id):
    return Product.query.filter_by(id=product_id, is_active=True).first()


def _cart_items(user_id):
    return (
        CartItem.query.filter_by(user_id=user_id)
        .options(selectinload(CartItem.product))
        .order_by(CartItem.created_at.desc(), CartItem.id.desc())
        .all()
    )


def _cart_summary(user_id, coupon_code=None):
    """Lines, subtotal, promo discount, delivery and total. Pass ?coupon=CODE to preview a promo code."""
    items = _cart_items(user_id)
    return {"items": [i.to_dict() for i in items], **summarize(items, coupon_code)}


def _is_id(value):
    """A real id: an int, not true/false (bool is an int in Python)."""
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _coupon(value):
    """The promo code sent with a cart call, or None (anything but text is ignored)."""
    return value.strip()[:30] or None if isinstance(value, str) else None


def _max_qty(product):
    return min(product.stock, MAX_QTY_PER_ITEM)


# ---------- Wishlist ----------

@bp.get("/wishlist")
@jwt_required()
def wishlist():
    favs = (
        Favorite.query.filter_by(user_id=_user_id())
        .options(selectinload(Favorite.product))
        .order_by(Favorite.created_at.desc(), Favorite.id.desc())
        .all()
    )
    products = [f.product for f in favs if f.product.is_active]
    return success({"ids": [p.id for p in products], "items": [p.to_dict() for p in products]})


@bp.post("/wishlist/<int:product_id>")
@jwt_required()
def add_to_wishlist(product_id):
    if not _active_product(product_id):
        return error("Product not found", 404)
    user_id = _user_id()
    if not Favorite.query.filter_by(user_id=user_id, product_id=product_id).first():
        db.session.add(Favorite(user_id=user_id, product_id=product_id))
        try:
            db.session.commit()
        except IntegrityError:
            # Two taps at the same moment: the other request saved it already
            db.session.rollback()
    return success({"product_id": product_id, "in_wishlist": True}, "Added to wishlist")


@bp.delete("/wishlist/<int:product_id>")
@jwt_required()
def remove_from_wishlist(product_id):
    Favorite.query.filter_by(user_id=_user_id(), product_id=product_id).delete()
    db.session.commit()
    return success({"product_id": product_id, "in_wishlist": False}, "Removed from wishlist")


def _ids_from_body():
    """{"product_ids": [1, 2]} -> [1, 2], or None when the body is not a list of ids."""
    ids = json_body().get("product_ids")
    if not isinstance(ids, list) or not ids or len(ids) > 100 or not all(_is_id(i) for i in ids):
        return None
    return list(dict.fromkeys(ids))


def _wishlist_ids(user_id):
    favs = Favorite.query.filter_by(user_id=user_id).order_by(Favorite.created_at.desc(), Favorite.id.desc()).all()
    return [f.product_id for f in favs if f.product.is_active]


@bp.post("/wishlist/batch-remove")
@jwt_required()
def remove_many_from_wishlist():
    """Body: {"product_ids": [1, 2]}. Used by the Select view's Remove button."""
    ids = _ids_from_body()
    if ids is None:
        return error("Validation failed", 422, {"product_ids": "Choose at least one product"})
    user_id = _user_id()
    Favorite.query.filter(Favorite.user_id == user_id, Favorite.product_id.in_(ids)).delete(synchronize_session=False)
    db.session.commit()
    return success({"ids": _wishlist_ids(user_id)}, f"Removed {len(ids)} from wishlist")


@bp.post("/wishlist/batch-add")
@jwt_required()
def add_many_to_wishlist():
    """Body: {"product_ids": [1, 2]}. Puts items back (Undo); unknown products are skipped."""
    ids = _ids_from_body()
    if ids is None:
        return error("Validation failed", 422, {"product_ids": "Choose at least one product"})
    user_id = _user_id()
    have = {f.product_id for f in Favorite.query.filter_by(user_id=user_id)}
    # Oldest first, so the first id ends up at the top again
    for product_id in reversed(ids):
        if product_id not in have and _active_product(product_id):
            db.session.add(Favorite(user_id=user_id, product_id=product_id))
            db.session.flush()
    db.session.commit()
    return success({"ids": _wishlist_ids(user_id)}, "Saved to wishlist")


@bp.post("/wishlist/move-to-cart")
@jwt_required()
def move_wishlist_to_cart():
    """Body: {"product_ids": [1, 2]}. Adds one of each to the cart and takes it off the wishlist.
    Sold-out items, and items whose cart line is already at the limit, stay in the wishlist (skipped)."""
    ids = _ids_from_body()
    if ids is None:
        return error("Validation failed", 422, {"product_ids": "Choose at least one product"})
    user_id = _user_id()
    moved, skipped = [], []
    for product_id in ids:
        product = _active_product(product_id)
        item = CartItem.query.filter_by(user_id=user_id, product_id=product_id).first()
        if not product or product.stock <= 0 or (item.quantity if item else 0) + 1 > _max_qty(product):
            skipped.append(product_id)
            continue
        if item:
            item.quantity += 1
        else:
            db.session.add(CartItem(user_id=user_id, product_id=product_id, quantity=1))
        Favorite.query.filter_by(user_id=user_id, product_id=product_id).delete()
        moved.append(product_id)
    db.session.commit()
    count = sum(i.quantity for i in CartItem.query.filter_by(user_id=user_id))
    message = f"Moved {len(moved)} to your cart" if moved else "Nothing could be moved to your cart"
    return success({"moved": moved, "skipped": skipped, "ids": _wishlist_ids(user_id), "cart_count": count}, message)


# ---------- Cart ----------

@bp.get("/cart")
@jwt_required()
def cart():
    return success(_cart_summary(_user_id(), request.args.get("coupon")))


@bp.post("/cart")
@jwt_required()
def add_to_cart():
    """Body: {"product_id": 1, "quantity": 1}. Adds to the existing line if the product is already in the cart."""
    data = json_body()
    product_id = data.get("product_id")
    quantity = data.get("quantity", 1)
    if not _is_id(product_id):
        return error("Validation failed", 422, {"product_id": "Product is required"})
    if not _is_id(quantity):
        return error("Validation failed", 422, {"quantity": "Quantity must be at least 1"})

    product = _active_product(product_id)
    if not product:
        return error("Product not found", 404)

    user_id = _user_id()
    item = CartItem.query.filter_by(user_id=user_id, product_id=product_id).first()
    new_qty = (item.quantity if item else 0) + quantity
    if product.stock <= 0:
        return error("This item is sold out", 409)
    if new_qty > _max_qty(product):
        return error(f"Only {_max_qty(product)} can be added for this item", 409)

    if item:
        item.quantity = new_qty
    else:
        db.session.add(CartItem(user_id=user_id, product_id=product_id, quantity=quantity))
    db.session.commit()
    return success(_cart_summary(user_id, _coupon(data.get("coupon"))), "Added to cart", 201)


def _own_item(item_id):
    return CartItem.query.filter_by(id=item_id, user_id=_user_id()).first()


@bp.put("/cart/<int:item_id>")
@jwt_required()
def update_cart_item(item_id):
    """Body: {"quantity": 2, "coupon": "WELCOME10"?}"""
    item = _own_item(item_id)
    if not item:
        return error("Item not in your cart", 404)
    data = json_body()
    quantity = data.get("quantity")
    if not _is_id(quantity):
        return error("Validation failed", 422, {"quantity": "Quantity must be at least 1"})
    if quantity > _max_qty(item.product):
        return error(f"Only {_max_qty(item.product)} available for this item", 409)
    item.quantity = quantity
    db.session.commit()
    return success(_cart_summary(item.user_id, _coupon(data.get("coupon"))))


@bp.delete("/cart/<int:item_id>")
@jwt_required()
def remove_cart_item(item_id):
    item = _own_item(item_id)
    if not item:
        return error("Item not in your cart", 404)
    user_id = item.user_id
    db.session.delete(item)
    db.session.commit()
    return success(_cart_summary(user_id, request.args.get("coupon")), "Removed from cart")


@bp.delete("/cart")
@jwt_required()
def clear_cart():
    CartItem.query.filter_by(user_id=_user_id()).delete()
    db.session.commit()
    return success(_cart_summary(_user_id()), "Cart cleared")


@bp.post("/cart/coupon")
@jwt_required()
def apply_coupon():
    """Body: {"code": "WELCOME10"}. Checks the code against the current cart."""
    code = _coupon(json_body().get("code")) or ""
    user_id = _user_id()
    subtotal = sum(float(i.product.final_price) * i.quantity for i in _cart_items(user_id))
    coupon, reason = find_coupon(code, subtotal)
    if coupon is None:
        return error(reason, 422, {"code": reason})
    return success(_cart_summary(user_id, coupon.code), f"{coupon.code} applied")
