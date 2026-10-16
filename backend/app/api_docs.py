"""API documentation: the OpenAPI 3 spec, served at /api/openapi.json and shown with
Swagger UI at /api/docs. `flask --app run api-docs` writes the same spec as docs/API.md.
A test checks that every /api route is documented here."""
import os

from flask import Blueprint, jsonify, render_template_string, request, send_from_directory
from swagger_ui_bundle import swagger_ui_path

bp = Blueprint("api_docs", __name__)


# ---------------------------------------------------------------------------
# Helpers to keep the spec short
# ---------------------------------------------------------------------------

def ref(name):
    return {"$ref": f"#/components/schemas/{name}"}


def arr(schema):
    return {"type": "array", "items": schema}


def obj(required=(), **props):
    schema = {"type": "object", "properties": props}
    if required:
        schema["required"] = list(required)
    return schema


S = {"type": "string"}
I = {"type": "integer"}
N = {"type": "number"}
B = {"type": "boolean"}
DT = {"type": "string", "format": "date-time"}


def nullable(schema):
    return {**schema, "nullable": True}


def ok(data, description="OK", status="200", message="OK"):
    """A success response: {success: true, message, data}."""
    return {status: {
        "description": description,
        "content": {"application/json": {"schema": {
            "allOf": [ref("Envelope"), {"properties": {"data": data, "message": {"type": "string", "example": message}}}],
        }}},
    }}


def body(schema, example=None):
    content = {"schema": schema}
    if example is not None:
        content["example"] = example
    return {"required": True, "content": {"application/json": content}}


def upload():
    return {"required": True, "content": {"multipart/form-data": {"schema": obj(["file"], file={"type": "string", "format": "binary"})}}}


def query(name, schema=S, description="", required=False):
    return {"name": name, "in": "query", "required": required, "schema": schema, "description": description}


def path(name, description=""):
    return {"name": name, "in": "path", "required": True, "schema": I, "description": description}


def err(*codes):
    return {str(c): {"$ref": f"#/components/responses/{ERROR_NAMES[c]}"} for c in codes}


ERROR_NAMES = {400: "BadRequest", 401: "Unauthorized", 403: "Forbidden", 404: "NotFound", 409: "Conflict", 422: "ValidationError", 429: "TooManyRequests"}
LOGIN = [{"bearerAuth": []}]
PAGE_PARAMS = [query("page", I, "Page number, from 1"), query("per_page", I, "Rows per page (max 100 for admin lists, 50 for products)")]


def op(tag, summary, responses, *, description="", params=(), request_body=None, auth=True, errors=()):
    o = {"tags": [tag], "summary": summary, "responses": {**responses, **err(*errors)}}
    if description:
        o["description"] = description
    if params:
        o["parameters"] = list(params)
    if request_body:
        o["requestBody"] = request_body
    if auth:
        o["security"] = LOGIN
        o["responses"].update(err(401))
    return o


def page_of(schema):
    return obj(items=arr(schema), page=I, per_page=I, total=I, total_pages=I)


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------

