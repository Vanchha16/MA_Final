# Anime World Shop - E-Commerce Mobile App

Online store for anime figures, plush, model kits and anime trading card games (One Piece, Pokemon, Yu-Gi-Oh! ...).

Final project (SU25 - Mobile Application). Flutter mobile app + Flask REST API + MySQL.

| Layer | Tech |
|---|---|
| Mobile | Flutter, Dart, Provider, Dio |
| Backend | Python Flask, SQLAlchemy, Flask-JWT-Extended, bcrypt |
| Database | MySQL 8.0 |

## Project structure

```
backend/     Flask REST API
mobile/      Flutter app
docs/        Requirement analysis, diagrams, API docs
  database/  schema.sql, ERD.md, erd.dbml
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

Load sample data (8 categories, 10 anime series, 35 products, demo users):

```bash
flask --app run seed
```

Demo logins: `demo@shop.com` / `demo123` (customer), `admin@shop.com` / `demo123` (admin).

Start the API:

```bash
python run.py                   # http://localhost:5000/api/health
```

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
| GET | `/api/categories` | - | All categories with `product_count` |
| GET | `/api/series` | - | Anime series (One Piece, Pokemon, ...) |
| GET | `/api/brands` | - | Distinct brands, for the filter screen |
| GET | `/api/products` | - | Search / filter / sort / paginate (see below) |
| GET | `/api/products/<id>` | - | Product details + reviews + related products (same series) |

`/api/products` query params (all optional): `q`, `category_id`, `series_id`, `brand`,
`min_price`, `max_price`, `in_stock=1`, `featured=1`,
`sort=newest|price_asc|price_desc|name`, `page`, `per_page` (max 50).

Example: `/api/products?category_id=6&series_id=1&max_price=50&sort=price_asc`
