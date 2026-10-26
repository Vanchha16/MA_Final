"""Data flow diagrams (Yourdon/DeMarco notation) for Anime World Shop.

Writes dfd-level-0.svg, dfd-level-1.svg and dfd-level-2.svg next to this file:
black lines on grid paper, rectangles for outside parties (external entities),
numbered circles for processes, open boxes for data stores. Lines only run
across or down, so every flow is a short path of straight legs.

Usage:  python make_dfd.py
PNG:    chrome --headless --screenshot=dfd-level-1.png --window-size=2000,940 dfd-level-1.svg
"""
from pathlib import Path

HERE = Path(__file__).parent
INK, LINE, LABEL = "#111111", "#333333", "#222222"
FONT = "Arial, Helvetica, sans-serif"


class Svg:
    def __init__(self, w, h):
        self.w, self.h, self.parts = w, h, []

    def text(self, x, y, label, size=15, weight="normal", anchor="middle", halo=True):
        lines = label.replace("&", "&amp;").split("\n")
        y0 = y - (len(lines) - 1) * size * 0.6
        halo_attr = ' stroke="#FFFFFF" stroke-width="6" paint-order="stroke"' if halo else ""
        spans = "".join(f'<tspan x="{x}" y="{y0 + i * size * 1.2:.0f}">{line}</tspan>' for i, line in enumerate(lines))
        self.parts.append(f'<text font-family="{FONT}" font-size="{size}" font-weight="{weight}" fill="{LABEL}" '
                          f'text-anchor="{anchor}" dominant-baseline="middle"{halo_attr}>{spans}</text>')

    def entity(self, x, y, w, h, label):
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="4" fill="#FFFFFF" stroke="{INK}" stroke-width="1.8"/>')
        self.text(x + w / 2, y + h / 2, label, size=18, halo=False)

    def process(self, cx, cy, r, number, label):
        self.parts.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#FFFFFF" stroke="{INK}" stroke-width="1.8"/>')
        self.text(cx, cy - r * 0.42, number, size=17, halo=False)
        self.text(cx, cy + 14, label, size=17, halo=False)

    def store(self, x, y, w, ident, label, h=44):
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#FFFFFF"/>')
        self.parts.append(f'<path d="M{x + w} {y} H{x} V{y + h} H{x + w}" fill="none" stroke="{INK}" stroke-width="1.8"/>')
        self.parts.append(f'<line x1="{x + 46}" y1="{y}" x2="{x + 46}" y2="{y + h}" stroke="{INK}" stroke-width="1.8"/>')
        self.text(x + 23, y + h / 2, ident, size=16, halo=False)
        self.text(x + 58, y + h / 2, label, size=17, anchor="start", halo=False)

    def flow(self, points, label="", at=None, anchor="middle", both=False):
        d = "M" + " L".join(f"{x} {y}" for x, y in points)
        start = ' marker-start="url(#head)"' if both else ""
        self.parts.append(f'<path d="{d}" fill="none" stroke="{LINE}" stroke-width="1.6" stroke-linejoin="round"{start} marker-end="url(#head)"/>')
        if label:
            self.text(at[0], at[1], label, size=15, anchor=anchor)

    def save(self, name):
        grid = ('<defs><pattern id="g" width="25" height="25" patternUnits="userSpaceOnUse">'
                '<path d="M25 0 H0 V25" fill="none" stroke="#E6E9EE" stroke-width="1"/></pattern>'
                '<pattern id="G" width="100" height="100" patternUnits="userSpaceOnUse">'
                '<rect width="100" height="100" fill="url(#g)"/><path d="M100 0 H0 V100" fill="none" stroke="#D5DAE1" stroke-width="1"/></pattern>'
                f'<marker id="head" viewBox="0 0 10 10" refX="9.5" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
                f'<path d="M0 0 L10 5 L0 10 z" fill="{LINE}"/></marker></defs>')
        head = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}">{grid}'
                f'<rect width="{self.w}" height="{self.h}" fill="#FFFFFF"/><rect width="{self.w}" height="{self.h}" fill="url(#G)"/>')
        (HERE / name).write_text(head + "".join(self.parts) + "</svg>\n", encoding="utf-8")