SCHEMAS = {
    "Envelope": obj(["success", "message", "data"], success={"type": "boolean", "example": True}, message=S, data={}),
    "Error": obj(["success", "message"], success={"type": "boolean", "example": False}, message=S,
                 errors=nullable({"type": "object", "additionalProperties": True, "description": "Field name -> what is wrong"})),
    "User": obj(id=I, full_name=S, email=S, phone=nullable(S), avatar_url=nullable(S),
                role={"type": "string", "enum": ["customer", "admin"]}, created_at=DT),
    "Category": obj(id=I, name=S, slug=S, description=nullable(S), image_url=nullable(S),
                    product_count={**I, "description": "Products in the shop"}, cover_image=nullable(S)),
    "Series": obj(id=I, name=S, slug=S, image_url=nullable(S), product_count=I, cover_image=nullable(S)),
    "Product": obj(id=I, category=ref("Category"), series=nullable(ref("Series")), brand=nullable(S), name=S, slug=S,
                   description=nullable(S), price=N, discount_price=nullable(N), stock=I, is_featured=B,
                   image_url=nullable({**S, "description": "Main photo"}), images=arr(S), rating=N, review_count=I),
    "Review": obj(id=I, product_id=I, user=S, rating={"type": "integer", "minimum": 1, "maximum": 5}, comment=nullable(S),
                  tags=arr({"type": "string", "enum": ["quality", "as_pictured", "packaging", "delivery", "value"]}),
                  created_at=DT, edited=B, is_mine={**B, "description": "True for the logged-in customer's own review"}),
    "ReviewSummary": obj(rating={**N, "example": 4.6}, count=I,
                         stars={"type": "object", "description": "How many reviews gave each star", "example": {"5": 49, "4": 12, "3": 4, "2": 2, "1": 1}},
                         with_comment=I, tags={"type": "object", "description": "How many reviews chose each tag", "example": {"quality": 31, "packaging": 24}}),
    "ProductDetail": {"allOf": [ref("Product"), obj(reviews=arr(ref("Review")), review_summary=ref("ReviewSummary"),
                                                     my_review=nullable(ref("Review")),
                                                     can_review={**B, "description": "Logged in and the product was delivered to them"},
                                                     related=arr(ref("Product")))]},
    "CartItem": obj(id=I, quantity=I, subtotal=N, product=ref("Product")),
    "Totals": obj(count=I, subtotal=N, discount=N, shipping_fee=N, free_shipping_min=N, total=N, savings=N,
                  coupon=nullable(obj(code=S, description=S, discount=N)), coupon_error=nullable(S)),
    "Cart": {"allOf": [obj(items=arr(ref("CartItem"))), ref("Totals")]},
    "Address": obj(id=I, label=S, recipient_name=S, phone=S, street=S, city=S, province=nullable(S), postal_code=nullable(S),
                   is_default=B, one_line=S),
    "AddressInput": obj(["recipient_name", "phone", "street", "city"], label={**S, "example": "Home"}, recipient_name=S,
                        phone={**S, "example": "012 345 678"}, street=S, city={**S, "description": "District"},
                        province=S, postal_code=S, is_default=B),
    "OrderItem": obj(product_id=nullable(I), product_name=S, image_url=nullable(S), category=nullable(ref("Category")),
                     unit_price=N, quantity=I, subtotal=N,
                     my_rating=nullable({**I, "description": "Stars the customer gave this product (delivered orders), else null"})),
    "Order": obj(id=I, order_number={**S, "example": "AWS-20261016-00042"},
                 status={"type": "string", "enum": ["pending", "confirmed", "shipped", "delivered", "cancelled"]},
                 payment_method={"type": "string", "enum": ["cod", "khqr"]},
                 payment_status={"type": "string", "enum": ["unpaid", "paid", "failed", "refunded"]},
                 subtotal=N, shipping_fee=N, discount=N, coupon_code=nullable(S), total=N,
                 delivery_method={"type": "string", "enum": ["standard", "pickup"]}, item_count=I, created_at=DT),
    "OrderDetail": {"allOf": [ref("Order"), obj(shipping=obj(name=S, phone=S, address=S), note=nullable(S), items=arr(ref("OrderItem")))]},
    "Payment": obj(qr={**S, "description": "KHQR string to show as a QR code"}, amount=N, currency=S,
                   status={"type": "string", "enum": ["pending", "paid", "expired"]}, expires_at=DT, paid_at=nullable(DT),
                   demo={**B, "description": "True in mock mode: the app can simulate the payment"}),
    "PaymentState": obj(payment=ref("Payment"), order=ref("OrderDetail")),
    "Notification": obj(id=I, title=S, message=S, type={"type": "string", "enum": ["order", "promo", "system"]},
                        event={"type": "string", "enum": ["placed", "paid", "confirmed", "shipped", "delivered", "cancelled",
                                                          "welcome", "promo", "news", "support"]},
                        is_read=B, order=nullable(obj(id=I, number=S)), image_url=nullable(S), promo_code=nullable(S), created_at=DT),
    "ContactMessage": obj(id=I, topic={"type": "string", "enum": ["order", "payment", "product", "other"]}, message=S,
                          status={"type": "string", "enum": ["open", "answered"]}, reply=nullable(S),
                          order=nullable(obj(id=I, number=S)), created_at=DT, replied_at=nullable(DT)),
    "Preferences": obj(notify_orders=B, notify_offers=B, notify_news=B),
    "ProfileSummary": obj(user=ref("User"), stats=obj(orders=I, wishlist=I, reviews=I),
                          order_status=obj(to_pay=I, to_ship=I, to_receive=I, to_review=I), points=I,
                          tier=obj(name=S, next_name=nullable(S), points_to_next=I, progress=N)),
    "AdminProduct": {"allOf": [ref("Product"), obj(is_active={**B, "description": "False = hidden from the shop"},
                                                   photos=arr(obj(id=I, url=S, is_primary=B)), created_at=DT)]},
    "ProductInput": obj(name={**S, "example": "Roronoa Zoro 1/8 Scale Figure"}, category_id=I, series_id=nullable(I),
                        brand=S, description=S, price={**N, "example": 120}, discount_price=nullable({**N, "example": 99}),
                        stock={**I, "example": 4}, is_featured=B, is_active=B),
    "AdminCategory": {"allOf": [ref("Category"), obj(product_count=I)]},
    "Customer": {"allOf": [ref("User"), obj(is_active=B, order_count=I, total_spent=N)]},
    "CustomerDetail": {"allOf": [ref("Customer"), obj(addresses=arr(ref("Address")), orders=arr(ref("Order")))]},
    "AdminOrder": {"allOf": [ref("Order"), obj(customer=obj(id=I, full_name=S, email=S, phone=S),
                                               next_statuses=arr({**S, "description": "Statuses this order can move to"}),
                                               image_url=nullable({**S, "description": "First item's photo"}))]},
    "AdminOrderDetail": {"allOf": [ref("OrderDetail"), ref("AdminOrder")]},
    "Stats": obj(week=arr(obj(date={"type": "string", "format": "date"}, revenue=N)), week_revenue=N, products=I, low_stock={**I, "description": "In the shop with 3 or fewer left"}, categories=I, customers=I,
                 orders=I, orders_to_handle={**I, "description": "Pending or confirmed"}, revenue=N, open_messages=I),
    "ActivityEvent": obj(id={**S, "example": "paid-12"}, kind={"type": "string", "enum": ["paid", "order", "message", "sold_out"]},
                         at=DT, title=S, message=S, image_url=nullable(S),
                         action=nullable({"type": "string", "enum": ["confirm", "ship", "reply", "restock"],
                                          "description": "What the shop can do now; null once handled"}),
                         status=nullable({**S, "description": "Order or message status"}), order_id=nullable(I), order_number=nullable(S),
                         message_id=nullable(I), product_id=nullable(I)),
}

