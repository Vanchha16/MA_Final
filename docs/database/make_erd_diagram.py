"""Draws a Navicat-style ER diagram (blue table boxes, key icons, crow's-foot lines with
fk labels) from the live ecommerce_db, as erd-diagram.svg/html next to this script.

Run with WAMP's MySQL started:  python docs/database/make_erd_diagram.py
Then export erd-diagram.html from Chrome (headless --screenshot / --print-to-pdf) for the PNG and PDF.
Box positions and line routes are set by hand below (POS, ROUTES, LABELS); a new table or
foreign key needs an entry there.
"""
import html
import os
import re
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
MYSQL = "C:/wamp64/bin/mysql/mysql8.4.7/bin/mysql.exe"


def q(sql):
    out = subprocess.run([MYSQL, "-u", "root", "-N", "-B", "-e", sql], capture_output=True, text=True, check=True).stdout
    return [line.split("\t") for line in out.strip().splitlines()]


cols = {}
for t, c, typ, key, null in q("SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, COLUMN_KEY, IS_NULLABLE FROM information_schema.COLUMNS "
                               "WHERE TABLE_SCHEMA='ecommerce_db' ORDER BY TABLE_NAME, ORDINAL_POSITION"):
    typ = "enum" if typ.startswith("enum") else re.sub(r"decimal\((\d+),(\d+)\)", r"decimal(\1, \2)", typ)
    cols.setdefault(t, []).append((c, typ, key, null == "YES"))
fks = {(t, c): (name, p) for name, t, c, p in q(
    "SELECT CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME FROM information_schema.KEY_COLUMN_USAGE "
    "WHERE TABLE_SCHEMA='ecommerce_db' AND REFERENCED_TABLE_NAME IS NOT NULL")}

W, HEAD, ROW, PAD = 236, 30, 19, 10
XA, XB, XC, XD, XE = 30, 470, 906, 1340, 1800

POS = {
    "coupons": (XA, 40), "contact_messages": (XA, 300), "addresses": (XA, 640), "password_resets": (XA, 960),
    "orders": (XB, 40), "users": (XB, 640),
    "payments": (XC, 40), "notifications": (XC, 380), "cart_items": (XC, 640), "favorites": (XC, 820), "reviews": (XC, 990),
    "order_items": (XD, 300), "products": (XD, 640),
    "categories": (XE, 640), "series": (XE, 820), "product_images": (XE, 990),
}


def bottom(t):
    return POS[t][1] + HEAD + len(cols[t]) * ROW + PAD


def ry(t, column):
    return POS[t][1] + HEAD + [c[0] for c in cols[t]].index(column) * ROW + ROW / 2


def L(t):
    return POS[t][0]


def R(t):
    return POS[t][0] + W


A_R, B_R, C_R, D_R = XA + W, XB + W, XC + W, XD + W

# child column -> points from the child's edge to the parent's edge (right angles only)
ROUTES = {
    ("contact_messages", "order_id"): [(A_R, ry("contact_messages", "order_id")), (XB, ry("contact_messages", "order_id"))],
    ("contact_messages", "user_id"): [(A_R - 30, bottom("contact_messages")), (A_R - 30, 570), (A_R + 50, 570), (A_R + 50, 665), (XB, 665)],
    ("addresses", "user_id"): [(A_R, ry("addresses", "user_id")), (XB, ry("addresses", "user_id"))],
    ("password_resets", "user_id"): [(A_R, ry("password_resets", "user_id")), (A_R + 90, ry("password_resets", "user_id")), (A_R + 90, 920), (XB, 920)],
    ("orders", "user_id"): [(XB + W / 2, bottom("orders")), (XB + W / 2, 640)],
    ("payments", "order_id"): [(XC, ry("payments", "order_id")), (B_R, ry("payments", "order_id"))],
    ("notifications", "order_id"): [(XC, ry("notifications", "order_id")), (XC - 40, ry("notifications", "order_id")), (XC - 40, 400), (B_R, 400)],
    ("notifications", "user_id"): [(XC + 30, bottom("notifications")), (XC + 30, 622), (XC - 66, 622), (XC - 66, 656), (B_R, 656)],
    ("order_items", "order_id"): [(XD, ry("order_items", "order_id")), (B_R, ry("order_items", "order_id"))],
    ("order_items", "product_id"): [(XD + W / 2, bottom("order_items")), (XD + W / 2, 640)],
    ("cart_items", "user_id"): [(XC, ry("cart_items", "user_id")), (B_R, ry("cart_items", "user_id"))],
    ("cart_items", "product_id"): [(C_R, ry("cart_items", "product_id")), (XD, ry("cart_items", "product_id"))],
    ("favorites", "user_id"): [(XC, ry("favorites", "user_id")), (B_R, ry("favorites", "user_id"))],
    ("favorites", "product_id"): [(C_R, ry("favorites", "product_id")), (XD, ry("favorites", "product_id"))],
    ("reviews", "user_id"): [(XC, ry("reviews", "user_id")), (XC - 60, ry("reviews", "user_id")), (XC - 60, 940), (B_R, 940)],
    ("reviews", "product_id"): [(C_R, ry("reviews", "product_id")), (XD - 60, ry("reviews", "product_id")), (XD - 60, 930), (XD, 930)],
    ("products", "category_id"): [(D_R, ry("products", "category_id")), (XE, ry("products", "category_id"))],
    ("products", "series_id"): [(D_R, ry("products", "series_id")), (XE - 60, ry("products", "series_id")), (XE - 60, 870), (XE, 870)],
    ("product_images", "product_id"): [(XE, ry("product_images", "product_id")), (XE - 80, ry("product_images", "product_id")), (XE - 80, 930), (D_R, 930)],
}
assert set(ROUTES) == set(fks), set(fks) ^ set(ROUTES)

