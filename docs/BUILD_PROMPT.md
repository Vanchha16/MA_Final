# Anime World Shop — End-to-End Build Prompt

> **How to use:** open the repo root (`final_project_group/`) in an AI coding agent
> (Claude Code, Cursor, etc.) and paste everything below the line. Let it work **one phase at a time**;
> after each phase, check its report, run the app, then say "continue to the next phase".

---

## 0. Your role

You are a senior full-stack engineer finishing a university final project: **Anime World Shop**, an
e-commerce mobile app for anime figures, plush, model kits and anime trading card games (TCG).
Build it **end to end** — backend, database, Flutter app, bonus features, tests and documentation —
following the phases in section 9. The repo already contains a working foundation (section 3):
**extend it, do not rewrite it**.

Work rules:
- Read the existing code first and match its style, folder layout and naming.
- Never change the fixed decisions in section 2 unless the user asks.
- After every phase: run the backend tests, `flutter analyze` (must report 0 issues) and `flutter test`,
  then report what you built, what you tested, and anything that is not working.
- Keep `docs/database/schema.sql`, `backend/app/models.py`, `docs/database/ERD.md` and
  `docs/database/erd.dbml` **in sync** whenever the schema changes.
- Never commit secrets. `.env` stays out of git; `.env.example` documents every variable.
- Ask the user only for things you cannot decide yourself (passwords, API keys, merchant accounts).

---

## 1. The assignment (from SU25-MA-Final-Project.docx)

Build a complete **E-Commerce Mobile Application** with **Flutter** and a **backend system**.

**Mobile app — at least 20 screens**, covering:
- User Management: Splash, Login, Register, Forgot Password, User Profile, Edit Profile
- Product Management: Home, Product Categories, Product List, Product Details, Search, Filtering
- Shopping: Shopping Cart, Add to Cart, Update Quantity, Remove from Cart, Wishlist/Favorites
- Orders: Checkout, Order Confirmation, Order History, Order Details
- Additional: Notifications, Settings, About Application, Contact Information
- Modern, clean, user-friendly UI with smooth navigation

**Backend:** User authentication & authorization, Product management, Category management,
Customer management, Shopping cart management, Order management, APIs for the mobile app.
JSON data exchange, proper error handling and validation, API documentation.

**Database:** ERD + schema design. Suggested entities: Users, Categories, Products, Product Images,
Cart, Orders, Order Items, Addresses, Favorites/Wishlist.

**Technical:** Flutter + Dart, any state management, Git + GitHub.

**Required documents:** Requirement Analysis, Use Case Diagram, ERD, API Documentation.

**Deliverables:** Flutter source, backend source, database design + ERD, complete documentation,
GitHub repository, demo video.

**Bonus marks:** Online payment, Multi-language, Dark mode, Product reviews & ratings,
Advanced search & filtering. **Implement all five.**

---

## 2. Fixed decisions (do not change)

| Topic | Decision |
|---|---|
| App name | **Anime World Shop** (internal package id stays `com.setec.ecommerce_app`) |
| Products sold | Anime figures (scale, chibi/Nendoroid, prize), plush & merch, model kits (Gunpla), TCG booster packs/boxes, starter decks, TCG accessories |
| Mobile | Flutter 3.x, Dart, **Provider** (state), **Dio** (HTTP), Material 3 |
| Backend | Python **Flask** REST API, **Flask-SQLAlchemy**, **Flask-JWT-Extended**, **Flask-Bcrypt**, Flask-CORS |
| Database | **MySQL 8.0** (`ecommerce_db`, utf8mb4). Tests use SQLite in-memory. |
| Auth | JWT Bearer token (7-day expiry), `sub` = user id **as a string**, claim `role` = `customer` or `admin` |
| Colors | Sky blue `#0EA5E9` = theme seed (`ColorScheme.fromSeed`); darker sky `#0284C7` behind white text; aqua `#06B6D4` accent; coral `#F43F5E` for sale badges, discount %, wishlist heart, errors that need attention |
| Logo | `mobile/assets/logo.png` (original), `mobile/assets/logo_centered.png` (used in app), app icons via `flutter_launcher_icons` |
| Web preview | `device_preview` is enabled only on web (`enabled: kIsWeb`), default device Google Pixel 9 |
| Currency | USD, formatted with `intl` (`$1,234.50`) |
| Backgrounds | Auth screens (login, register, forgot/verify/reset password): **clean solid light** `#F6F9FE` (colorScheme.surface) — no blobs, patterns or shapes (user chose option A) |
| Buttons | **Solid fills only — no gradients on buttons.** Primary = solid sky blue `#0284C7` pill with soft shadow (`PillButton`) |
| Icons | **Material icons only — never use emoji** in UI text, labels or designs (e.g. "Welcome back!" + `Icons.waving_hand_rounded`, ratings with `Icons.star_rounded`) |
| Repo layout | `backend/`, `mobile/`, `docs/` at the root |