def level_0():
    """Context diagram: the whole shop is one process."""
    s = Svg(2000, 830)
    s.process(1000, 415, 120, "0", "Anime World\nShop System")
    s.entity(880, 40, 240, 80, "Customer")
    s.entity(120, 375, 260, 80, "Staff / Owner")
    s.entity(1620, 375, 260, 80, "Payment Gateway\n(Bakong / ABA)")
    s.entity(880, 710, 240, 80, "Email Service")
    # Customer (two lines at x 980 / 1020; the circle top is at y 296)
    s.flow([(980, 120), (980, 297)], "Login details, search,\ncart items, order, payment choice", at=(968, 208), anchor="end")
    s.flow([(1020, 297), (1020, 120)], "Products, order status,\nQR code, receipt, notifications", at=(1032, 208), anchor="start")
    # Staff / Owner
    s.flow([(380, 400), (881, 400)], "Products, stock, order steps, staff, promo codes, payment methods", at=(630, 380))
    s.flow([(881, 430), (380, 430)], "Orders to handle, messages, sales dashboard", at=(630, 452))
    # Payment gateway
    s.flow([(1119, 400), (1620, 400)], "QR request (order number, amount)", at=(1370, 380))
    s.flow([(1620, 430), (1119, 430)], "Payment status (paid / expired)", at=(1370, 452))
    # Email
    s.flow([(1000, 535), (1000, 710)], "Password reset code", at=(1012, 622), anchor="start")
    s.save("dfd-level-0.svg")


def level_1():
    """The six main functions and the seven data stores."""
    s = Svg(2000, 940)
    r = 85
    s.entity(860, 40, 220, 70, "Customer")
    s.entity(40, 150, 200, 70, "Email Service")
    s.entity(40, 615, 220, 70, "Payment Gateway")
    s.entity(1760, 615, 200, 70, "Staff / Owner")
    s.process(360, 330, r, "1.0", "User & Profile\nManagement")
    s.process(970, 330, r, "3.0", "Cart &\nCheckout")
    s.process(1580, 330, r, "2.0", "Catalog Browsing\n& Search")
    s.process(640, 650, r, "4.0", "Payment\nProcessing")
    s.process(1180, 650, r, "5.0", "Order Tracking\n& Notifications")
    s.process(1580, 650, r, "6.0", "Shop\nAdministration")
    s.store(240, 470, 240, "D1", "Users")
    s.store(700, 470, 240, "D3", "Cart & Favorites")
    s.store(1720, 308, 260, "D2", "Products & Categories")
    s.store(1210, 168, 280, "D7", "Coupons & Pay Methods")
    s.store(520, 840, 240, "D5", "Payments")
    s.store(900, 840, 240, "D4", "Orders")
    s.store(1260, 840, 240, "D6", "Notifications")
    # 1.0 user & profile
    s.flow([(860, 60), (360, 60), (360, 245)], "Register / Login", at=(610, 46))
    s.flow([(380, 247), (380, 90), (860, 90)], "Token, profile", at=(610, 104))
    s.flow([(360, 415), (360, 470)], "User record", at=(372, 442), anchor="start", both=True)
    s.flow([(275, 330), (140, 330), (140, 220)], "Reset code", at=(146, 290), anchor="start")
    s.flow([(445, 330), (885, 330)], "User ID, login status", at=(530, 316))
    # 2.0 catalog
    s.flow([(1080, 60), (1580, 60), (1580, 245)], "Search / filter request", at=(1330, 46))
    s.flow([(1600, 247), (1600, 90), (1080, 90)], "Products, prices", at=(1330, 104))
    s.flow([(1720, 330), (1665, 330)], "Product data", at=(1730, 372), anchor="start")
    s.flow([(1495, 330), (1055, 330)], "Selected product", at=(1380, 316))
    # 3.0 cart & checkout
    s.flow([(960, 110), (960, 245)], "Add to cart,\naddress, Place order", at=(948, 170), anchor="end")
    s.flow([(980, 245), (980, 110)], "Cart, totals", at=(992, 160), anchor="start")
    s.flow([(920, 399), (920, 470)], "Cart lines", at=(908, 436), anchor="end", both=True)
    s.flow([(1210, 190), (1030, 190), (1030, 270)], "Promo code,\npay methods on", at=(1042, 226), anchor="start")
    s.flow([(1020, 399), (1020, 840)], "New order", at=(1032, 560), anchor="start")
    s.flow([(887, 350), (640, 350), (640, 565)], "Order to pay", at=(652, 420), anchor="start")
    # 4.0 payment
    s.flow([(260, 635), (556, 635)], "QR request", at=(408, 621))
    s.flow([(556, 665), (260, 665)], "Payment status", at=(408, 680))
    s.flow([(640, 735), (640, 840)], "Payment record", at=(652, 788), anchor="start", both=True)
    s.flow([(725, 650), (940, 650), (940, 840)], "Mark paid", at=(832, 636))
    s.flow([(600, 575), (600, 140), (940, 140), (940, 110)], "QR code,\npayment status", at=(588, 220), anchor="end")
    # 5.0 tracking
    s.flow([(1140, 862), (1180, 862), (1180, 735)], "Order status", at=(1192, 790), anchor="start")
    s.flow([(1265, 650), (1380, 650), (1380, 840)], "New\nnotification", at=(1392, 752), anchor="start")
    s.flow([(1180, 565), (1180, 140), (1060, 140), (1060, 110)], "Order tracker,\nnotifications", at=(1192, 455), anchor="start")
    # 6.0 administration
    s.flow([(1760, 635), (1664, 635)], "Products, stock,\norder steps, promos", at=(1712, 590))
    s.flow([(1664, 665), (1760, 665)], "Orders, messages,\ndashboard", at=(1712, 712))
    s.flow([(1600, 567), (1600, 450), (1850, 450), (1850, 352)], "Product &\nstock changes", at=(1725, 476))
    s.flow([(1540, 575), (1540, 450), (1300, 450), (1300, 212)], "Promo codes,\npay methods on/off", at=(1312, 380), anchor="start")
    s.flow([(1500, 680), (1500, 780), (1100, 780), (1100, 840)], "Order steps", at=(1300, 766))
    s.save("dfd-level-1.svg")


