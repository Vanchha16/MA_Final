"""Cart and order money rules, shared by the cart and (later) checkout."""
from .models import Coupon
from .utils.clock import utcnow

FREE_SHIPPING_MIN = 50.0  # free delivery in Phnom Penh from this subtotal
SHIPPING_FEE = 2.0


def shipping_for(subtotal):
    return 0.0 if subtotal >= FREE_SHIPPING_MIN or subtotal == 0 else SHIPPING_FEE


def find_coupon(code, subtotal):
    """Returns (coupon, None) when the code can be used now, else (None, reason)."""
    code = code.strip().upper() if isinstance(code, str) else ""
    if not code:
        return None, "Enter a promo code"
    coupon = Coupon.query.filter_by(code=code).first()
    if coupon is None or not coupon.is_active:
        return None, "This promo code does not exist"
    if coupon.expires_at is not None and coupon.expires_at < utcnow():
        return None, "This promo code has expired"
    if subtotal < float(coupon.min_subtotal):
        return None, f"Spend ${float(coupon.min_subtotal):g} or more to use {coupon.code}"
    return coupon, None


DELIVERY_METHODS = ("standard", "pickup")


def summarize(items, coupon_code=None, delivery_method="standard"):
    """Totals for cart lines (anything with .product and .quantity). Store pickup has no delivery fee."""
    subtotal = round(sum(float(i.product.final_price) * i.quantity for i in items), 2)
    sale_savings = round(sum((float(i.product.price) - float(i.product.final_price)) * i.quantity for i in items), 2)
    coupon, coupon_error = (None, None)
    if coupon_code:
        coupon, coupon_error = find_coupon(coupon_code, subtotal)
    discount = coupon.discount_for(subtotal) if coupon else 0.0
    shipping = 0.0 if delivery_method == "pickup" else shipping_for(subtotal)
    return {
        "count": sum(i.quantity for i in items),
        "subtotal": subtotal,
        "discount": discount,
        "shipping_fee": shipping,
        "free_shipping_min": FREE_SHIPPING_MIN,
        "total": round(subtotal - discount + shipping, 2),
        "savings": round(sale_savings + discount, 2),
        "coupon": {"code": coupon.code, "description": coupon.description, "discount": discount} if coupon else None,
        "coupon_error": coupon_error,
    }
