"""Sample data for development and the demo video.

Run:  flask --app run seed
Products start without photos: the app shows a branded placeholder tile until
real product photos are uploaded.
"""
from datetime import timedelta

from slugify import slugify

from .extensions import bcrypt, db
from .models import Category, Favorite, Order, OrderItem, Product, Review, Series, User
from .utils.clock import utcnow


CATEGORIES = [
    ("Scale Figures", "scale-figures", "Premium detailed figures in 1/7, 1/8 scale"),
    ("Chibi Figures", "chibi-figures", "Nendoroid and cute chibi-style figures"),
    ("Prize Figures", "prize-figures", "Affordable figures from Banpresto, SEGA, Taito"),
    ("Plush & Merch", "plush-merch", "Plushies, keychains, acrylic stands"),
    ("Model Kits", "model-kits", "Gunpla and plastic model kits"),
    ("TCG Boosters", "tcg-boosters", "Booster packs and booster boxes"),
    ("TCG Starter Decks", "tcg-decks", "Ready-to-play starter and structure decks"),
    ("TCG Accessories", "tcg-accessories", "Sleeves, deck boxes, playmats, binders"),
]

SERIES = [
    ("One Piece", "one-piece"), ("Pokemon", "pokemon"), ("Dragon Ball", "dragon-ball"),
    ("Naruto", "naruto"), ("Demon Slayer", "demon-slayer"), ("Jujutsu Kaisen", "jujutsu-kaisen"),
    ("Spy x Family", "spy-x-family"), ("Chainsaw Man", "chainsaw-man"),
    ("Gundam", "gundam"), ("Yu-Gi-Oh!", "yu-gi-oh"),
]