def level_2():
    """Process 3.0 Cart & Checkout, split into its four steps."""
    s = Svg(2000, 900)
    r = 85
    s.entity(870, 40, 220, 70, "Customer")
    s.process(380, 320, r, "3.1", "Manage\nCart")
    s.process(1560, 320, r, "3.2", "Price &\nPromo Code")
    s.process(760, 640, r, "3.3", "Check Stock &\nSave Order")
    s.process(1300, 640, r, "3.4", "Choose\nPayment")
    s.process(1760, 640, 72, "4.0", "Payment\nProcessing")
    s.process(1760, 820, 60, "5.0", "Order\nTracking")
    s.store(260, 470, 240, "D3", "Cart & Favorites")
    s.store(1690, 155, 290, "D7", "Coupons & Pay Methods")
    s.store(380, 800, 260, "D2", "Products (stock)")
    s.store(700, 800, 240, "D4", "Orders")
    # 3.1 manage cart
    s.flow([(870, 60), (380, 60), (380, 235)], "Add, change quantity, remove", at=(625, 46))
    s.flow([(400, 237), (400, 90), (870, 90)], "Cart lines, stock left", at=(625, 104))
    s.flow([(380, 405), (380, 470)], "Cart lines", at=(392, 438), anchor="start", both=True)
    s.flow([(465, 320), (1475, 320)], "Cart items, subtotal", at=(700, 306))
    # 3.2 price and promo
    s.flow([(1090, 60), (1560, 60), (1560, 235)], "Promo code", at=(1325, 46))
    s.flow([(1580, 237), (1580, 90), (1090, 90)], "Price breakdown (discount, delivery fee)", at=(1325, 104))
    s.flow([(1800, 199), (1800, 300), (1643, 300)], "Coupon rules,\nmethods that are on", at=(1812, 250), anchor="start")
    s.flow([(1560, 405), (1560, 500), (760, 500), (760, 555)], "Final amount, delivery fee", at=(1160, 486))
    # 3.3 check stock and save
    s.flow([(980, 110), (980, 620), (843, 620)], "Address, delivery,\nPlace order", at=(992, 410), anchor="start")
    s.flow([(675, 640), (520, 640), (520, 800)], "Stock check,\nstock taken", at=(508, 700), anchor="end", both=True)
    s.flow([(780, 725), (780, 800)], "New order", at=(792, 764), anchor="start")
    s.flow([(700, 580), (700, 420), (440, 420), (440, 381)], "Sold out / only N left", at=(570, 406))
    s.flow([(845, 660), (1217, 660)], "Order number, total", at=(1030, 646))
    # 3.4 choose payment
    s.flow([(1385, 640), (1688, 640)], "KHQR / ABA: order to pay", at=(1536, 626))
    s.flow([(1300, 725), (1300, 820), (1700, 820)], "Cash: order confirmed", at=(1500, 806))
    s.save("dfd-level-2.svg")


if __name__ == "__main__":
    level_0()
    level_1()
    level_2()