**API response envelope (every endpoint):**
```json
{ "success": true,  "message": "OK", "data": { } }
{ "success": false, "message": "Validation failed", "errors": { "email": "Email is not valid" } }
```
Paginated lists return `data = { items, page, per_page, total, total_pages }`.

**Status codes:** 200 OK, 201 Created, 400 bad request, 401 not logged in / bad token,
403 forbidden (not admin, disabled account), 404 not found, 409 conflict (e.g. out of stock),
422 validation failed (with per-field `errors`), 500 server error (generic message, details only in logs).

---

## 3. What already exists (keep it, build on it)

### Database — `docs/database/`
`schema.sql`, `ERD.md` (Mermaid), `erd.dbml` (for dbdiagram.io). 13 tables:
`users, password_resets, addresses, categories, series, products, product_images, cart_items,
favorites, orders, order_items, notifications, reviews`.
- `series` = anime franchise (One Piece, Pokemon, ...). Products have `category_id`, nullable `series_id`,
  `brand`, `price`, nullable `discount_price`, `stock`, `is_featured`, `is_active`.
- `orders` copies shipping name/phone/address at checkout; `order_items` copies product name and unit price.
- `orders.status`: pending, confirmed, shipped, delivered, cancelled.
  `payment_method`: cod, khqr, card. `payment_status`: unpaid, paid, failed, refunded.

### Backend — `backend/`
- `run.py`, `app/__init__.py` (app factory, CLI `flask --app run init-db` and `flask --app run seed`),
  `config.py` (reads `.env`), `extensions.py`, `errors.py` (JSON error handlers incl. JWT errors),
  `models.py` (all models with `to_dict()`), `seed.py` (8 categories, 10 series, 35 products with
  placeholder images, demo users `demo@shop.com` / `admin@shop.com`, password `demo123`).
- `utils/responses.py` (`success()`, `error()`), `utils/validators.py` (`require_fields`, `is_valid_email`).
- Routes done:
  - `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me`
  - `GET /api/health`, `GET /api/categories` (with `product_count`), `GET /api/series`, `GET /api/brands`
  - `GET /api/products` — `q, category_id, series_id, brand, min_price, max_price, in_stock=1,
    featured=1, sort=newest|price_asc|price_desc|name, page, per_page(<=50)`
  - `GET /api/products/<id>` — details + `reviews` + `related` (same series)

### Mobile — `mobile/lib/`
- `main.dart` (DevicePreview → MultiProvider → `ShopApp`, light/dark theme, `ThemeProvider` mode)
- `core/constants/api_constants.dart`, `core/network/api_client.dart` (Dio singleton, adds Bearer token
  from SharedPreferences, unwraps envelope, throws `ApiException(message, statusCode, errors)`),
  `core/theme/app_theme.dart`
- `models/user.dart`, `services/auth_service.dart`, `providers/auth_provider.dart`
  (`tryAutoLogin`, `login`, `register`, `logout`), `providers/theme_provider.dart`
