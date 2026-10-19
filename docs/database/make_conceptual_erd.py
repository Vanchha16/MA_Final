"""Draws the conceptual ER diagram (Chen notation: entities, relationship diamonds,
attribute ovals) for Anime World Shop as conceptual-erd.svg/html next to this script.

Run:  python docs/database/make_conceptual_erd.py
Then export conceptual-erd.html from Chrome (headless --screenshot / --print-to-pdf).
"""
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
WIDTH, HEIGHT = 1800, 1400

TEAL, NAVY, CRIMSON = "#00AFC8", "#005A80", "#BF124F"
EW, EH = 160, 58      # entity
DW, DH = 150, 80      # relationship diamond
AW, AH = 124, 52      # attribute oval

ENTITIES = {
    "Customer": (480, 470), "Address": (110, 470), "Shopping Cart": (150, 790),
    "Order": (1000, 470), "Payment": (1490, 660), "Coupon": (1490, 470),
    "Product": (1000, 1070), "Category": (1490, 1070), "Series": (1490, 880), "Product Image": (1000, 1300),
}
# name: (centre, entity A, marker at A, entity B, marker at B)
# markers: one, zero_one, many, zero_many, one_many
RELATIONS = {
    "Has": ((295, 470), "Customer", "one", "Address", "zero_many"),
    "Places": ((740, 470), "Customer", "one", "Order", "zero_many"),
    "Paid by": ((1250, 600), "Order", "one", "Payment", "zero_many"),
    "Uses": ((1250, 470), "Order", "zero_many", "Coupon", "zero_one"),
    "Contains": ((1000, 780), "Order", "zero_many", "Product", "one_many"),
    "Owns": ((310, 630), "Customer", "one", "Shopping Cart", "one"),
    "Holds": ((330, 1070), "Shopping Cart", "zero_many", "Product", "zero_many"),
    "Saves\n(wishlist)": ((730, 780), "Customer", "zero_many", "Product", "zero_many"),
    "Reviews": ((480, 780), "Customer", "zero_many", "Product", "zero_many"),
    "Belongs to": ((1250, 1070), "Product", "zero_many", "Category", "one"),
    "Part of": ((1250, 960), "Product", "zero_many", "Series", "zero_one"),
    "Has photos": ((1000, 1190), "Product", "one", "Product Image", "zero_many"),
}
# attribute: (centre, owner)  owner = entity or relationship
ATTRS = [
    ("Name", (350, 345), "Customer"), ("E-mail", (480, 325), "Customer"), ("Phone", (610, 345), "Customer"),
    ("Street", (70, 350), "Address"), ("City", (195, 345), "Address"),
    ("Order\nNumber", (850, 350), "Order"), ("Status", (1000, 330), "Order"), ("Total", (1150, 350), "Order"),
    ("Method", (1665, 590), "Payment"), ("Amount", (1690, 665), "Payment"), ("Status", (1640, 745), "Payment"),
    ("Code", (1490, 355), "Coupon"), ("Discount", (1665, 420), "Coupon"),
    ("Quantity", (1165, 745), "Contains"), ("Unit Price", (1165, 825), "Contains"),
    ("Rating", (330, 880), "Reviews"), ("Comment", (380, 950), "Reviews"),
    ("Quantity", (330, 1180), "Holds"),
    ("Name", (780, 1180), "Product"), ("Price", (1210, 1175), "Product"), ("Stock", (800, 1260), "Product"),
    ("Name", (1665, 1070), "Category"), ("Name", (1665, 880), "Series"), ("Image", (1195, 1300), "Product Image"),
]


def centre(name):
    return ENTITIES[name] if name in ENTITIES else RELATIONS[name][0]


def clip(c, toward, shape):
    """Point where the line from c toward `toward` leaves the shape around c."""
    (x, y), (tx, ty) = c, toward
    dx, dy = tx - x, ty - y
    d = math.hypot(dx, dy) or 1
    ux, uy = dx / d, dy / d
    if shape == "rect":
        t = min((EW / 2) / abs(ux) if ux else 1e9, (EH / 2) / abs(uy) if uy else 1e9)
    elif shape == "diamond":
        t = 1 / (abs(ux) / (DW / 2) + abs(uy) / (DH / 2))
    else:
        t = 1 / math.sqrt((ux / (AW / 2)) ** 2 + (uy / (AH / 2)) ** 2)
    return x + ux * t, y + uy * t, ux, uy


def marker(x, y, ux, uy, kind):
    """Cardinality mark at the entity end (x, y); (ux, uy) points away from the entity."""
    nx, ny = -uy, ux
    out = []

    def bar(k):
        out.append(f'<path d="M{x+ux*k+nx*7:.1f} {y+uy*k+ny*7:.1f} L{x+ux*k-nx*7:.1f} {y+uy*k-ny*7:.1f}" class="ln"/>')

    def crow():
        out.append(f'<path d="M{x+nx*8:.1f} {y+ny*8:.1f} L{x+ux*13:.1f} {y+uy*13:.1f} L{x-nx*8:.1f} {y-ny*8:.1f}" class="ln"/>')

    def ring(k):
        out.append(f'<circle cx="{x+ux*k:.1f}" cy="{y+uy*k:.1f}" r="4.2" class="ring"/>')

    if kind == "one":
        bar(9); bar(14)
    elif kind == "zero_one":
        bar(9); ring(19)
    elif kind == "many":
        crow()
    elif kind == "zero_many":
        crow(); ring(19)
    elif kind == "one_many":
        crow(); bar(17)
    return "".join(out)


