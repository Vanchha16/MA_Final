"""Data flow diagrams (Yourdon/DeMarco notation) for Anime World Shop.

Writes dfd-level-0.svg (context diagram) and dfd-level-1.svg next to this file.
Circles are processes, rectangles are outside parties (external entities),
open boxes are data stores. A rectangle with a corner stroke is a copy of an
entity drawn twice to keep the lines short.

Usage:  python make_dfd.py
PNG:    chrome --headless --screenshot=dfd-level-1.png --window-size=1900,1400 dfd-level-1.svg
"""
from pathlib import Path

HERE = Path(__file__).parent
BLUE, INK, MUTED, LINE = "#0284C7", "#0F172A", "#475569", "#64748B"
FONT = "Roboto, Arial, sans-serif"


class Svg:
    def __init__(self, w, h, title):
        self.w, self.h, self.parts = w, h, []
        self.text(w / 2, 46, title, size=26, weight="bold", color=INK)

    def text(self, x, y, label, size=15, weight="normal", color=MUTED, anchor="middle", halo=False):
        lines = label.split("\n")
        y0 = y - (len(lines) - 1) * size * 0.6
        halo_attr = ' stroke="#FFFFFF" stroke-width="5" paint-order="stroke"' if halo else ""
        spans = "".join(f'<tspan x="{x}" y="{y0 + i * size * 1.2:.0f}">{line}</tspan>' for i, line in enumerate(lines))
        self.parts.append(f'<text font-family="{FONT}" font-size="{size}" font-weight="{weight}" fill="{color}" '
                          f'text-anchor="{anchor}"{halo_attr}>{spans}</text>')

    def entity(self, x, y, w, h, label, copy=False):
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#E0F2FE" stroke="{BLUE}" stroke-width="2.5"/>')
        if copy:
            self.parts.append(f'<line x1="{x}" y1="{y + 18}" x2="{x + 18}" y2="{y}" stroke="{BLUE}" stroke-width="2.5"/>')
        self.text(x + w / 2, y + h / 2 + 6, label, size=18, weight="bold", color=INK)

    def process(self, cx, cy, r, number, label):
        self.parts.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#FFFFFF" stroke="{BLUE}" stroke-width="3"/>')
        self.text(cx, cy - r * 0.45, number, size=17, weight="bold", color=BLUE)
        self.text(cx, cy + 12, label, size=18, weight="bold", color=INK)

    def store(self, x, y, w, ident, label):
        h = 44
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#F8FAFC"/>')
        self.parts.append(f'<path d="M{x + w} {y} H{x} V{y + h} H{x + w}" fill="none" stroke="{INK}" stroke-width="2"/>')
        self.parts.append(f'<line x1="{x + 56}" y1="{y}" x2="{x + 56}" y2="{y + h}" stroke="{INK}" stroke-width="2"/>')
        self.text(x + 28, y + 28, ident, size=16, weight="bold", color=BLUE)
        self.text(x + 68, y + 28, label, size=16, weight="bold", color=INK, anchor="start")

    def flow(self, points, label="", at=None, both=False, anchor="middle"):
        d = "M" + " L".join(f"{x} {y}" for x, y in points)
        start = ' marker-start="url(#head)"' if both else ""
        self.parts.append(f'<path d="{d}" fill="none" stroke="{LINE}" stroke-width="2"{start} marker-end="url(#head)"/>')
        if label:
            if at is None:
                (x1, y1), (x2, y2) = points[0], points[-1]
                at = ((x1 + x2) / 2, (y1 + y2) / 2)
            self.text(at[0], at[1], label, size=15, anchor=anchor, halo=True)

    def save(self, name):
        head = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}">'
                f'<defs><marker id="head" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="9" markerHeight="9" orient="auto-start-reverse">'
                f'<path d="M0 0 L10 5 L0 10 z" fill="{LINE}"/></marker></defs>'
                f'<rect width="{self.w}" height="{self.h}" fill="#FFFFFF"/>')
        (HERE / name).write_text(head + "".join(self.parts) + "</svg>\n", encoding="utf-8")


def level_0():
    s = Svg(1600, 1000, "Anime World Shop - Data Flow Diagram, Level 0 (context)")
    s.process(800, 500, 150, "0", "Anime World Shop\nsystem")
    s.entity(80, 440, 240, 110, "Customer")
    s.entity(680, 90, 240, 90, "Staff")
    s.entity(1260, 180, 240, 100, "Owner (admin)")
    s.entity(1260, 600, 260, 110, "Bakong KHQR /\nABA PayWay")
    s.entity(680, 860, 240, 90, "Email service")
    # Customer
    s.flow([(320, 470), (653, 470)], "account details, searches,\ncart items, orders, reviews", at=(486, 430))
    s.flow([(653, 530), (320, 530)], "products and prices, QR codes,\norder status, notifications, receipts", at=(486, 578))
    # Staff
    s.flow([(770, 180), (770, 353)], "products, stock,\norder steps, replies", at=(760, 262), anchor="end")
    s.flow([(830, 353), (830, 180)], "orders to handle,\nmessages, dashboard", at=(840, 262), anchor="start")
    # Owner
    s.flow([(1260, 215), (930, 400)], "staff accounts, promo codes,\npayment methods on/off", at=(1070, 222))
    s.flow([(948, 432), (1260, 265)], "sales and reports", at=(1140, 375))
    # Bank
    s.flow([(948, 525), (1260, 625)], "QR request\n(order number, amount)", at=(1100, 535))
    s.flow([(1260, 690), (940, 568)], "payment confirmation", at=(1070, 676))
    # Email
    s.flow([(800, 650), (800, 860)], "password reset code", at=(812, 760), anchor="start")
    s.flow([(680, 905), (200, 905), (200, 550)], "6-digit code by email", at=(440, 890))
    s.save("dfd-level-0.svg")