- Screens: `splash/` (gradient + logo, auto-login → Home or Login), `auth/login_screen.dart`
  (working, but "Sign up" and "Forgot password?" are TODO), `home/home_screen.dart` (placeholder)
- `test/widget_test.dart` (splash → login)

### Known issues to fix first
1. `ApiConstants.baseUrl` is hard-coded to `http://10.0.2.2:5000/api` — on web it must be
   `http://localhost:5000/api`. Make it configurable: `--dart-define=API_BASE_URL=...`, default
   `localhost` on web and `10.0.2.2` on Android emulator.
2. `backend/.env` does not exist yet — ask the user for the MySQL root password, create it from
   `.env.example`, run `schema.sql` (or `init-db`) and `seed`.
3. The Android emulator on this PC fails to boot (VMware/Hyper-V conflict). Use Chrome with
   device_preview or a real Android phone for testing; do not spend time on the emulator.

---

## 4. Backend — everything still to build

Organise routes as blueprints in `backend/app/routes/`: `auth.py`, `catalog.py` (exist), `profile.py`,
`addresses.py`, `cart.py`, `favorites.py`, `orders.py`, `reviews.py`, `notifications.py`,
`payments.py`, `uploads.py`, `admin/*.py`. Put business logic that is shared (order creation,
notifications) in `backend/app/services/`.

### 4.1 Auth & profile
| Method | Path | Auth | Notes |
|---|---|---|---|
| POST | `/api/auth/forgot-password` | – | body `email`. Create 6-digit OTP, store **hashed** in `password_resets`, expires in 10 min. Always answer "If the email exists, a code was sent" (do not reveal accounts). Send by SMTP; if `MAIL_MODE=console`, print the code to the server log. |
| POST | `/api/auth/verify-otp` | – | `email, code` → returns a short-lived `reset_token` (JWT, 15 min, claim `purpose=reset`) |
| POST | `/api/auth/reset-password` | – | `reset_token, new_password` (min 6). Mark the OTP used. |
| PUT | `/api/profile` | Bearer | `full_name, phone` |
| PUT | `/api/profile/password` | Bearer | `current_password, new_password` |
| POST | `/api/profile/avatar` | Bearer | multipart `file` (jpg/png/webp, ≤ 5 MB) → saves to `backend/uploads/avatars/`, returns `avatar_url` |

Max 5 OTP requests per email per hour (return 429 with a clear message).

### 4.2 Addresses
`GET /api/addresses`, `POST /api/addresses`, `PUT /api/addresses/<id>`, `DELETE /api/addresses/<id>`,
`PUT /api/addresses/<id>/default`. Validate `recipient_name, phone, street, city`. Only one default per
user; the first address becomes default automatically. Users can only touch their own rows (404 otherwise).

### 4.3 Cart
| Method | Path | Notes |
|---|---|---|
| GET | `/api/cart` | `{ items: [CartItem], item_count, subtotal, shipping_fee, total }` |
| POST | `/api/cart` | `product_id, quantity=1` — adds or increases. 409 if quantity would exceed stock or product inactive. |
| PUT | `/api/cart/<item_id>` | `quantity` (1..stock) |
| DELETE | `/api/cart/<item_id>` | remove one |
| DELETE | `/api/cart` | clear |

**Shipping rule:** $2.00 flat, **free when subtotal ≥ $50**. Put it in one function used by cart and checkout.

### 4.4 Favorites (wishlist)
`GET /api/favorites` (list of products), `POST /api/favorites/<product_id>` (add, idempotent),
`DELETE /api/favorites/<product_id>`. Product JSON gets `is_favorite` when the request has a valid token
(use `verify_jwt_in_request(optional=True)` in catalog routes).

### 4.5 Orders
| Method | Path | Notes |
|---|---|---|
| POST | `/api/orders` | Checkout from the cart. Body `address_id, payment_method (cod|khqr), note?`. In **one transaction**: lock product rows (`with_for_update()`), check stock (409 listing the items that are short), create order + items with price snapshot, decrement stock, clear cart, create a notification. Order number `AWS-YYYYMMDD-XXXX` (unique). |
| GET | `/api/orders` | current user, newest first, `?status=` filter, paginated |
| GET | `/api/orders/<id>` | full detail incl. items and shipping |
| POST | `/api/orders/<id>/cancel` | only while `pending`; restores stock; notification |