# (name, category_slug, series_slug, brand, price, discount_price, stock, featured, description)
PRODUCTS = [
    # Scale figures
    ("P.O.P SA-MAXIMUM Monkey D. Luffy Gear 5 Figure", "scale-figures", "one-piece", "MegaHouse", 189.00, 169.00, 5, True,
     "Luffy in his awakened Gear 5 form with dynamic cloud effects. Approx. 30 cm."),
    ("P.O.P SA-MAXIMUM Roronoa Zoro Three Thousand Worlds 1/8 Figure", "scale-figures", "one-piece", "MegaHouse", 159.00, None, 4, False,
     "Zoro unleashing his Three Sword Style ultimate attack. Approx. 21 cm without swords."),
    ("Rengoku Kyojuro Mugen Train 1/8 Scale Figure", "scale-figures", "demon-slayer", "Aniplex", 179.00, None, 3, True,
     "The Flame Hashira from the Mugen Train movie visual, with flame effect base. Approx. 20 cm."),
    ("Satoru Gojo Tokyo Jujutsu High School Ver. 1/7 Figure", "scale-figures", "jujutsu-kaisen", "Good Smile Company", 199.00, 185.00, 2, True,
     "Gojo in his Tokyo Jujutsu High uniform with round sunglasses. Approx. 28.5 cm with base."),
    ("F:NEX Makima 1/7 Scale Figure", "scale-figures", "chainsaw-man", "FuRyu", 149.00, None, 0, False,
     "Makima striking her signature hand pose. Approx. 25 cm with base."),
    # Chibi figures
    ("Nendoroid Anya Forger", "chibi-figures", "spy-x-family", "Good Smile Company", 49.00, None, 15, True,
     "Includes peanut, smug face, and Chimera plush parts."),
    ("Nendoroid Tanjiro Kamado", "chibi-figures", "demon-slayer", "Good Smile Company", 52.00, 45.00, 12, False,
     "Comes with Water Breathing effect parts and Nezuko box."),
    ("Nendoroid Yuji Itadori", "chibi-figures", "jujutsu-kaisen", "Good Smile Company", 52.00, None, 10, False,
     "Includes Divergent Fist effect and Sukuna face plate."),
    ("Nendoroid Ash & Pikachu", "chibi-figures", "pokemon", "Good Smile Company", 45.00, None, 20, False,
     "Ash with Pikachu, Poke Ball and Thunderbolt effect parts."),
    # Prize figures
    ("Grandista Son Goku Super Saiyan Prize Figure", "prize-figures", "dragon-ball", "Banpresto", 29.00, 24.00, 30, True,
     "Big Super Saiyan Goku from the Grandista line. Approx. 28 cm."),
    ("Grandista Vegeta Super Saiyan Prize Figure", "prize-figures", "dragon-ball", "Banpresto", 29.00, None, 25, False,
     "Big Super Saiyan Vegeta from the Grandista line. Approx. 26 cm."),
    ("Memorable Saga Special Naruto Uzumaki Sage Mode Prize Figure", "prize-figures", "naruto", "Banpresto", 32.00, None, 18, False,
     "Sage Mode Naruto from the Pain invasion arc on a diorama base. Approx. 12 cm."),
    ("Grandista Uchiha Itachi Prize Figure", "prize-figures", "naruto", "Banpresto", 32.00, 27.00, 14, False,
     "Itachi in his Akatsuki cloak from the Grandista line. Approx. 28 cm."),
    ("Xross Link Nezuko Kamado Prize Figure", "prize-figures", "demon-slayer", "SEGA", 26.00, None, 22, False,
     "Nezuko in a dynamic pose, made to display next to the Tanjiro figure. Approx. 16 cm."),
    # Plush & merch
    ("Poke Piece Pikachu Big Plush 28 cm", "plush-merch", "pokemon", "Banpresto", 25.00, None, 40, False,
     "Extra soft and huggable Pikachu plush. Approx. 28 cm."),
    ("Tony Tony Chopper Plush Sepia (S)", "plush-merch", "one-piece", "ONE PIECE BASE SHOP", 9.00, None, 60, False,
     "Fluffy Chopper plush in calm sepia colors."),
    ("Luminasta Anya Forger Summer Vacation Figure", "prize-figures", "spy-x-family", "SEGA", 12.00, 10.00, 35, False,
     "Anya enjoying summer vacation with her swim ring. Approx. 15 cm."),
    ("Nesoberi Pochita Plush", "plush-merch", "chainsaw-man", "SEGA", 22.00, None, 0, False,
     "The cutest chainsaw devil, lying down. Approx. 16 cm long."),
    # Model kits
    ("RG 1/144 RX-78-2 Gundam Ver.2.0", "model-kits", "gundam", "Bandai Spirits", 35.00, None, 12, True,
     "Real Grade kit with an all-new inner frame and articulation. No glue needed."),
    ("HG 1/144 Gundam Aerial", "model-kits", "gundam", "Bandai Spirits", 22.00, 19.00, 20, False,
     "High Grade kit from The Witch from Mercury."),
    ("MG 1/100 Freedom Gundam Ver.2.0", "model-kits", "gundam", "Bandai Spirits", 65.00, None, 6, False,
     "Master Grade kit with full wing gimmicks."),
    # TCG boosters
    ("One Piece Card Game Romance Dawn OP-01 Booster Box (24 packs)", "tcg-boosters", "one-piece", "Bandai", 110.00, 99.00, 10, True,
     "Sealed booster box, 24 packs x 12 cards. English edition."),
    ("One Piece Card Game Romance Dawn OP-01 Booster Pack", "tcg-boosters", "one-piece", "Bandai", 5.00, None, 200, False,
     "Single booster pack, 12 cards."),
    ("Pokemon TCG Battle Partners Booster Box (30 packs)", "tcg-boosters", "pokemon", "The Pokemon Company", 145.00, 135.00, 8, True,
     "Sealed box, 30 packs x 5 cards. Japanese edition."),
    ("Pokemon TCG Battle Partners Booster Pack", "tcg-boosters", "pokemon", "The Pokemon Company", 4.50, None, 300, False,
     "Single booster pack, 5 cards. Japanese edition."),
    ("Pokemon TCG Deck Build Box Battle Partners", "tcg-boosters", "pokemon", "The Pokemon Company", 49.00, None, 15, False,
     "171 cards, 10 booster packs, a card box and dividers."),
    ("Yu-Gi-Oh! Revolution Booster Box", "tcg-boosters", "yu-gi-oh", "Konami", 85.00, None, 6, False,
     "Sealed concept booster box for Toon, Witchcrafter and Hakai decks."),
    ("Dragon Ball Super Fusion World Awakened Pulse FB01 Booster Box", "tcg-boosters", "dragon-ball", "Bandai", 95.00, None, 0, False,
     "Sealed booster box, 24 packs. English edition."),
    # TCG decks
    ("One Piece Card Game Starter Deck Straw Hat Crew ST-01", "tcg-decks", "one-piece", "Bandai", 15.00, None, 25, False,
     "51-card ready-to-play deck led by Luffy."),
    ("Yu-Gi-Oh! Structure Deck Power of the Fellows", "tcg-decks", "yu-gi-oh", "Konami", 12.00, None, 30, False,
     "Ready-to-play Synchro deck inspired by Yusei Fudo."),
    ("Pokemon TCG Start Deck Generations", "tcg-decks", "pokemon", "The Pokemon Company", 14.00, 12.00, 20, False,
     "Ready-to-play deck with 2 Pokemon ex, damage counters and markers."),
    # TCG accessories (no series)
    ("Dragon Shield Matte Sleeves Black (100)", "tcg-accessories", None, "Dragon Shield", 11.00, None, 80, False,
     "Standard size 63.5 x 88 mm matte card sleeves."),
    ("Ultra PRO Eclipse PRO 100+ Deck Box", "tcg-accessories", None, "Ultra Pro", 6.00, None, 50, False,
     "Holds 100 sleeved cards."),
    ("Ultra PRO Black Stitched Playmat Starfield", "tcg-accessories", None, "Ultra Pro", 18.00, 15.00, 25, False,
     "Smooth cloth surface with non-slip rubber base."),
    ("Vault X 9-Pocket Exo-Tec Zip Binder (360 cards)", "tcg-accessories", None, "Vault X", 25.00, None, 18, False,
     "Side-loading pockets to protect your collection."),
]