def text(x, y, label, size, weight=500, color="#fff"):
    lines = label.split("\n")
    first = y - (len(lines) - 1) * size * 0.6 + size * 0.35
    return "".join(f'<text x="{x}" y="{first + i*size*1.2:.1f}" font-size="{size}" font-weight="{weight}" fill="{color}" text-anchor="middle">{s}</text>'
                   for i, s in enumerate(lines))


lines_svg, shapes = [], []
for rel, (c, a, ma, b, mb) in RELATIONS.items():
    for ent, mk in ((a, ma), (b, mb)):
        ex, ey, ux, uy = clip(ENTITIES[ent], c, "rect")
        dx, dy, _, _ = clip(c, ENTITIES[ent], "diamond")
        lines_svg.append(f'<path d="M{ex:.1f} {ey:.1f} L{dx:.1f} {dy:.1f}" class="ln"/>' + marker(ex, ey, ux, uy, mk))
for label, c, owner in ATTRS:
    oc = centre(owner)
    sx, sy, _, _ = clip(oc, c, "rect" if owner in ENTITIES else "diamond")
    ax, ay, _, _ = clip(c, oc, "oval")
    lines_svg.append(f'<path d="M{sx:.1f} {sy:.1f} L{ax:.1f} {ay:.1f}" class="ln"/>')
    shapes.append(f'<ellipse cx="{c[0]}" cy="{c[1]}" rx="{AW/2}" ry="{AH/2}" fill="{CRIMSON}"/>' + text(c[0], c[1], label, 13.5))
for rel, (c, *_rest) in RELATIONS.items():
    x, y = c
    shapes.append(f'<path d="M{x} {y-DH/2} L{x+DW/2} {y} L{x} {y+DH/2} L{x-DW/2} {y} Z" fill="{NAVY}"/>' + text(x, y, rel, 14))
for ent, (x, y) in ENTITIES.items():
    shapes.append(f'<rect x="{x-EW/2}" y="{y-EH/2}" width="{EW}" height="{EH}" fill="{TEAL}"/>' + text(x, y, ent, 18.5, 500))

# Legend (like the reference picture)
lx, ly = 40, 105
legend = [f'<rect x="{lx}" y="{ly}" width="1110" height="140" rx="12" fill="#fff" stroke="#c7ccd1" stroke-width="1.5"/>',
          f'<rect x="{lx+40}" y="{ly+40}" width="120" height="58" fill="{TEAL}"/>' + text(lx + 100, ly + 69, "Entity", 15),
          f'<path d="M{lx+260} {ly+30} L{lx+330} {ly+69} L{lx+260} {ly+108} L{lx+190} {ly+69} Z" fill="{NAVY}"/>' + text(lx + 260, ly + 69, "Relationship", 13.5),
          f'<ellipse cx="{lx+425}" cy="{ly+69}" rx="62" ry="29" fill="{CRIMSON}"/>' + text(lx + 425, ly + 69, "Attribute", 14)]
for i, (kind, words) in enumerate([("one", "= One (exactly one)"), ("zero_one", "= Zero or one, optional"),
                                   ("one_many", "= One or more"), ("zero_many", "= Zero or more, optional")]):
    x0, y0 = lx + 540 + (i // 2) * 230, ly + 45 + (i % 2) * 50
    legend.append(f'<path d="M{x0} {y0} H{x0+60}" class="ln"/>' + marker(x0, y0, 1, 0, kind)
                  + f'<text x="{x0+72}" y="{y0+5}" font-size="15" fill="#333">{words}</text>')

doc = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}" font-family="Roboto, Arial, sans-serif">
<style>.ln{{fill:none;stroke:#555;stroke-width:1.4}} .ring{{fill:#fff;stroke:#555;stroke-width:1.4}}</style>
<rect width="100%" height="100%" fill="#fff"/>
<text x="{WIDTH/2}" y="62" font-size="32" fill="#333" text-anchor="middle">Entity Relationship Diagram - Anime World Shop</text>
{''.join(legend)}
{''.join(lines_svg)}
{''.join(shapes)}
</svg>"""
open(os.path.join(HERE, "conceptual-erd.svg"), "w", encoding="utf-8").write(doc)
open(os.path.join(HERE, "conceptual-erd.html"), "w", encoding="utf-8").write(
    '<!doctype html><html><head><meta charset="utf-8"><link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500&display=swap" rel="stylesheet">'
    f'<style>@page{{size:{WIDTH}px {HEIGHT}px;margin:0}}html,body{{margin:0}}svg{{display:block}}</style></head><body>{doc}</body></html>')
print("ok")