### 4.6 Reviews (bonus)
`GET /api/products/<id>/reviews` (paginated), `POST /api/products/<id>/reviews` (`rating 1-5, comment?`).
Allowed only if the user has a **delivered** order containing that product; one review per user per
product (second POST updates it). `GET /api/products/<id>` already returns `rating` and `review_count`;
add `can_review` when logged in.

### 4.7 Notifications
`GET /api/notifications` (paginated, `unread_count` in data), `PUT /api/notifications/<id>/read`,
`PUT /api/notifications/read-all`. Create automatically on: order placed, status changed, payment paid,
order cancelled. Admin can broadcast promo notifications.

### 4.8 Online payment — Bakong KHQR (bonus)
- `POST /api/payments/khqr/<order_id>` → returns `{ qr_string, md5, amount, expires_at }` for an
  unpaid `khqr` order. Use the `bakong-khqr` PyPI package (verify its current API in its docs) with
  merchant info from `.env` (`BAKONG_TOKEN`, `BAKONG_ACCOUNT_ID`, `MERCHANT_NAME`, `MERCHANT_CITY`).
- `GET /api/payments/khqr/<order_id>/status` → checks payment by md5; when paid, set
  `payment_status=paid`, `status=confirmed`, create notification.
- **`PAYMENT_MODE=mock`** (default for development and the demo): generate a valid-looking KHQR
  string, and expose `POST /api/payments/khqr/<order_id>/mock-pay` so the demo works without a real
  merchant account. Disable the mock endpoint when `PAYMENT_MODE=live`.

### 4.9 Admin API (Product / Category / Customer / Order management)
All under `/api/admin/*`, protected by an `admin_required` decorator (role claim = `admin`, else 403).
- Dashboard: `GET /api/admin/stats` — totals (revenue, orders by status, customers, low-stock products ≤ 3)
- Products: list (with inactive), create, update, delete (soft delete → `is_active=false`),
  `POST /api/admin/products/<id>/images` (multipart upload, ≤ 5 images, choose primary),
  `DELETE /api/admin/products/<id>/images/<image_id>`
- Categories and Series: full CRUD (slug auto-generated from name, unique; cannot delete a category that still has products → 409)
- Customers: list/search, detail with order history, `PUT /api/admin/customers/<id>/status` (activate/disable)
- Orders: list/filter by status/date, detail, `PUT /api/admin/orders/<id>/status`
  (allowed transitions: pending→confirmed→shipped→delivered, pending/confirmed→cancelled) — each change creates a notification
- Notifications: `POST /api/admin/notifications/broadcast` (`title, message`, type `promo`)

### 4.10 Admin web panel (recommended — shows "Backend System" clearly in the demo)
A small server-rendered panel at `/admin` using Flask + Jinja2 + Bootstrap 5 (CDN), session login
for admins only, using the same models/services as the API: Dashboard, Products (+ image upload),
Categories, Series, Orders (change status), Customers, Send promo notification.
Same sky-blue branding and the logo.

### 4.11 Uploads & static files
Serve `backend/uploads/` at `/uploads/<path>`. Validate extension and size, generate random file
names (uuid), never trust the client file name. Return absolute URLs (`request.host_url`).

### 4.12 API documentation
- Swagger UI with **flasgger** at `/apidocs` (docstrings or YAML specs for every endpoint).
- `docs/api.md`: every endpoint with method, path, auth, request example, response example, error codes.
- `docs/postman/AnimeWorldShop.postman_collection.json` with an environment variable `{{baseUrl}}` and
  `{{token}}` (login request saves the token via a test script).

