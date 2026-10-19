"""Builds the one-file Project Documentation (Markdown, Word) from the existing docs:
REQUIREMENTS.md, USE_CASES.md, database/ERD.md + schema.sql and API.md, plus the
overview, setup, bonus-feature and testing chapters written here.

Run:  python docs/make_project_doc.py   (needs pip install pypandoc_binary python-docx)
Then export PROJECT_DOCUMENTATION.docx to PDF (Word, or LibreOffice:
soffice --headless --convert-to pdf PROJECT_DOCUMENTATION.docx).
"""
import re
import sys
from datetime import date
from pathlib import Path

import pypandoc

DOCS = Path(__file__).resolve().parent
sys.path.insert(0, str(DOCS / "requirements"))
from make_docx import polish  # noqa: E402

PAGE_BREAK = '\n```{=openxml}\n<w:p><w:r><w:br w:type="page"/></w:r></w:p>\n```\n\n'
REPO = "https://github.com/Vanchha16/MA_Final"


def read(rel):
    return (DOCS / rel).read_text(encoding="utf-8")


def chapter(md, number, title, drop=()):
    """One source document as chapter `number`: its title becomes the chapter heading,
    other headings go one level down and get the chapter number in front
    ("## 1. Introduction" -> "## 2.1 Introduction"); links to other files become text."""
    out = [f"# {number}. {title}"]
    skip_code = False  # mermaid / shell blocks are for GitHub and developers, not the report
    for line in md.splitlines():
        if skip_code:
            skip_code = line.strip() != "```"
            continue
        if line.strip() in ("```mermaid", "```bash"):
            skip_code = True
            continue
        if line.startswith("# "):
            continue  # the document's own title
        if any(line.startswith(d) for d in drop):
            continue
        m = re.match(r"^(#{2,6}) (\d+(?:\.\d+)*)\.? (.*)$", line)
        if m:
            line = f"{m.group(1)} {number}.{m.group(2)} {m.group(3)}"
        # [text](OTHER.md) / [text](../x) -> text ; images stay
        line = re.sub(r"(?<!!)\[([^\]]+)\]\((?!https?:)[^)]+\)", r"\1", line)
        out.append(line)
    return "\n".join(out).strip() + "\n"


def without_section(md, start, end=None):
    """Drops the part of md from the line starting with `start` up to `end` (or the next heading)."""
    lines, keep, out = md.splitlines(), True, []
    for line in lines:
        if line.startswith(start):
            keep = False
            continue
        if not keep and ((end and line.startswith(end)) or (not end and line.startswith("#"))):
            keep = True
        if keep:
            out.append(line)
    return "\n".join(out)


today = date.today().strftime("%d %B %Y")

cover = f"""---
title: "Anime World Shop"
subtitle: "E-Commerce Mobile Application - Complete Project Documentation"
---

**Course:** Mobile Application (Year 4, SU25) - Final Project\\
**Institute:** SETEC Institute\\
**Date:** {today}\\
**Source code:** <{REPO}>

**Team members**

| No. | Name |
|---|---|
| 1 | Loum Vanchha |
| 2 | Hong Dalin |
| 3 | Khounn Eangleng |
| 4 | Sour Sombo |
| 5 | Rem Sophannary |

**Lecturer:** Ly Lay
{PAGE_BREAK}
## Contents

1. Project Overview
2. Requirement Analysis
3. Use Case Diagram and Specifications
4. Database Design and ER Diagram
5. API Documentation
6. Installation and Running the Project
7. Bonus Features
8. Testing
9. Project Deliverables Checklist

Appendix A. Database Schema (SQL)
{PAGE_BREAK}"""