# Labels that don't fit on their line: (x, y, anchor) in empty space next to it
LABELS = {
    ("contact_messages", "user_id"): (XA + 6, 548, "start"),
    ("password_resets", "user_id"): (A_R + 98, 990, "start"),
    ("notifications", "user_id"): (B_R + 6, 612, "start"),
    ("products", "series_id"): (XE - 52, 811, "start"),
    ("product_images", "product_id"): (XE - 86, 978, "end"),
}


def unit(a, b):
    return ((b[0] > a[0]) - (b[0] < a[0]), (b[1] > a[1]) - (b[1] < a[1]))


def many(p, d):
    """Crow's foot + circle (zero or many) at p; d points along the line, away from the box."""
    (x, y), (dx, dy) = p, d
    nx, ny = -dy, dx  # sideways
    return (f'<path d="M{x+6*nx} {y+6*ny} L{x+12*dx} {y+12*dy} L{x-6*nx} {y-6*ny} M{x} {y} L{x+12*dx} {y+12*dy}" class="ln"/>'
            f'<circle cx="{x+17*dx}" cy="{y+17*dy}" r="3.6" class="dot"/>')


def one(p, d, optional):
    """One (two bars) or zero-or-one (bar + circle) at p."""
    (x, y), (dx, dy) = p, d
    nx, ny = -dy, dx
    bar = lambda k: f'<path d="M{x+k*dx+6*nx} {y+k*dy+6*ny} L{x+k*dx-6*nx} {y+k*dy-6*ny}" class="ln"/>'
    return bar(6) + (f'<circle cx="{x+14*dx}" cy="{y+14*dy}" r="3.6" class="dot"/>' if optional else bar(11))


LINK = "M0 4 l3 -3 a2.4 2.4 0 0 1 3.4 3.4 l-3 3 M7 -1 l3 -3 a2.4 2.4 0 0 1 3.4 3.4 l-3 3 M4 3 l4 -4"

lines = []
for (child, column), pts in ROUTES.items():
    name, parent = fks[(child, column)]
    nullable = next(c[3] for c in cols[child] if c[0] == column)
    path = "M" + " L".join(f"{x} {y}" for x, y in pts)
    lines.append(f'<path d="{path}" class="ln"/>')
    lines.append(many(pts[0], unit(pts[0], pts[1])))
    lines.append(one(pts[-1], unit(pts[-1], pts[-2]), nullable))
    # label: centred above the longest horizontal piece (or beside a straight vertical line)
    segs = [(a, b) for a, b in zip(pts, pts[1:]) if a[1] == b[1]]
    tw = len(name) * 6.0 + 16
    if (child, column) in LABELS:
        lx, ly, anchor = LABELS[(child, column)]
        if anchor == "end":
            lx -= tw
    elif segs:
        a, b = max(segs, key=lambda s: abs(s[1][0] - s[0][0]))
        lx, ly = (a[0] + b[0]) / 2 - tw / 2, a[1] - 7
    else:
        (a, b) = pts[0], pts[-1]
        lx, ly = a[0] + 12, (a[1] + b[1]) / 2 + 4
    lines.append(f'<g class="lbl"><path transform="translate({lx} {ly-8})" d="{LINK}" class="link"/>'
                 f'<text x="{lx+16}" y="{ly}">{name}</text></g>')