def level_1():
    s = Svg(1900, 1420, "Anime World Shop - Data Flow Diagram, Level 1")
    r = 95
    # outside parties (Customer drawn twice: left for shopping, right for payment and tracking)
    s.entity(40, 70, 200, 80, "Email service")
    s.entity(40, 610, 200, 90, "Customer")
    s.entity(1680, 250, 200, 90, "Staff / Owner")
    s.entity(1680, 710, 200, 90, "Customer", copy=True)
    s.entity(1680, 1100, 200, 100, "Bakong /\nABA PayWay")
    # processes
    s.process(520, 180, r, "1.0", "Manage\naccounts")
    s.process(520, 500, r, "2.0", "Browse\nproducts")
    s.process(520, 820, r, "3.0", "Cart and\nwishlist")
    s.process(520, 1150, r, "4.0", "Place\norder")
    s.process(1420, 300, r, "7.0", "Run the\nshop")
    s.process(1420, 760, r, "6.0", "Track and\nnotify")
    s.process(1420, 1150, r, "5.0", "Pay for\norder")
    # data stores
    s.store(820, 158, 300, "D1", "Users")
    s.store(820, 478, 300, "D2", "Products")
    s.store(820, 798, 300, "D3", "Cart and favorites")
    s.store(820, 990, 300, "D4", "Orders")
    s.store(820, 1290, 300, "D7", "Coupons, payment methods")
    s.store(1290, 1310, 260, "D5", "Payments")
    s.store(1640, 545, 240, "D6", "Notifications")
    # 1.0 accounts
    s.flow([(240, 640), (440, 230)], "login, register,\nreset request", at=(300, 420))
    s.flow([(615, 180), (820, 180)], "user record", at=(718, 150), both=True)
    s.flow([(430, 150), (240, 110)], "reset code", at=(335, 112))
    s.flow([(140, 150), (140, 610)], "code", at=(150, 380), anchor="start")
    # 2.0 browse
    s.flow([(240, 645), (430, 530)], "search, filters", at=(345, 568))
    s.flow([(430, 565), (240, 665)], "products, prices", at=(365, 648))
    s.flow([(820, 500), (615, 500)], "product data", at=(718, 470))
    # 3.0 cart
    s.flow([(240, 680), (435, 790)], "add, update,\nremove", at=(318, 768))
    s.flow([(615, 820), (820, 820)], "cart lines", at=(718, 790), both=True)
    # 4.0 order
    s.flow([(200, 700), (200, 1150), (425, 1150)], "address,\npayment choice", at=(310, 1125))
    s.flow([(900, 842), (590, 1085)], "cart items", at=(760, 930))
    s.flow([(600, 1100), (980, 522)], "stock taken", at=(870, 690))
    s.flow([(615, 1130), (820, 1012)], "new order", at=(700, 1040))
    s.flow([(820, 1300), (600, 1200)], "promo code,\nmethods that are on", at=(700, 1290))
    s.flow([(615, 1160), (1325, 1160)], "order to pay", at=(980, 1185))
    # 5.0 pay
    s.flow([(1515, 1135), (1680, 1135)], "QR request", at=(1598, 1110))
    s.flow([(1680, 1175), (1515, 1175)], "payment\nconfirmation", at=(1598, 1222))
    s.flow([(1420, 1245), (1420, 1310)], "payment record", at=(1432, 1280), anchor="start", both=True)
    s.flow([(1340, 1105), (1120, 1028)], "mark paid", at=(1240, 1095))
    s.flow([(1490, 1085), (1720, 800)], "QR code,\npayment status", at=(1640, 960))
    # 6.0 track and notify
    s.flow([(1120, 1000), (1335, 800)], "order status", at=(1215, 880))
    s.flow([(1490, 695), (1680, 589)], "new notification", at=(1580, 615))
    s.flow([(1760, 589), (1760, 710)], "notification list", at=(1772, 650), anchor="start")
    s.flow([(1515, 770), (1680, 770)], "order tracker", at=(1598, 745))
    # 7.0 run the shop
    s.flow([(1680, 275), (1515, 275)], "products, stock, order steps,\nstaff, promos, payment methods", at=(1598, 222))
    s.flow([(1515, 320), (1680, 320)], "orders, messages,\ndashboard", at=(1598, 360))
    s.flow([(1325, 250), (1120, 180)], "staff accounts", at=(1225, 195))
    s.flow([(1328, 330), (1120, 490)], "product and\nstock changes", at=(1230, 390))
    s.flow([(1345, 360), (1120, 995)], "order steps", at=(1255, 640))
    s.flow([(1375, 385), (1120, 1295)], "promo codes,\npayment methods", at=(1180, 1130))
    s.save("dfd-level-1.svg")


if __name__ == "__main__":
    level_0()
    level_1()
