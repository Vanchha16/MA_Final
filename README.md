# Anime World Shop - E-Commerce Mobile App

Online store for anime figures, plush, model kits and anime trading card games (One Piece, Pokemon, Yu-Gi-Oh! ...).

Final project (SU25 - Mobile Application). Flutter mobile app + Flask REST API + MySQL.

| Layer | Tech |
|---|---|
| Mobile | Flutter, Dart, Provider, Dio |
| Backend | Python Flask, SQLAlchemy, Flask-JWT-Extended, bcrypt, Flask-Admin (admin panel), Swagger UI (API docs) |
| Database | MySQL 8.0 |

## Team

1. Loum Vanchha
2. Hong Dalin
3. Khounn Eangleng
4. Sour Sombo
5. Rem Sophannary

## Project structure

```
backend/     Flask REST API (+ the Flask-Admin panel at /admin)
mobile/      Flutter app (customer shop + admin tabs for an admin account)
web-admin/   React web admin (Vite + Tailwind), served by Flask at /dashboard
docs/        Requirement analysis, diagrams, API docs
  PROJECT_DOCUMENTATION  Complete project documentation in one file (.md, .docx, .pdf),
                 built by docs/make_project_doc.py from the documents below
  requirements/  REQUIREMENTS (Requirement Analysis) and USE_CASES (Use Case
                 Diagram + specifications), each as .md, .docx and .pdf;
                 diagrams/ has the PlantUML sources and PNGs
  database/  schema.sql, ERD.md (+ erd.png / erd.pdf), erd.dbml
  API.md     API documentation (also live at /api/docs)
```

## Run the backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate          # Windows  (macOS/Linux: source .venv/bin/activate)
pip install -r requirements.txt
copy .env.example .env          # then put your MySQL password in .env
```

Create the database - either run `docs/database/schema.sql` in MySQL Workbench, or:

```bash
mysql -u root -p -e "CREATE DATABASE ecommerce_db CHARACTER SET utf8mb4"
flask --app run init-db
```

All tables are InnoDB so the foreign keys (the relationships in the ERD) are kept. WAMP's MySQL makes
MyISAM tables by default, which silently drops every foreign key; if an older database shows no
relationships, run `flask --app run init-db` once: it converts the tables to InnoDB and adds the missing keys.

Load sample data (8 categories, 10 anime series, 35 products, demo users):

```bash
flask --app run seed
```

Demo logins: `demo@shop.com` / `demo123` (customer), `admin@shop.com` / `demo123` (admin, the shop owner),
`staff@shop.com` / `demo123` (staff: runs orders and products, but cannot manage staff, promo codes or block customers).
The owner adds and manages staff accounts in **More > Staff** (app) or **Staff** (web admin).

The tests (`backend/tests` and `web-admin/src/test`) are kept on the `store-info` branch, not on `main`.

Forgot-password emails: with `MAIL_MODE=console` (default) the code is printed in the
server terminal, and in debug mode the app shows a "Dev code" chip to tap. For real email
set `MAIL_MODE=smtp` and the `MAIL_*` values in `.env` (see `.env.example`).

Online payments: Bakong KHQR needs `BAKONG_TOKEN` and `BAKONG_ACCOUNT_ID`; ABA PayWay needs
`PAYWAY_MERCHANT_ID` and `PAYWAY_API_KEY` (sandbox by default, `PAYWAY_BASE` switches to live).
Ask the team for the values; they are never committed. After pulling, run `flask --app run init-db`
once so the database gets the new payment columns.

Start the API:

```bash
python run.py                   # http://localhost:5000/api/health
```

Once it is running:

| Address | What |
|---|---|
| <http://localhost:5000/admin> | Admin panel for the shop owner (log in as `admin@shop.com`): dashboard, products and photos, categories, orders, customers, Contact messages |
| <http://localhost:5000/api/docs> | Interactive API documentation (Swagger UI). Press **Authorize** and paste a login token to try the logged-in routes |
| [docs/API.md](docs/API.md) | The same API documentation as one Markdown file, for the report |

After changing an API route, update `backend/app/api_docs.py` and run `flask --app run api-docs`
so `docs/API.md` stays up to date.

## Web admin

Two ways to manage the shop on a computer, signed in with an admin account
(`admin@shop.com` / `demo123`). Staff accounts can use the web admin too, without Staff and Coupons:

| | URL | Built with |
|---|---|---|
| **Web admin** (main) | http://127.0.0.1:5000/dashboard | React 18, Vite, Tailwind CSS, Recharts, React Router |
| **Admin panel** | http://127.0.0.1:5000/admin | Flask-Admin (server pages, Chart.js) |

Both have the same dashboard: revenue, 7-day chart, orders to handle with one-click
Confirm / Ship / Delivered, live activity (Reply, Restock), and low stock with +5.
The web admin also has pages for orders, products (photos), categories, customers
(block), messages, reviews, coupons and staff. It refreshes every 20 seconds, and has a
Light / Dark / System switch (bottom of the sidebar, remembered in the browser; dark
uses the same colours as the app's dark mode).

The built web admin is already in `backend/app/static/web-admin`, so it works as soon
as the backend runs. To change it (needs Node.js 18+):

```bash
cd web-admin
npm install
npm run dev      # http://localhost:5173/dashboard/ (calls the backend on :5000)
npm run build    # writes the new build into backend/app/static/web-admin
```

Screenshots: `docs/screenshots/web-admin/` on the `store-info` branch.

## Run the mobile app

```bash
cd mobile
flutter pub get
flutter run
```

The app calls `http://10.0.2.2:5000/api` (Android emulator -> your PC).
On a real phone, change `baseUrl` in `mobile/lib/core/constants/api_constants.dart` to your PC's Wi-Fi IP.