boxes = []
for t, (x, y) in POS.items():
    y1 = bottom(t)
    parts = [f'<rect x="{x}" y="{y}" width="{W}" height="{y1-y}" rx="7" class="box"/>',
             f'<path d="M{x} {y+HEAD} V{y+7} a7 7 0 0 1 7 -7 H{x+W-7} a7 7 0 0 1 7 7 V{y+HEAD} Z" class="head"/>',
             f'<text x="{x+W/2}" y="{y+20}" class="title">{t}</text>']
    for i, (c, typ, key, _) in enumerate(cols[t]):
        cy = y + HEAD + i * ROW + ROW / 2
        if key == "PRI":
            parts.append(f'<g transform="translate({x+10} {cy-7})"><circle cx="4.5" cy="4.5" r="4" class="key"/><path d="M7.5 7 L14 13.5 M11 10.5 l-2 2 M13 12.5 l-2 2" class="keyl"/></g>')
        elif key in ("UNI", "MUL"):
            parts.append(f'<path d="M{x+15} {cy-4.5} l4.5 4.5 l-4.5 4.5 l-4.5 -4.5 z" class="idx"/>')
        parts.append(f'<text x="{x+30}" y="{cy+4.5}" class="col">{html.escape(c)}<tspan class="typ"> : {html.escape(typ)}</tspan></text>')
    boxes.append("".join(parts))

WIDTH, HEIGHT = XE + W + 40, 1230
legend_x, legend_y = XD, 60
doc = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">
<style>
 .box{{fill:#fff;stroke:#3a7fc1;stroke-width:1.6}}
 .head{{fill:#3a7fc1}}
 .title{{font:700 14px Roboto,Arial,sans-serif;fill:#fff;text-anchor:middle}}
 .col{{font:500 12.5px Roboto,Arial,sans-serif;fill:#1f2937}}
 .typ{{font-weight:400;fill:#9aa3ae}}
 .ln{{fill:none;stroke:#4b5563;stroke-width:1.3}}
 .dot{{fill:#fff;stroke:#4b5563;stroke-width:1.3}}
 .key{{fill:#f5b301;stroke:#c98a00;stroke-width:1}}
 .keyl{{fill:none;stroke:#c98a00;stroke-width:2;stroke-linecap:round}}
 .idx{{fill:#fff;stroke:#8b95a1;stroke-width:1.2}}
 .lbl text{{font:12px Roboto,Arial,sans-serif;fill:#374151;paint-order:stroke;stroke:#fff;stroke-width:4px;stroke-linejoin:round}}
 .link{{fill:none;stroke:#6b7280;stroke-width:1.2;stroke-linecap:round}}
 .ttl{{font:800 26px Roboto,Arial,sans-serif;fill:#0f172a}}
 .sub{{font:14px Roboto,Arial,sans-serif;fill:#64748b}}
 .leg{{font:13px Roboto,Arial,sans-serif;fill:#374151}}
</style>
<rect width="100%" height="100%" fill="#ffffff"/>
<text x="{legend_x}" y="{legend_y+10}" class="ttl">Anime World Shop - ER Diagram</text>
<text x="{legend_x}" y="{legend_y+36}" class="sub">MySQL database ecommerce_db (InnoDB) · 16 tables · 19 foreign keys</text>
<g transform="translate({legend_x} {legend_y+66})">
 <g transform="translate(0 -9)"><circle cx="4.5" cy="4.5" r="4" class="key"/><path d="M7.5 7 L14 13.5 M11 10.5 l-2 2 M13 12.5 l-2 2" class="keyl"/></g>
 <text x="22" y="4" class="leg">primary key</text>
 <path d="M135 -4.5 l4.5 4.5 l-4.5 4.5 l-4.5 -4.5 z" class="idx"/><text x="148" y="4" class="leg">foreign key / unique / index</text>
 <path d="M0 30 H60" class="ln"/>{one((60, 30), (-1, 0), False)}{many((0, 30), (1, 0))}<text x="72" y="34" class="leg">one to many (required)</text>
 <path d="M260 30 H320" class="ln"/>{one((320, 30), (-1, 0), True)}{many((260, 30), (1, 0))}<text x="332" y="34" class="leg">zero-or-one to many (optional)</text>
</g>
{''.join(lines)}
{''.join(boxes)}
</svg>"""
open(os.path.join(HERE, "erd-diagram.svg"), "w", encoding="utf-8").write(doc)
open(os.path.join(HERE, "erd-diagram.html"), "w", encoding="utf-8").write(
    '<!doctype html><html><head><meta charset="utf-8"><link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700;800&display=swap" rel="stylesheet">'
    f'<style>@page{{size:{WIDTH}px {HEIGHT}px;margin:0}}html,body{{margin:0}}svg{{display:block}}</style></head><body>{doc}</body></html>')
print("ok", WIDTH, HEIGHT, {t: bottom(t) for t in POS})