### 4.13 Backend tests
`backend/tests/` with **pytest** and SQLite in-memory (fixtures: app, client, seeded data, customer token,
admin token). Cover every endpoint: success path, validation errors, auth/ownership errors, stock
conflicts, order cancel restores stock, shipping rule, review permission, admin 403 for customers.
Add `pytest` to `requirements-dev.txt`.

---

## 5. Mobile app — everything still to build

### 5.1 Packages to add
`go_router` (navigation), `flutter_localizations` + `intl` (i18n, gen-l10n with ARB files),
`shimmer` (loading skeletons), `image_picker` (avatar), `url_launcher` (contact links),
`qr_flutter` (KHQR), `photo_view` (zoomable gallery), `smooth_page_indicator` (onboarding/banners).
Keep `provider`, `dio`, `shared_preferences`, `cached_network_image`, `device_preview`.

### 5.2 Structure (extend the existing one)
```
lib/
  core/        constants/ network/ theme/ router/ (go_router config) utils/ (formatters, validators)
  l10n/        app_en.arb, app_km.arb
  models/      user, category, series, product, product_detail, review, cart, address, order, order_item, notification, paged
  services/    auth, catalog, cart, favorites, address, order, review, notification, payment, profile
  providers/   auth, theme, locale, cart (badge + totals), favorites (ids set), notifications (unread count)
  widgets/     product_card, product_grid, price_text, sale_badge, rating_stars, quantity_stepper,
               section_header, empty_view, error_view (with retry), shimmer_*, app_network_image, primary_button
  screens/     one folder per feature (see 5.4)
```

### 5.3 Navigation
- `go_router` with named routes. Auth redirect: guests can browse Home/Products; Cart, Wishlist
  (server side), Checkout, Orders, Profile require login → redirect to Login and come back afterwards.
- `MainShell` with a bottom NavigationBar (5 tabs, state kept per tab with `StatefulShellRoute`):
  **Home · Categories · Wishlist · Cart (badge with item count) · Profile**.

### 5.4 Screens (target 30; the brief requires ≥ 20)
| # | Screen | Content / behaviour | API |
|---|---|---|---|
| 1 | Splash (done) | gradient + logo, auto-login, first-launch → Onboarding | `/auth/me` |
| 2 | Onboarding | 3 slides (Figures / Trading Cards / Fast delivery), skip, shown once | – |
| 3 | Login (done) | email, password, show/hide, "Forgot password?", "Sign up", "Continue as guest" | `/auth/login` |
| 4 | Register | name, email, phone, password, confirm, terms checkbox, field errors from API | `/auth/register` |
| 5 | Forgot Password | email → send code | `/auth/forgot-password` |
| 6 | Verify OTP | 6 boxes, resend countdown 60 s | `/auth/verify-otp` |
| 7 | Reset Password | new + confirm → success → Login | `/auth/reset-password` |
| 8 | Home | greeting, search bar, promo banner carousel (local gradient banners), category chips, "Shop by Anime" series row, Featured grid, New Arrivals, pull-to-refresh | categories, series, products |
| 9 | Categories | grid of 8 categories with image + product count | `/categories` |
| 10 | Shop by Anime (Series) | grid of series → product list filtered | `/series` |
| 11 | Product List | title from category/series/featured; grid, sort menu, filter button, infinite scroll, empty state | `/products` |
| 12 | Search | autofocus field, debounce 400 ms, recent searches (SharedPreferences), popular series chips, results grid | `/products?q=` |
| 13 | Filter (bottom sheet / page) | category, series, brand (multi from `/brands`), price RangeSlider, in-stock switch, sort, reset/apply, active-filter count | `/products` |
| 14 | Product Details | Hero image, PageView gallery + dots, name, series & brand chips, price + strike-through + coral -% badge, rating, stock ("Only 2 left", "Sold out"), description, reviews preview, related row, sticky bottom bar: quantity stepper + Add to Cart, heart toggle | `/products/<id>`, cart, favorites |
| 15 | Image Gallery | full-screen zoom (photo_view), swipe | – |
| 16 | Reviews | list + average breakdown (5-star..1-star bars), "Write a review" if `can_review` | reviews |
| 17 | Write Review | star picker + comment | `POST reviews` |
| 18 | Wishlist | grid, remove, move to cart, empty state | favorites |
| 19 | Cart | items with image, price, quantity stepper (update), swipe-to-delete with undo, subtotal / shipping (free-shipping progress bar "Add $X more for free shipping") / total, Checkout button, empty state | cart |
| 20 | Checkout | address card (change), payment method (Cash on Delivery / Bakong KHQR), order note, summary, Place Order | orders |
| 21 | Address List | select / edit / delete / set default | addresses |
| 22 | Add / Edit Address | form with validation | addresses |
| 23 | KHQR Payment | QR (qr_flutter) with amount and KHQR styling, countdown, poll status every 3 s, "Simulate payment" button in mock mode | payments |
| 24 | Order Confirmation | success animation, order number, total, "View order" / "Continue shopping" | – |
| 25 | Order History | tabs: All / Pending / Shipped / Delivered / Cancelled, cards with status chip | `/orders` |
| 26 | Order Details | status timeline, items, shipping, payment, totals, Cancel (pending only), "Pay now" for unpaid KHQR, "Review" for delivered items | `/orders/<id>` |
| 27 | Notifications | list grouped by day, unread dot, tap → order details, mark all read, unread badge on Profile/AppBar | notifications |
| 28 | Profile | avatar, name, email, menu: My Orders, Addresses, Wishlist, Notifications, Settings, About, Contact, Logout (confirm dialog) | `/auth/me` |
| 29 | Edit Profile | avatar picker (camera/gallery), name, phone | profile |
| 30 | Change Password | current / new / confirm | profile |
| 31 | Settings | Dark mode (System/Light/Dark), Language (English / ខ្មែរ), notification toggle, clear search history, app version | – |
| 32 | About App | logo, version, description, team members & roles, tech stack | – |
| 33 | Contact Us | phone, email, Telegram, Facebook, shop address + opening hours; tap launches `tel:`, `mailto:`, `https://t.me/...` | – |