def seed_data():
    if Category.query.first():
        print("Database already has data - skipping catalog seed.")
        seed_demo_orders()
        return

    categories = {slug: Category(name=n, slug=slug, description=d)
                  for n, slug, d in CATEGORIES}
    series = {slug: Series(name=n, slug=slug) for n, slug in SERIES}
    db.session.add_all([*categories.values(), *series.values()])

    for name, cat, ser, brand, price, disc, stock, featured, desc in PRODUCTS:
        product = Product(
            name=name, slug=slugify(name), description=desc, brand=brand,
            category=categories[cat], series=series[ser] if ser else None,
            price=price, discount_price=disc, stock=stock, is_featured=featured,
        )
        db.session.add(product)

    pw = bcrypt.generate_password_hash("demo123").decode()
    admin = User(full_name="Admin", email="admin@shop.com", password_hash=pw, role="admin")
    demo = User(full_name="Demo Customer", email="demo@shop.com", password_hash=pw, phone="012345678")
    db.session.add_all([admin, demo])
    db.session.flush()

    first_products = Product.query.order_by(Product.id).limit(4).all()
    for product, rating in zip(first_products, [5, 4, 5, 4]):
        db.session.add(Review(product=product, user=demo, rating=rating, comment="Great quality, fast delivery!"))

    db.session.commit()
    print(f"Seeded {len(CATEGORIES)} categories, {len(SERIES)} series, {len(PRODUCTS)} products, 2 users.")
    seed_demo_orders()


# Order history for demo@shop.com so the Profile shows real data in the demo video:
# 3 delivered (926 pts -> Silver), 2 shipped (To Receive), 1 confirmed (To Ship),
# 2 delivered products not reviewed yet (To Review).
# (days ago, status, payment method, payment status, [(product name, qty)])
DEMO_ORDERS = [
    (40, "delivered", "khqr", "paid", [("P.O.P SA-MAXIMUM Monkey D. Luffy Gear 5 Figure", 1), ("P.O.P SA-MAXIMUM Roronoa Zoro Three Thousand Worlds 1/8 Figure", 1)]),
    (25, "delivered", "cod", "paid", [("Rengoku Kyojuro Mugen Train 1/8 Scale Figure", 1), ("Satoru Gojo Tokyo Jujutsu High School Ver. 1/7 Figure", 1)]),
    (12, "delivered", "khqr", "paid", [("Pokemon TCG Battle Partners Booster Box (30 packs)", 1), ("One Piece Card Game Romance Dawn OP-01 Booster Box (24 packs)", 1)]),
    (4, "shipped", "cod", "unpaid", [("Nendoroid Anya Forger", 1)]),
    (3, "shipped", "khqr", "paid", [("Poke Piece Pikachu Big Plush 28 cm", 2)]),
    (1, "confirmed", "khqr", "paid", [("RG 1/144 RX-78-2 Gundam Ver.2.0", 1)]),
]
DEMO_WISHLIST = [
    "Nendoroid Tanjiro Kamado", "F:NEX Makima 1/7 Scale Figure", "Pokemon TCG Deck Build Box Battle Partners",
    "MG 1/100 Freedom Gundam Ver.2.0", "Nesoberi Pochita Plush", "Nendoroid Yuji Itadori",
]


def seed_demo_orders():
    """Idempotent: does nothing if the demo customer already has orders."""
    demo = User.query.filter_by(email="demo@shop.com").first()
    if not demo or Order.query.filter_by(user_id=demo.id).first():
        return
    products = {p.name: p for p in Product.query}
    now = utcnow()
    for seq, (days_ago, status, method, paid, lines) in enumerate(DEMO_ORDERS, start=1):
        when = now - timedelta(days=days_ago)
        subtotal = sum(float(products[n].final_price) * q for n, q in lines)
        shipping = 0 if subtotal >= 50 else 2  # free shipping from $50
        order = Order(
            order_number=f"AWS-{when:%Y%m%d}-{seq:04d}", user_id=demo.id,
            shipping_name=demo.full_name, shipping_phone=demo.phone or "012345678",
            shipping_address="St. 271, Toul Tom Poung, Phnom Penh",
            subtotal=subtotal, shipping_fee=shipping, total=subtotal + shipping,
            status=status, payment_method=method, payment_status=paid,
            created_at=when, updated_at=when,
        )
        for name, qty in lines:
            p = products[name]
            order.items.append(OrderItem(product_id=p.id, product_name=p.name, unit_price=p.final_price,
                                         quantity=qty, subtotal=float(p.final_price) * qty))
        db.session.add(order)
    for name in DEMO_WISHLIST:
        if name in products:
            db.session.add(Favorite(user_id=demo.id, product_id=products[name].id))
    db.session.commit()
    print(f"Seeded {len(DEMO_ORDERS)} demo orders and {len(DEMO_WISHLIST)} wishlist items for demo@shop.com.")