## Git workflow (one branch per screen)

```bash
git checkout main && git pull                 # start from the latest main
git checkout -b feature/<screen>-screen       # e.g. feature/register-screen
# ... build the screen (+ its API) ...
flutter analyze && flutter test               # must pass before committing
git add -A && git commit -m "feat(<screen>): ..."
git checkout main && git merge --no-ff feature/<screen>-screen
git push origin main                          # or open a Pull Request on GitHub
```

- Commit messages use Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`, `test:`.
- After each screen is merged, it is also added to the Figma file
  ([Anime World Shop – UI](https://www.figma.com/design/lllrJB8GJ2hDEfPWJerlHq)) as frame `NN - <Screen>`.

## API response format

```json
{ "success": true,  "message": "OK", "data": { } }
{ "success": false, "message": "Validation failed", "errors": { "email": "Email is not valid" } }
```

## Endpoints (done so far)

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/health` | - | Server status |
| POST | `/api/auth/register` | - | `full_name`, `email`, `password`, `phone?` |
| POST | `/api/auth/login` | - | `email`, `password` -> `token`, `user` |
| GET | `/api/auth/me` | Bearer | Current user |
| POST | `/api/auth/forgot-password` | - | `email` -> emails a 6-digit code (10 min). Same reply whether or not the email exists |
| POST | `/api/auth/verify-otp` | - | `email`, `code` -> `reset_token` (15 min, cannot be used to log in) |
| POST | `/api/auth/reset-password` | - | `reset_token`, `new_password` |
| GET | `/api/categories` | - | All categories with `product_count` |
| GET | `/api/series` | - | Anime series (One Piece, Pokemon, ...) |
| GET | `/api/brands` | - | Distinct brands, for the filter screen |
| GET | `/api/products` | - | Search / filter / sort / paginate (see below) |
| GET | `/api/products/<id>` | - | Product details + reviews + related products (same series) |
| GET | `/api/search/suggestions?q=` | - | While typing: up to 5 products, search phrases, total matches |
| GET | `/api/wishlist` | Bearer | Wishlist `ids` and `items` |
| POST / DELETE | `/api/wishlist/<product_id>` | Bearer | Add / remove a product |
| GET | `/api/cart?coupon=` | Bearer | Lines, `subtotal`, `discount`, `shipping_fee` (free from $50, else $2), `total`, `savings` |
| POST | `/api/cart` | Bearer | `product_id`, `quantity?` (adds to the line; checks stock, max 20) |
| PUT | `/api/cart/<item_id>` | Bearer | `quantity` |
| DELETE | `/api/cart/<item_id>` | Bearer | Remove a line |
| DELETE | `/api/cart` | Bearer | Empty the cart |
| POST | `/api/cart/coupon` | Bearer | `code` -> cart with the discount, or 422 with the reason. Demo codes: WELCOME10, ANIME5, BIGSALE40 (OLDCODE is expired) |

`/api/products` query params (all optional): `q`, `category_id`, `series_id`, `brand` (repeat for several),
`min_price`, `max_price`, `in_stock=1`, `featured=1`,
`sort=newest|price_asc|price_desc|name`, `page`, `per_page` (max 50).

Example: `/api/products?category_id=6&series_id=1&max_price=50&sort=price_asc`

## Product photos

Photos are not on `main` (`backend/uploads/` is ignored). Get the `backend/uploads` folder from the
`store-info` branch (or the team drive), put it in `backend/uploads/`, then run `flask --app run import-images`.
The `store-info` branch also has `docs/product-photos.md` with the folder list and the source of every photo.

Product images belong to their respective owners and are used for educational purposes only.
The payment logos in `mobile/assets/payment/` are the official Bakong (KHQR) mark from the National Bank of
Cambodia's KHQR asset pack (bakong.nbc.gov.kh) and ABA Bank's logo (ababank.com), used only to label those payment methods.