### 5.5 UI/UX standards
- Material 3, theme from `AppTheme` only (no hard-coded colors in screens except the constants in
  section 2). 8-pt spacing, corner radius 12–16, consistent `ProductCard` everywhere.
- Every data screen has **loading (shimmer), empty, error (message + Retry)** states and pull-to-refresh.
- Optimistic updates for wishlist heart and cart quantity, rolled back on error with a SnackBar.
- Form validation on the client **and** show server field errors (`ApiException.errors`) under fields.
- Hero animation list → details; smooth page transitions; cart badge updates instantly.
- Works and looks correct in light + dark mode, English + Khmer (no overflow with longer Khmer text),
  small (iPhone SE) and large phones in device_preview.
- Images: `cached_network_image` with placeholder + error icon; prices via one `formatPrice()` helper.

### 5.6 Multi-language (bonus)
English + Khmer with `flutter gen-l10n` (`l10n.yaml`, `lib/l10n/app_en.arb`, `app_km.arb`).
**All UI strings** go through `AppLocalizations`. `LocaleProvider` saves the choice. Product data
stays as stored in the database (English).

### 5.7 Mobile tests
Widget tests for: splash → login, login validation, product card (sale badge, sold out), cart totals
and free-shipping bar, filter sheet, settings toggles. Mock services with simple fakes (no network).
`flutter analyze` must report **No issues found**.

---

## 6. Documentation (put everything in `docs/`)