overview = f"""# 1. Project Overview

**Anime World Shop** is an online shop for anime figures, plush, model kits and anime trading
card games (One Piece, Pokemon, Yu-Gi-Oh! ...). Customers shop in a Flutter mobile app; the shop
team runs the shop from the same app (admin tabs) or from a web admin on a computer. Everything
talks to one Flask REST API backed by a MySQL database.

## 1.1 System parts

| Part | Who uses it | Technology |
|---|---|---|
| Mobile app (customer) | Shoppers | Flutter 3, Dart, Provider, Dio |
| Mobile app (admin tabs) | Shop owner (admin) and staff | Flutter (same app, opened by an admin or staff account) |
| REST API | The app and the web admin | Python Flask, SQLAlchemy, Flask-JWT-Extended, bcrypt |
| Web admin | Shop owner and staff on a computer | React 18, Vite, Tailwind CSS, Recharts (at `/dashboard`) |
| Admin panel (fallback) | Shop owner | Flask-Admin (at `/admin`) |
| Database | All of the above | MySQL 8 (InnoDB, 16 tables, 19 foreign keys) |
| Payments | Customers | Bakong KHQR (bakong-khqr) and ABA PayWay (signed REST calls) |
| Source control | The team | Git and GitHub ({REPO}) |

## 1.2 Architecture

```
 Flutter app (customer + admin)      React web admin (/dashboard)
               \\                          /
                \\   HTTPS JSON (JWT)     /
                 v                       v
            Flask REST API  (/api/...)  +  Flask-Admin (/admin)
                 |            |                  |
              MySQL      Bakong KHQR API     ABA PayWay API
          (ecommerce_db)
```

Every API response has the same shape `{{success, message, data}}`; errors add an `errors`
object that says which field is wrong. Logged-in calls send `Authorization: Bearer <token>`.

## 1.3 Demo accounts

| Account | Email | Password | Can do |
|---|---|---|---|
| Customer | demo@shop.com | demo123 | Shop, pay, track orders, review |
| Admin (shop owner) | admin@shop.com | demo123 | Everything, including staff, promo codes, blocking customers |
| Staff | staff@shop.com | demo123 | Orders, products, categories, messages, reviews; view customers |
"""

erd = read("database/ERD.md")
erd = re.sub(r"\]\((erd[^)]*\.(png|pdf|dbml|svg))\)", r"](database/\1)", erd)
erd_ch = chapter(erd, 4, "Database Design and ER Diagram", drop=("All 16 tables", "image [", "(GitHub draws", "Files:", "[`erd", "`python docs"))
erd_ch = erd_ch.replace("![ERD](database/erd.png)", "## Overview diagram\n\n![Overview ER diagram](database/erd.png)")
erd_ch += """
## Tables

| Table | Holds |
|---|---|
| users | Customers, staff and admins (role), login and settings |
| addresses | A customer's delivery addresses (one is the default) |
| password_resets | 6-digit "forgot password" codes |
| categories | Product categories (Scale Figures, Plush, TCG Boosters, ...) |
| series | Anime series (One Piece, Pokemon, ...) |
| products | Products with price, sale price, stock, brand |
| product_images | A product's photos (one is the main photo) |
| cart_items | What is in each customer's cart |
| favorites | Each customer's wishlist |
| orders | Orders with delivery, payment method and status |
| order_items | The products in an order (name and price copied at purchase) |
| payments | KHQR / ABA PayWay payment attempts |
| coupons | Promo codes |
| reviews | Star ratings and reviews of delivered products |
| notifications | In-app notifications (order updates, offers, replies) |
| contact_messages | Questions sent from the Contact screen and the shop's replies |

The full `CREATE TABLE` script is in Appendix A.
"""

api = read("API.md")
api_ch = chapter(api, 5, "API Documentation", drop=("> Generated", "> Interactive"))
api_ch = api_ch.replace(f"# 5. API Documentation", "# 5. API Documentation\n\nThe same documentation is live in Swagger UI at "
                        "<http://localhost:5000/api/docs> while the backend runs (try every call there with a login token).", 1)

reqs = chapter(read("requirements/REQUIREMENTS.md"), 2, "Requirement Analysis", drop=("Related documents:", "---"))
ucs = chapter(without_section(read("requirements/USE_CASES.md"), "The diagrams are written in PlantUML", "---"), 3,
              "Use Case Diagram and Specifications", drop=("Related documents:", "The Word copies", "---"))

install = """# 6. Installation and Running the Project

## 6.1 Requirements

Python 3.11+, MySQL 8 (WAMP or MySQL Server), Flutter 3 SDK with Android Studio or a phone,
Node.js 18+ (only to change the web admin), Git.

## 6.2 Backend and database

```
cd backend
python -m venv .venv
.venv\\Scripts\\activate            (macOS/Linux: source .venv/bin/activate)
pip install -r requirements.txt
copy .env.example .env              (then set the MySQL URL and the keys in .env)
mysql -u root -p -e "CREATE DATABASE ecommerce_db CHARACTER SET utf8mb4"
flask --app run init-db             (creates the 16 tables, InnoDB with foreign keys)
flask --app run seed                (categories, series, 35 products, demo accounts)
python run.py                       (http://localhost:5000/api/health)
```

The database can also be created by running `docs/database/schema.sql` in MySQL Workbench or Navicat.
Online payments need `BAKONG_TOKEN`, `BAKONG_ACCOUNT_ID`, `PAYWAY_MERCHANT_ID` and `PAYWAY_API_KEY`
in `.env`; these keys are never committed to GitHub.

## 6.3 Mobile app

```
cd mobile
flutter pub get
flutter run
```

The app calls `http://10.0.2.2:5000/api` (the Android emulator's address for the computer). On a real
phone, set `baseUrl` in `mobile/lib/core/constants/api_constants.dart` to the computer's Wi-Fi IP.

## 6.4 Web admin

The built web admin is served by the backend at <http://localhost:5000/dashboard> (log in with an
admin or staff account). To change it: `cd web-admin`, `npm install`, `npm run dev`, then
`npm run build` to update the copy the backend serves.

| Address | What |
|---|---|
| http://localhost:5000/dashboard | Web admin (React) |
| http://localhost:5000/admin | Admin panel (Flask-Admin) |
| http://localhost:5000/api/docs | API documentation (Swagger UI) |
"""