RESPONSES = {
    name: {"description": desc, "content": {"application/json": {"schema": ref("Error"), "example": example}}}
    for name, desc, example in [
        ("BadRequest", "Bad request, e.g. an expired code", {"success": False, "message": "Invalid or expired code", "errors": {"code": "The code is incorrect or has expired"}}),
        ("Unauthorized", "No token, or the token is wrong or expired", {"success": False, "message": "Missing or invalid token", "errors": None}),
        ("Forbidden", "Not allowed (blocked account, or not an admin)", {"success": False, "message": "Admins only", "errors": None}),
        ("NotFound", "Not found, or not yours", {"success": False, "message": "Order not found", "errors": None}),
        ("Conflict", "Not possible right now, e.g. sold out or a wrong order step", {"success": False, "message": "This item is sold out", "errors": None}),
        ("ValidationError", "Some fields are wrong; `errors` says which", {"success": False, "message": "Validation failed", "errors": {"email": "Email is not valid"}}),
        ("TooManyRequests", "Too many tries; wait and try again", {"success": False, "message": "Please wait 42s before requesting a new code", "errors": {"retry_after": 42}}),
    ]
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

AUTH, CATALOG, REVIEWS, WISHLIST, CART, ADDRESSES, ORDERS, PAY, PROFILE, NOTES, CONTACT, ADMIN = (
    "Auth", "Catalog", "Reviews", "Wishlist", "Cart", "Addresses", "Orders", "KHQR payment", "Profile", "Notifications", "Contact", "Admin")
TOKEN = obj(token={**S, "description": "Send as `Authorization: Bearer <token>`"}, user=ref("User"))
IDS = body(obj(["product_ids"], product_ids=arr(I)), {"product_ids": [3, 7]})
CART_COUPON = query("coupon", S, "Promo code to preview, e.g. WELCOME10")

PATHS = {
    "/api/health": {"get": op(AUTH, "Is the server up?", ok(obj(status={**S, "example": "up"})), auth=False)},

    # Auth
    "/api/auth/register": {"post": op(AUTH, "Create a customer account", ok(TOKEN, "Registered", "201", "Registered successfully"), auth=False,
                                      description="Also adds a WELCOME10 promo notification. Name 2-100 characters with letters, email up to 150, password 6-72, phone Cambodian. 20 sign-ups an hour per network (429).", errors=(422, 429),
                                      request_body=body(obj(["full_name", "email", "password"], full_name=S, email=S, phone=S,
                                                            password={**S, "minLength": 6}),
                                                        {"full_name": "Sok Dara", "email": "dara@example.com", "phone": "012345678", "password": "secret123"}))},
    "/api/auth/login": {"post": op(AUTH, "Log in", ok(TOKEN, message="Logged in successfully"), auth=False, errors=(401, 403, 422, 429),
                                   description="401 for a wrong email or password, 403 for a blocked account. Tokens last 7 days. "
                                               "429 after 10 tries a minute from one network, or 10 in 15 minutes for one email.",
                                   request_body=body(obj(["email", "password"], email=S, password=S), {"email": "demo@shop.com", "password": "demo123"}))},
    "/api/auth/me": {"get": op(AUTH, "The logged-in user", ok(ref("User")), errors=(403, 404))},
    "/api/auth/forgot-password": {"post": op(
        AUTH, "Email a 6-digit reset code", ok(obj(expires_in=I, resend_after=I, dev_code={**S, "description": "Development only"})),
        auth=False, errors=(422, 429),
        description="Always answers the same, so nobody can find out which emails are registered. 60 s between codes, 5 an hour.",
        request_body=body(obj(["email"], email=S), {"email": "demo@shop.com"}))},
    "/api/auth/verify-otp": {"post": op(AUTH, "Check the code, get a reset token", ok(obj(reset_token=S), message="Code verified"),
                                        auth=False, errors=(400, 422, 429), description="5 wrong tries lock the code.",
                                        request_body=body(obj(["email", "code"], email=S, code=S), {"email": "demo@shop.com", "code": "123456"}))},
    "/api/auth/reset-password": {"post": op(AUTH, "Set a new password with the reset token", ok({"nullable": True}, message="Password updated. You can now log in."),
                                            auth=False, errors=(400, 422),
                                            request_body=body(obj(["reset_token", "new_password"], reset_token=S, new_password={**S, "minLength": 6})))},

    # Catalog
    "/api/categories": {"get": op(CATALOG, "Categories with product counts and a cover photo", ok(arr(ref("Category"))), auth=False)},
    "/api/series": {"get": op(CATALOG, "Anime series that have products, most first", ok(arr(ref("Series"))), auth=False)},
    "/api/brands": {"get": op(CATALOG, "Brand names, A to Z", ok(arr(S)), auth=False)},
    "/api/search/suggestions": {"get": op(CATALOG, "Suggestions while typing", ok(obj(products=arr(ref("Product")), keywords=arr(S), total=I)),
                                          auth=False, params=[query("q", S, "What the customer typed", required=True)],
                                          description="Up to 5 products, matching search phrases and the number of matches.")},
    "/api/products": {"get": op(CATALOG, "Search, filter, sort and page products", ok(page_of(ref("Product"))), auth=False, errors=(422,),
                                params=[query("q", S, "Name, brand or series contains"), query("category_id", I), query("series_id", I),
                                        query("brand", S, "Repeat for several: brand=Bandai&brand=SEGA"), query("min_price", N), query("max_price", N),
                                        query("in_stock", S, "1 = only in stock"), query("featured", S, "1 = only featured"),
                                        query("sort", {"type": "string", "enum": ["newest", "price_asc", "price_desc", "name"]}), *PAGE_PARAMS])},
    "/api/products/{product_id}": {"get": op(CATALOG, "Product details with reviews and related products", ok(ref("ProductDetail")),
                                             auth=False, params=[path("product_id")], errors=(404,))},

    # Reviews
    "/api/products/{product_id}/reviews": {
        "get": op(REVIEWS, "Reviews of a product with the rating summary",
                  ok(obj(summary=ref("ReviewSummary"), items=arr(ref("Review")), page=I, per_page=I, total=I, total_pages=I)),
                  auth=False, params=[path("product_id"), query("rating", I, "Only this many stars (1-5)"),
                                      query("with_comment", S, "1 = only reviews with a comment"), *PAGE_PARAMS],
                  errors=(404, 422), description="Login is optional; when logged in, the customer's own review comes first and has is_mine = true."),
        "post": op(REVIEWS, "Rate a product (posting again edits the review)",
                   ok(obj(review=ref("Review"), summary=ref("ReviewSummary")), "Review created", "201", "Thanks for your review!"),
                   params=[path("product_id")], errors=(403, 404, 422),
                   description="Only for products in one of the customer's delivered orders (403 otherwise). 200 \"Review updated\" when editing.",
                   request_body=body(obj(["rating"], rating={"type": "integer", "minimum": 1, "maximum": 5},
                                         comment={**S, "maxLength": 1000},
                                         tags=arr({"type": "string", "enum": ["quality", "as_pictured", "packaging", "delivery", "value"]})),
                                     {"rating": 5, "comment": "Exactly like the photos!", "tags": ["quality", "packaging"]})),
    },
    "/api/products/{product_id}/reviews/mine": {"delete": op(REVIEWS, "Delete my review of this product", ok(obj(summary=ref("ReviewSummary")), message="Review deleted"),
                                                             params=[path("product_id")], errors=(404,))},
    "/api/reviews/to-review": {"get": op(REVIEWS, "Delivered products I haven't rated yet",
                                         ok(arr(obj(product=ref("Product"), order_id=I, order_number=S))))},

    # Wishlist
    "/api/wishlist": {"get": op(WISHLIST, "Saved products, newest first", ok(obj(ids=arr(I), items=arr(ref("Product")))))},
    "/api/wishlist/{product_id}": {
        "post": op(WISHLIST, "Save a product", ok(obj(product_id=I, in_wishlist=B), message="Added to wishlist"), params=[path("product_id")], errors=(404,)),
        "delete": op(WISHLIST, "Remove a product", ok(obj(product_id=I, in_wishlist=B), message="Removed from wishlist"), params=[path("product_id")]),
    },
    "/api/wishlist/batch-remove": {"post": op(WISHLIST, "Remove several products", ok(obj(ids=arr(I))), request_body=IDS, errors=(422,))},
    "/api/wishlist/batch-add": {"post": op(WISHLIST, "Save several products again (Undo)", ok(obj(ids=arr(I))), request_body=IDS, errors=(422,))},
    "/api/wishlist/move-to-cart": {"post": op(WISHLIST, "Move products to the cart", ok(obj(moved=arr(I), skipped=arr(I), ids=arr(I), cart_count=I)),
                                              request_body=IDS, errors=(422,),
                                              description="Adds one of each and takes it off the wishlist. Sold-out items stay (skipped).")},

    # Cart
    "/api/cart": {
        "get": op(CART, "The cart with totals", ok(ref("Cart")), params=[CART_COUPON]),
        "post": op(CART, "Add to cart", ok(ref("Cart"), "Added", "201", "Added to cart"), errors=(404, 409, 422),
                   description="Adds to the line if the product is already in the cart. At most 20 of an item, and no more than the stock.",
                   request_body=body(obj(["product_id"], product_id=I, quantity={**I, "default": 1}, coupon=S), {"product_id": 1, "quantity": 1})),
        "delete": op(CART, "Empty the cart", ok(ref("Cart"), message="Cart cleared")),
    },
    "/api/cart/{item_id}": {
        "put": op(CART, "Change a line's quantity", ok(ref("Cart")), params=[path("item_id", "Cart line id")], errors=(404, 409, 422),
                  request_body=body(obj(["quantity"], quantity=I, coupon=S), {"quantity": 2})),
        "delete": op(CART, "Remove a line", ok(ref("Cart"), message="Removed from cart"), params=[path("item_id", "Cart line id"), CART_COUPON], errors=(404,)),
    },
    "/api/cart/coupon": {"post": op(CART, "Check a promo code against the cart", ok(ref("Cart"), message="WELCOME10 applied"), errors=(422,),
                                    request_body=body(obj(["code"], code=S), {"code": "WELCOME10"}))},

    # Addresses
    "/api/addresses": {
        "get": op(ADDRESSES, "Saved delivery addresses, default first", ok(arr(ref("Address")))),
        "post": op(ADDRESSES, "Add an address", ok(ref("Address"), "Saved", "201", "Address saved"), errors=(422,),
                   description="The first address, or one sent with is_default, becomes the default.", request_body=body(ref("AddressInput"))),
    },
    "/api/addresses/{address_id}": {
        "put": op(ADDRESSES, "Change an address", ok(ref("Address"), message="Address updated"), params=[path("address_id")], errors=(404, 422),
                  request_body=body(ref("AddressInput"))),
        "delete": op(ADDRESSES, "Delete an address", ok(arr(ref("Address")), message="Address removed"), params=[path("address_id")], errors=(404,),
                     description="If it was the default, the newest other address becomes the default."),
    },

    # Orders
    "/api/checkout": {"get": op(ORDERS, "Everything the Checkout screen shows",
                                ok({"allOf": [ref("Cart"), obj(delivery_method=S, delivery_options=arr(obj(id=S, label=S, detail=S, fee=N)),
                                                               addresses=arr(ref("Address")), store=obj(name=S, address=S, hours=S))]}),
                                params=[CART_COUPON, query("delivery", {"type": "string", "enum": ["standard", "pickup"]})])},
    "/api/orders": {
        "get": op(ORDERS, "My orders, newest first, with their items", ok(arr(ref("OrderDetail"))),
                  description="Unpaid KHQR orders past their 15 minutes are cancelled first (stock goes back)."),
        "post": op(ORDERS, "Place an order from the cart", ok(ref("OrderDetail"), "Placed", "201", "Order placed"), errors=(409, 422),
                   description="Lowers stock and empties the cart. Store pickup is free and needs no address. 409 if an item sold out meanwhile.",
                   request_body=body(obj(["payment_method"], address_id=I, delivery_method={"type": "string", "enum": ["standard", "pickup"]},
                                         payment_method={"type": "string", "enum": ["khqr", "cod"]}, coupon=S, note=S),
                                     {"address_id": 1, "delivery_method": "standard", "payment_method": "khqr", "coupon": "WELCOME10", "note": ""})),
    },
    "/api/orders/{order_id}": {"get": op(ORDERS, "One of my orders", ok(ref("OrderDetail")), params=[path("order_id")], errors=(404,))},
    "/api/orders/{order_id}/received": {"post": op(ORDERS, '"Got it": I have the parcel', ok(ref("OrderDetail"), message="Enjoy your order!"),
                                                   params=[path("order_id")], errors=(404, 409),
                                                   description="Only for shipped orders. Cash orders count as paid.")},

    # KHQR
    "/api/orders/{order_id}/khqr": {"post": op(PAY, "Make (once) the order's KHQR code", ok(ref("PaymentState")), params=[path("order_id")],
                                               errors=(404, 409), description="Calling it again returns the same code. It is valid for 15 minutes.")},
    "/api/orders/{order_id}/payment": {"get": op(PAY, "Payment status (polled by the app)", ok(ref("PaymentState")), params=[path("order_id")],
                                                 errors=(404,), description="Checks Bakong once: pending, paid or expired. Expired cancels the order.")},
    "/api/orders/{order_id}/payment/simulate": {"post": op(PAY, "Demo mode: pretend the bank app paid", ok(ref("PaymentState")),
                                                           params=[path("order_id")], errors=(403, 404, 409),
                                                           description="Only when PAYMENT_PROVIDER=mock.")},

    # Profile
    "/api/profile": {"put": op(PROFILE, "Change name and phone", ok(ref("User"), message="Profile updated"), errors=(422,),
                               request_body=body(obj(["full_name"], full_name=S, phone=nullable(S)), {"full_name": "Demo Customer", "phone": "012345678"}))},
    "/api/profile/summary": {"get": op(PROFILE, "Profile screen numbers: orders by status, points and tier", ok(ref("ProfileSummary")), errors=(404,))},
    "/api/profile/password": {"put": op(PROFILE, "Change password", ok(obj(token={**S, "description": "New login token for this device; the old ones stop working (401)"}), message="Password changed"), errors=(422,),
                                        request_body=body(obj(["current_password", "new_password"], current_password=S, new_password={**S, "minLength": 6})))},
    "/api/profile/avatar": {"post": op(PROFILE, "Upload a profile photo", ok(ref("User"), message="Photo updated"), errors=(422,),
                                       description="JPG, PNG or WebP, 5 MB max. It must open as a picture; it is saved again as a WebP (at most 512 px).", request_body=upload())},
    "/api/profile/preferences": {
        "get": op(PROFILE, "Settings > Notify me about", ok(ref("Preferences")), errors=(404,)),
        "put": op(PROFILE, "Save notification choices", ok(ref("Preferences"), message="Saved"), errors=(404, 422),
                  request_body=body(ref("Preferences"), {"notify_news": False})),
    },

    # Notifications
    "/api/notifications": {"get": op(NOTES, "Newest 100 notifications and the unread count", ok(obj(items=arr(ref("Notification")), unread=I)))},
    "/api/notifications/unread-count": {"get": op(NOTES, "Unread count for the bell badge", ok(obj(unread=I)))},
    "/api/notifications/read-all": {"post": op(NOTES, "Mark all read", ok(obj(unread=I), message="All caught up"))},
    "/api/notifications/{notification_id}/read": {"post": op(NOTES, "Mark one read", ok(obj(unread=I)), params=[path("notification_id")], errors=(404,))},
    "/api/notifications/{notification_id}": {"delete": op(NOTES, "Delete one", ok(obj(unread=I), message="Deleted"), params=[path("notification_id")], errors=(404,))},

    # Contact
    "/api/contact": {
        "get": op(CONTACT, "My Contact messages", ok(arr(ref("ContactMessage")))),
        "post": op(CONTACT, "Send a message to the shop", ok(ref("ContactMessage"), "Sent", "201", "Message sent"), errors=(404, 422, 429),
                   description="The order is kept only for order and payment questions and must be yours. The reply arrives as a `support` notification. "
                               "At most 5 messages in 10 minutes and 30 a day per account (429).",
                   request_body=body(obj(["message"], topic={"type": "string", "enum": ["order", "payment", "product", "other"]},
                                         message={**S, "maxLength": 1000}, order_id=I),
                                     {"topic": "order", "order_id": 12, "message": "When will my Luffy figure arrive?"})),
    },

    # Admin
    "/api/admin/stats": {"get": op(ADMIN, "Dashboard numbers, with paid revenue for each of the last 7 days", ok(ref("Stats")), errors=(403,))},
    "/api/admin/activity": {"get": op(ADMIN, "Live activity: payments, new orders, messages, sold-out products", ok(arr(ref("ActivityEvent"))),
                                      errors=(403,), params=[query("limit", I, "How many (default 20, max 50)")],
                                      description="Newest first. Each event says which action still applies (confirm, ship, reply, restock).")},
    "/api/admin/products": {
        "get": op(ADMIN, "All products, hidden ones too", ok(page_of(ref("AdminProduct"))), errors=(403,),
                  params=[query("q", S, "Name or brand"), query("category_id", I), query("active", S, "1 = in the shop, 0 = hidden"),
                          query("low_stock", S, "1 = 3 or fewer left"), *PAGE_PARAMS]),
        "post": op(ADMIN, "Add a product", ok(ref("AdminProduct"), "Added", "201", "Product added"), errors=(403, 422),
                   description="name, category_id and price are required. The slug is made from the name.",
                   request_body=body(ref("ProductInput"), {"name": "Roronoa Zoro 1/8 Scale Figure", "category_id": 1, "price": 120, "stock": 4})),
    },
    "/api/admin/products/{product_id}": {
        "get": op(ADMIN, "One product", ok(ref("AdminProduct")), params=[path("product_id")], errors=(403, 404)),
        "put": op(ADMIN, "Change a product (send only what changes)", ok(ref("AdminProduct"), message="Product saved"),
                  params=[path("product_id")], errors=(403, 404, 422), request_body=body(ref("ProductInput"), {"stock": 10, "discount_price": None})),
        "delete": op(ADMIN, "Hide a product from the shop", ok(ref("AdminProduct"), message="Product hidden from the shop"),
                     params=[path("product_id")], errors=(403, 404),
                     description="Products are hidden, not deleted, because past orders point to them. Send is_active: true to bring one back."),
    },
    "/api/admin/products/{product_id}/images": {"post": op(ADMIN, "Add a photo", ok(ref("AdminProduct"), "Added", "201", "Photo added"),
                                                           params=[path("product_id")], errors=(403, 404, 422), request_body=upload(),
                                                           description="JPG, PNG or WebP, 5 MB max. Made square and saved as WebP. The first photo is the main one.")},
    "/api/admin/products/{product_id}/images/{image_id}": {"delete": op(ADMIN, "Remove a photo", ok(ref("AdminProduct"), message="Photo removed"),
                                                                        params=[path("product_id"), path("image_id")], errors=(403, 404))},
    "/api/admin/categories": {
        "get": op(ADMIN, "Categories with product counts", ok(arr(ref("AdminCategory"))), errors=(403,)),
        "post": op(ADMIN, "Add a category", ok(ref("AdminCategory"), "Added", "201", "Category added"), errors=(403, 422),
                   request_body=body(obj(["name"], name=S, description=S), {"name": "Plush & Merch", "description": "Plushies, keychains, acrylic stands"})),
    },
    "/api/admin/categories/{category_id}": {
        "put": op(ADMIN, "Rename or describe a category", ok(ref("AdminCategory"), message="Category saved"), params=[path("category_id")],
                  errors=(403, 404, 422), request_body=body(obj(name=S, description=S))),
        "delete": op(ADMIN, "Delete an empty category", ok({"nullable": True}, message="Category deleted"), params=[path("category_id")],
                     errors=(403, 404, 409), description="409 while it still has products."),
    },
    "/api/admin/customers": {"get": op(ADMIN, "Customers", ok(page_of(ref("Customer"))), errors=(403,),
                                       params=[query("q", S, "Name, email or phone"), query("active", S, "1 = active, 0 = blocked"), *PAGE_PARAMS])},
    "/api/admin/customers/{user_id}": {
        "get": op(ADMIN, "A customer with addresses and orders", ok(ref("CustomerDetail")), params=[path("user_id")], errors=(403, 404)),
        "put": op(ADMIN, "Block or unblock a customer", ok(ref("Customer"), message="Customer blocked"), params=[path("user_id")],
                  errors=(403, 404, 422), description="A blocked customer cannot log in, and their current token stops working (403).",
                  request_body=body(obj(["is_active"], is_active=B), {"is_active": False})),
    },
    "/api/admin/orders": {"get": op(ADMIN, "All orders, newest first", ok(page_of(ref("AdminOrder"))), errors=(403, 422),
                                    params=[query("status", {"type": "string", "enum": ["pending", "confirmed", "shipped", "delivered", "cancelled"]}),
                                            query("q", S, "Order number, customer name or email"), *PAGE_PARAMS])},
    "/api/admin/orders/{order_id}": {"get": op(ADMIN, "One order with items and customer", ok(ref("AdminOrderDetail")), params=[path("order_id")], errors=(403, 404))},
    "/api/admin/orders/{order_id}/status": {"put": op(
        ADMIN, "Move an order on", ok(ref("AdminOrderDetail"), message="Order marked shipped"), params=[path("order_id")], errors=(403, 404, 409),
        description="Steps: pending -> confirmed -> shipped -> delivered, or cancelled from pending/confirmed. An unpaid KHQR order can only be "
                    "cancelled. Cancelling puts the stock back. The customer gets a notification for each step.",
        request_body=body(obj(["status"], status={"type": "string", "enum": ["confirmed", "shipped", "delivered", "cancelled"]}), {"status": "shipped"}))},
    "/api/admin/contact-messages": {"get": op(ADMIN, "Contact messages, newest first",
                                              ok(page_of({"allOf": [ref("ContactMessage"), obj(customer=obj(id=I, full_name=S))]})), errors=(403,),
                                              params=[query("status", {"type": "string", "enum": ["open", "answered"]}), *PAGE_PARAMS])},
    "/api/admin/contact-messages/{message_id}/reply": {"post": op(ADMIN, "Answer a message", ok(ref("ContactMessage"), message="Reply sent"),
                                                                  params=[path("message_id")], errors=(403, 404, 422),
                                                                  description="The customer gets the reply in Notifications.",
                                                                  request_body=body(obj(["reply"], reply=S), {"reply": "Your figure ships tomorrow!"}))},
}

TAGS = [
    (AUTH, "Register, log in, forgot password"),
    (CATALOG, "Categories, series, brands, products and search (no login needed)"),
    (REVIEWS, "Star ratings and reviews; customers review products delivered to them"),
    (WISHLIST, "Saved products"),
    (CART, "Shopping cart and promo codes"),
    (ADDRESSES, "Delivery addresses"),
    (ORDERS, "Checkout, placing orders, order history"),
    (PAY, "Bakong KHQR online payment"),
    (PROFILE, "Profile, password, photo, notification choices"),
    (NOTES, "In-app notifications"),
    (CONTACT, "Questions to the shop"),
    (ADMIN, "Shop owner only: an admin account's token"),
]


def spec(server_url="/"):
    return {
        "openapi": "3.0.3",
        "info": {
            "title": "Anime World Shop API",
            "version": "1.0.0",
            "description": (
                "JSON REST API for the Anime World Shop mobile app and its admin panel.\n\n"
                "Every response has the same shape: `{success, message, data}`. Errors have `success: false`, a `message`, "
                "and for validation errors an `errors` object saying which field is wrong.\n\n"
                "Log in with `POST /api/auth/login`, then press **Authorize** and paste the token. "
                "Demo accounts: `demo@shop.com` / `demo123` (customer) and `admin@shop.com` / `demo123` (admin)."
            ),
        },
        "servers": [{"url": server_url}],
        "tags": [{"name": n, "description": d} for n, d in TAGS],
        "paths": PATHS,
        "components": {
            "securitySchemes": {"bearerAuth": {"type": "http", "scheme": "bearer", "bearerFormat": "JWT"}},
            "schemas": SCHEMAS,
            "responses": RESPONSES,
        },
    }


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

SWAGGER_PAGE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Anime World Shop API</title>
  <link rel="icon" href="{{ url_for('static', filename='admin/logo.png') }}">
  <link rel="stylesheet" href="{{ url_for('api_docs.swagger_files', filename='swagger-ui.css') }}">
  <style>body { margin: 0; background: #F5F9FC; } .swagger-ui .topbar { display: none; }
    .swagger-ui .btn.authorize, .swagger-ui .btn.execute { background: #0284C7; border-color: #0284C7; color: #fff; }
    .swagger-ui .btn.authorize svg { fill: #fff; }</style>
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="{{ url_for('api_docs.swagger_files', filename='swagger-ui-bundle.js') }}"></script>
  <script>
    SwaggerUIBundle({ url: "{{ url_for('api_docs.openapi_json') }}", dom_id: "#swagger-ui",
                      persistAuthorization: true, docExpansion: "none", tryItOutEnabled: true });
  </script>
</body>
</html>"""


@bp.get("/api/openapi.json")
def openapi_json():
    return jsonify(spec(request.host_url))


@bp.get("/api/docs")
@bp.get("/api/docs/")
def swagger_ui():
    return render_template_string(SWAGGER_PAGE)


@bp.get("/api/docs/files/<path:filename>")
def swagger_files(filename):
    return send_from_directory(swagger_ui_path, filename)


# ---------------------------------------------------------------------------
# Markdown copy for the report (docs/API.md)
# ---------------------------------------------------------------------------

def _schema_text(schema, schemas, depth=0):
    """A short one-line description of a schema for the Markdown tables."""
    if "$ref" in schema:
        return f"`{schema['$ref'].rsplit('/', 1)[1]}`" + (" or null" if schema.get("nullable") else "")
    if "allOf" in schema:
        return " + ".join(_schema_text(s, schemas, depth) for s in schema["allOf"])
    if schema.get("type") == "array":
        return f"list of {_schema_text(schema['items'], schemas, depth)}"
    if schema.get("type") == "object" and "properties" in schema:
        if depth > 0:
            return "{" + ", ".join(schema["properties"]) + "}"
        return "{" + ", ".join(f"{k}: {_schema_text(v, schemas, depth + 1)}" for k, v in schema["properties"].items()) + "}"
    if "enum" in schema:
        return " \\| ".join(f"`{e}`" for e in schema["enum"])
    return schema.get("type", "any") + (" or null" if schema.get("nullable") else "")


def markdown():
    import json

    s = spec("http://localhost:5000/")
    schemas = s["components"]["schemas"]
    out = [
        "# Anime World Shop - API documentation",
        "",
        "> Generated from the OpenAPI spec in `backend/app/api_docs.py` by `flask --app run api-docs`. Do not edit by hand.",
        "> Interactive version: run the backend and open <http://localhost:5000/api/docs> (Swagger UI).",
        "",
        s["info"]["description"],
        "",
        "Base URL: `http://localhost:5000` (Android emulator: `http://10.0.2.2:5000`). Logged-in routes need the header "
        "`Authorization: Bearer <token>`.",
        "",
        "## Status codes",
        "",
        "| Code | Meaning |",
        "|---|---|",
        "| 200 / 201 | Done (201 = created) |",
        *[f"| {code} | {s['components']['responses'][name]['description']} |" for code, name in ERROR_NAMES.items()],
        "| 500 | Unexpected server error |",
        "",
        "## Endpoints",
        "",
    ]
    by_tag = {}
    for p, methods in s["paths"].items():
        for method, o in methods.items():
            by_tag.setdefault(o["tags"][0], []).append((p, method, o))
    for tag, description in TAGS:
        out += [f"### {tag}", "", description, "", "| Method | Path | What it does | Login |", "|---|---|---|---|"]
        for p, method, o in by_tag.get(tag, []):
            login = "admin" if tag == ADMIN else ("yes" if o.get("security") else "-")
            out.append(f"| `{method.upper()}` | `{p}` | {o['summary']} | {login} |")
        out.append("")
        for p, method, o in by_tag.get(tag, []):
            out += [f"#### `{method.upper()} {p}`", "", o["summary"] + ".", ""]
            if o.get("description"):
                out += [o["description"], ""]
            if o.get("parameters"):
                out.append("Parameters: " + ", ".join(
                    f"`{x['name']}` ({x['in']}{', required' if x.get('required') else ''}){' - ' + x['description'] if x.get('description') else ''}"
                    for x in o["parameters"]) + ".")
                out.append("")
            if rb := o.get("requestBody"):
                media, content = next(iter(rb["content"].items()))
                out.append(f"Body ({media}): {_schema_text(content['schema'], schemas)}")
                if "example" in content:
                    out += ["", "```json", json.dumps(content["example"], indent=2), "```"]
                out.append("")
            good = [(c, r) for c, r in o["responses"].items() if c.startswith("2")]
            for code, r in good:
                data = r["content"]["application/json"]["schema"]["allOf"][1]["properties"]["data"]
                out.append(f"Response {code}: `data` = {_schema_text(data, schemas)}")
            errors = [c for c in o["responses"] if not c.startswith("2")]
            if errors:
                out.append("")
                out.append("Errors: " + ", ".join(sorted(errors)))
            out.append("")
    out += ["## Data shapes", ""]
    for name, schema in schemas.items():
        out += [f"### {name}", "", _schema_text(schema, schemas), ""]
    return "\n".join(out).rstrip() + "\n"


def write_markdown(target=None):
    target = target or os.path.join(os.path.dirname(__file__), "..", "..", "docs", "API.md")
    with open(target, "w", encoding="utf-8", newline="\n") as f:
        f.write(markdown())
    return os.path.normpath(target)