| File | Content |
|---|---|
| `docs/requirements.md` | **Requirement Analysis**: introduction, problem statement, objectives, scope, stakeholders/actors (Guest, Customer, Admin), functional requirements numbered `FR-01…` grouped by module, non-functional requirements `NFR-01…` (security, performance, usability, availability, maintainability), assumptions & constraints, tech stack justification |
| `docs/use-case.md` | **Use Case Diagram** in PlantUML (`docs/diagrams/use-case.puml`) + exported PNG; actors Guest, Customer, Admin, Bakong (payment system); plus a description table (ID, name, actor, pre-conditions, main flow, alternative flows, post-conditions) for the main use cases: Register, Login, Reset Password, Browse & Search, Manage Cart, Checkout, Pay with KHQR, Track Order, Write Review, Manage Products, Manage Orders |
| `docs/database/*` | ERD (update for any schema change) + `schema.sql` + a data dictionary table per entity |
| `docs/api.md` + Swagger + Postman | see 4.12 |
| `docs/architecture.md` | system architecture diagram (Flutter ↔ REST/JSON ↔ Flask ↔ MySQL, Bakong), folder structure, auth flow and checkout sequence diagrams (Mermaid) |
| `docs/user-guide.md` | how to use the app with screenshots (take them with device_preview's screenshot tool) |
| `docs/testing.md` | test strategy, how to run tests, results, manual end-to-end checklist |
| `docs/demo-video-script.md` | 5–8 minute script: intro & team, architecture, register/login, browse/search/filter, details & reviews, wishlist, cart, checkout with KHQR, order tracking, notifications, settings (dark mode + Khmer), admin panel updating an order status live, closing |
| `README.md` (root) | overview, features list, screenshots, setup for backend + MySQL + mobile, env variables, demo accounts, links to all docs |

---

## 7. Data & content
- Extend `seed.py` (keep it idempotent): 35+ products, 2 images each, several reviews from 3–4 demo
  customers, 2–3 orders per demo customer in different statuses, a few notifications, addresses.
- Product photos: no placeholders in the seed. `flask --app run import-images` imports photos from
  `backend/uploads/products/<product-slug>/` (see `docs/product-photos.md` for the folder list);
  official photos stay out of git. Do not use official logos as the app logo.

---

## 8. Deployment & release (final phase)
- Backend: Dockerfile + `gunicorn`, deploy to Render or Railway with a managed MySQL; document env vars.
- Mobile: base URL via `--dart-define=API_BASE_URL=https://.../api`;
  `flutter build apk --release` → put the APK in the GitHub release.
- Git: feature branches (`feature/cart`, `feature/checkout` …), Conventional Commits
  (`feat:`, `fix:`, `docs:`), pull requests into `main`, tag `v1.0.0` at the end.

---

## 9. Phases (do them in order; each ends with tests + a short report)

| Phase | Goal | Done when |
|---|---|---|
| **1. Setup & fixes** | Section 3 known issues; `.env`, MySQL schema + seed; configurable base URL; Login links wired; pytest skeleton | Backend runs on MySQL, app on Chrome logs in with `demo@shop.com` |
| **2. Backend customer API** | 4.1–4.7, 4.11 + tests | All customer endpoints pass pytest |
| **3. Admin API + panel** | 4.9, 4.10 + tests | Admin can manage products/orders; status change creates a notification |
| **4. Mobile foundation** | packages, go_router, MainShell, models, services, providers, shared widgets, l10n setup | Tabs navigate, cart badge works, analyze clean |
| **5. Auth & catalog screens** | screens 1–17 | Browse → search → filter → details → reviews works against the real API |
| **6. Shopping & orders** | screens 18–26 (COD first, then KHQR) | Full purchase flow end to end; stock decreases; order appears in history |
| **7. Account & extras** | screens 27–33, dark mode, Khmer translation complete | All 33 screens reachable, no overflow in km/dark |
| **8. Payment bonus** | 4.8 + screen 23 in mock mode (live mode if the user provides Bakong keys) | KHQR shows, simulated payment marks order paid + notification |
| **9. Quality** | widget tests, pytest coverage, loading/empty/error states everywhere, polish animations | All tests green, manual checklist passes |
| **10. Docs & delivery** | section 6, Swagger, Postman, screenshots, README, Docker, APK, demo script | Every deliverable in section 1 exists in the repo |

At the very end, produce a **final checklist** mapping every requirement and bonus in section 1 to
the file/screen/endpoint that satisfies it, and list anything the team must still do by hand
(record the video, add real product photos, push to GitHub, add Bakong keys).