bonus = """# 7. Bonus Features

All five bonus features in the brief are done.

| Bonus feature | What was built | Where |
|---|---|---|
| Online payment integration | Bakong KHQR (any Cambodian bank app) and ABA PayWay (KHQR + Open ABA Mobile), with automatic payment detection, a 15-minute countdown and a printed receipt; cash on delivery too | KHQR / ABA PayWay Payment screen; `/api/orders/<id>/khqr`, `/api/orders/<id>/payway` |
| Multi-language support | English and Khmer, switched in Settings and remembered | `mobile/lib/l10n/*.arb` |
| Dark mode | Light, Dark or System theme in the app and the web admin, with a circle reveal animation | Settings; web admin sidebar |
| Product reviews and ratings | Star rating, tags and a comment for delivered products; average rating and a full Reviews page | Product Details, Reviews, Rate sheet |
| Advanced search and filtering | Live suggestions while typing, filters by category, series, brand, price range and stock, sorting, grid / list view | Search, Product List, Filter sheet |

Extra work beyond the brief: a staff role with owner-only staff management, a React web admin,
live activity on the admin dashboard, promo codes, notifications and contact messages.
"""

testing = """# 8. Testing

Automated tests run before every merge into `main`:

| Part | Tool | Tests | What they cover |
|---|---|---|---|
| Backend API | pytest | 138 | Every route: login and roles, catalogue, cart, checkout, KHQR and PayWay payments, admin and staff rules, validation, API docs up to date |
| Mobile app | flutter_test | 187 | Every screen's main flows with fake services (login, cart, checkout, payment, orders, admin tabs, staff) |
| Web admin | Vitest + Testing Library | 13 | Dashboard, order steps, staff page, theme switch |

`flutter analyze` reports no issues. The test folders (`backend/tests`, `web-admin/src/test`) are kept on
the `store-info` branch of the repository.

The payment flows were also tried for real: a Bakong KHQR payment from a bank app was detected and the
order marked paid, and ABA PayWay sandbox purchases return a working QR and ABA Mobile link.
"""

deliverables = f"""# 9. Project Deliverables Checklist

| Deliverable (from the brief) | Where |
|---|---|
| Flutter mobile application source code | `mobile/` in {REPO} |
| Backend system source code | `backend/` (Flask API) and `web-admin/` (React web admin) |
| Database design and ER diagram | Chapter 4; `docs/database/` (erd-diagram.png / .pdf, erd.png / .pdf, schema.sql) |
| Complete project documentation | This document; `docs/requirements/`, `docs/API.md`, `README.md` |
| GitHub repository | {REPO} |
| Project demonstration video | (link to be added) |
"""

appendix = "# Appendix A. Database Schema (SQL)\n\n```sql\n" + read("database/schema.sql").strip() + "\n```\n"

parts = [cover, overview, reqs, ucs, erd_ch, api_ch, install, bonus, testing, deliverables, appendix]
md = ("\n" + PAGE_BREAK + "\n").join(parts[:1]) + "\n".join(p if i == 0 else PAGE_BREAK + p for i, p in enumerate(parts[1:]))
src = DOCS / "PROJECT_DOCUMENTATION.md"
src.write_text(md, encoding="utf-8")

out = DOCS / "PROJECT_DOCUMENTATION.docx"
pypandoc.convert_file(str(src), "docx", outputfile=str(out),
                      extra_args=[f"--resource-path={DOCS}{';' if sys.platform == 'win32' else ':'}{DOCS / 'requirements'}",
                                  "--from=markdown+pipe_tables+raw_attribute-tex_math_dollars-auto_identifiers-raw_html"])
polish(out)
print("wrote", src.name, "and", out.name)
