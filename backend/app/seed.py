"""Sample data for development and the demo video.

Run:  flask --app run seed
Images are placeholders - replace them with real product photos later.
"""
from urllib.parse import quote_plus

from .extensions import bcrypt, db
from .models import Category, Product, ProductImage, Review, Series, User


def _img(text):
    return f"https://placehold.co/600x600/png?text={quote_plus(text)}"


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
    ("Monkey D. Luffy Gear 5 1/7 Scale Figure", "scale-figures", "one-piece", "Good Smile Company", 189.00, 169.00, 5, True,
     "Luffy in his awakened Gear 5 form with dynamic cloud effects. Approx. 30 cm."),
    ("Roronoa Zoro Three-Sword Style 1/8 Figure", "scale-figures", "one-piece", "MegaHouse", 159.00, None, 4, False,
     "Zoro unleashing Santoryu with detailed blade effects. Approx. 24 cm."),
    ("Rengoku Kyojuro 1/8 Scale Figure", "scale-figures", "demon-slayer", "Aniplex", 179.00, None, 3, True,
     "The Flame Hashira mid-strike with flame effect parts. Approx. 23 cm."),
    ("Gojo Satoru Unlimited Void 1/7 Figure", "scale-figures", "jujutsu-kaisen", "Good Smile Company", 199.00, 185.00, 2, True,
     "Gojo with a glowing Domain Expansion base. Approx. 28 cm."),
    ("Makima 1/7 Scale Figure", "scale-figures", "chainsaw-man", "Kotobukiya", 149.00, None, 0, False,
     "Makima seated elegantly on a throne base. Approx. 21 cm."),
    # Chibi figures
    ("Nendoroid Anya Forger", "chibi-figures", "spy-x-family", "Good Smile Company", 49.00, None, 15, True,
     "Includes peanut, smug face, and Chimera plush parts."),
    ("Nendoroid Tanjiro Kamado", "chibi-figures", "demon-slayer", "Good Smile Company", 52.00, 45.00, 12, False,
     "Comes with Water Breathing effect parts and Nezuko box."),
    ("Nendoroid Itadori Yuji", "chibi-figures", "jujutsu-kaisen", "Good Smile Company", 52.00, None, 10, False,
     "Includes Divergent Fist effect and Sukuna face plate."),
    ("Nendoroid Pikachu", "chibi-figures", "pokemon", "Good Smile Company", 45.00, None, 20, False,
     "Pikachu with Thunderbolt effect and Poke Ball accessory."),
    # Prize figures
    ("Son Goku Super Saiyan Prize Figure", "prize-figures", "dragon-ball", "Banpresto", 29.00, 24.00, 30, True,
     "Goku powering up in Super Saiyan form. Approx. 18 cm."),
    ("Vegeta Final Flash Prize Figure", "prize-figures", "dragon-ball", "Banpresto", 29.00, None, 25, False,
     "Vegeta charging his Final Flash. Approx. 17 cm."),
    ("Naruto Uzumaki Sage Mode Prize Figure", "prize-figures", "naruto", "Banpresto", 32.00, None, 18, False,
     "Naruto in Sage Mode with Rasengan effect. Approx. 16 cm."),
    ("Uchiha Itachi Prize Figure", "prize-figures", "naruto", "Banpresto", 32.00, 27.00, 14, False,
     "Itachi in Akatsuki cloak with crows base. Approx. 17 cm."),
    ("Nezuko Kamado Prize Figure", "prize-figures", "demon-slayer", "SEGA", 26.00, None, 22, False,
     "Nezuko with bamboo muzzle in a cute pose. Approx. 15 cm."),
    # Plush & merch
    ("Pikachu Plush 30 cm", "plush-merch", "pokemon", "The Pokemon Company", 25.00, None, 40, False,
     "Super soft official Pikachu plush."),
    ("Chopper Plush Keychain", "plush-merch", "one-piece", "Bandai", 9.00, None, 60, False,
     "Tony Tony Chopper mini plush with keychain clip."),
    ("Anya Forger Acrylic Stand", "plush-merch", "spy-x-family", "Toho", 12.00, 10.00, 35, False,
     "15 cm double-sided acrylic stand."),
    ("Pochita Plush", "plush-merch", "chainsaw-man", "SEGA", 22.00, None, 0, False,
     "The cutest chainsaw devil. Approx. 20 cm."),
    # Model kits
    ("RG 1/144 RX-78-2 Gundam", "model-kits", "gundam", "Bandai Spirits", 35.00, None, 12, True,
     "Real Grade kit with inner frame. No glue needed."),
    ("HG 1/144 Gundam Aerial", "model-kits", "gundam", "Bandai Spirits", 22.00, 19.00, 20, False,
     "High Grade kit from The Witch from Mercury."),
    ("MG 1/100 Freedom Gundam 2.0", "model-kits", "gundam", "Bandai Spirits", 65.00, None, 6, False,
     "Master Grade kit with full wing gimmicks."),
    # TCG boosters
    ("One Piece Card Game Booster Box (24 packs)", "tcg-boosters", "one-piece", "Bandai", 110.00, 99.00, 10, True,
     "Sealed booster box, 24 packs x 12 cards. English edition."),
    ("One Piece Card Game Booster Pack", "tcg-boosters", "one-piece", "Bandai", 5.00, None, 200, False,
     "Single booster pack, 12 cards."),
    ("Pokemon TCG Booster Box (36 packs)", "tcg-boosters", "pokemon", "The Pokemon Company", 145.00, 135.00, 8, True,
     "Sealed booster box, 36 packs x 10 cards. English edition."),
    ("Pokemon TCG Booster Pack", "tcg-boosters", "pokemon", "The Pokemon Company", 4.50, None, 300, False,
     "Single booster pack, 10 cards."),
    ("Pokemon TCG Elite Trainer Box", "tcg-boosters", "pokemon", "The Pokemon Company", 49.00, None, 15, False,
     "9 booster packs, sleeves, dice, and storage box."),
    ("Yu-Gi-Oh! Booster Box (24 packs)", "tcg-boosters", "yu-gi-oh", "Konami", 85.00, None, 6, False,
     "Sealed booster box, 24 packs x 9 cards."),
    ("Dragon Ball Super Fusion World Booster Box", "tcg-boosters", "dragon-ball", "Bandai", 95.00, None, 0, False,
     "Sealed booster box, 24 packs. English edition."),
    # TCG decks
    ("One Piece Card Game Starter Deck - Straw Hat Crew", "tcg-decks", "one-piece", "Bandai", 15.00, None, 25, False,
     "51-card ready-to-play deck led by Luffy."),
    ("Yu-Gi-Oh! Structure Deck", "tcg-decks", "yu-gi-oh", "Konami", 12.00, None, 30, False,
     "Ready-to-play 46-card structure deck."),
    ("Pokemon TCG Battle Deck", "tcg-decks", "pokemon", "The Pokemon Company", 14.00, 12.00, 20, False,
     "60-card ready-to-play deck with coin and guide."),
    # TCG accessories (no series)
    ("Dragon Shield Matte Sleeves (100)", "tcg-accessories", None, "Dragon Shield", 11.00, None, 80, False,
     "Standard size 63.5 x 88 mm matte card sleeves."),
    ("Ultra Pro Deck Box 100+", "tcg-accessories", None, "Ultra Pro", 6.00, None, 50, False,
     "Holds 100 sleeved cards."),
    ("Rubber Playmat 60 x 35 cm", "tcg-accessories", None, "Ultra Pro", 18.00, 15.00, 25, False,
     "Smooth cloth surface with non-slip rubber base."),
    ("9-Pocket Card Binder (360 cards)", "tcg-accessories", None, "Vault X", 25.00, None, 18, False,
     "Side-loading pockets to protect your collection."),
]


def seed_data():
    if Category.query.first():
        print("Database already has data - skipping seed.")
        return

    categories = {slug: Category(name=n, slug=slug, description=d, image_url=_img(n))
                  for n, slug, d in CATEGORIES}
    series = {slug: Series(name=n, slug=slug, image_url=_img(n)) for n, slug in SERIES}
    db.session.add_all([*categories.values(), *series.values()])

    for i, (name, cat, ser, brand, price, disc, stock, featured, desc) in enumerate(PRODUCTS, start=1):
        product = Product(
            name=name, slug=f"product-{i}", description=desc, brand=brand,
            category=categories[cat], series=series[ser] if ser else None,
            price=price, discount_price=disc, stock=stock, is_featured=featured,
        )
        product.images = [
            ProductImage(image_url=_img(name), is_primary=True, sort_order=0),
            ProductImage(image_url=_img(f"{name} (back)"), sort_order=1),
        ]
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
