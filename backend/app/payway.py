"""ABA PayWay: make a purchase (PayWay answers with its KHQR and an ABA Mobile
deeplink) and ask whether it is paid. Every request is signed with
HMAC-SHA512 over the fields in PayWay's order, then Base64.
"""
import base64
import hashlib
import hmac
import json
import secrets

import requests
from flask import current_app

from .utils.clock import utcnow

# The order PayWay hashes the purchase fields in; empty ones count as "".
PURCHASE_FIELDS = (
    "req_time", "merchant_id", "tran_id", "amount", "items", "shipping", "firstname", "lastname", "email", "phone",
    "type", "payment_option", "return_url", "cancel_url", "continue_success_url", "return_deeplink", "currency",
    "custom_fields", "return_params", "payout", "lifetime", "additional_params", "google_pay_token", "skip_success_page",
)


class PaywayError(Exception):
    """PayWay refused the request or could not be reached."""


def _sign(*values):
    key = current_app.config["PAYWAY_API_KEY"].encode()
    return base64.b64encode(hmac.new(key, "".join(values).encode(), hashlib.sha512).digest()).decode()


def _b64(text):
    return base64.b64encode(text.encode()).decode()


def _post(path, **kwargs):
    url = f"{current_app.config['PAYWAY_BASE'].rstrip('/')}/api/payment-gateway/v1/payments/{path}"
    try:
        res = requests.post(url, timeout=20, **kwargs)
        return res.json()
    except (requests.RequestException, ValueError) as exc:
        raise PaywayError(f"PayWay is not reachable: {exc}") from exc


def new_tran_id(order):
    """At most 20 characters: the order number without dashes plus a short random tail,
    so a reset database can never send PayWay a transaction id it has seen before."""
    return (order.order_number.replace("-", "") + secrets.token_hex(2))[:20]


def purchase(order, tran_id, callback_url):
    """Returns {"qr", "deeplink"} for a new PayWay transaction."""
    cfg = current_app.config
    user = order.user
    first, _, last = (user.full_name or "").partition(" ")
    items = [{"name": i.product_name[:100], "quantity": i.quantity, "price": float(i.unit_price)} for i in order.items]
    fields = dict.fromkeys(PURCHASE_FIELDS, "")
    fields.update(
        req_time=utcnow().strftime("%Y%m%d%H%M%S"),
        merchant_id=cfg["PAYWAY_MERCHANT_ID"],
        tran_id=tran_id,
        amount=f"{float(order.total):.2f}",
        items=_b64(json.dumps(items)),
        # The total already has delivery and the promo code in it
        shipping="0",
        firstname=first[:20], lastname=last[:20], email=user.email, phone=(user.phone or "")[:20],
        type="purchase",
        payment_option="abapay_khqr_deeplink",
        return_url=_b64(callback_url),
        currency="USD",
        lifetime=str(cfg["KHQR_MINUTES"]),
    )
    fields["hash"] = _sign(*(fields[name] for name in PURCHASE_FIELDS))
    data = _post("purchase", data=fields)
    status = data.get("status") or {}
    if str(status.get("code")) != "00" or not data.get("qrString"):
        raise PaywayError(f"PayWay refused the purchase: {status.get('message') or data}")
    return {"qr": data["qrString"], "deeplink": data.get("abapay_deeplink")}


def is_paid(tran_id):
    """PayWay's own answer, so a forged callback can never mark an order paid."""
    req_time = utcnow().strftime("%Y%m%d%H%M%S")
    merchant = current_app.config["PAYWAY_MERCHANT_ID"]
    data = _post("check-transaction-2", json={
        "req_time": req_time, "merchant_id": merchant, "tran_id": tran_id, "hash": _sign(req_time, merchant, tran_id),
    })
    return str((data.get("status") or {}).get("code")) == "00" and (data.get("data") or {}).get("payment_status") == "APPROVED"
