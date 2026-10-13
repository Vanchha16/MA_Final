# Anime World Shop — Figma UI/UX Prompts

Matches `docs/BUILD_PROMPT.md` (same colors, screens and flows), so the Figma design and the Flutter app stay identical.

## How to use

| Tool | How |
|---|---|
| **Figma Make** (best for full apps) | Paste **Prompt A**, then **Prompt B**, then the screen batches **C1 → C7** one at a time in the same chat. Finish with **Prompt D**. |
| **Figma "First Draft"** (Actions → First Draft) | Short prompts work best: paste Prompt A once as "context", then one screen from section C per generation. |
| Google Stitch / Uizard / Galileo | Same order as Figma Make; export or copy to Figma afterwards. |

Tips
- Upload `mobile/assets/logo.png` and tell the AI to use it wherever the prompt says **[LOGO]**.
- Generate **light mode first**; ask for dark mode at the end (Prompt D) so components are reused.
- After generating, fix anything off-brand by hand: AI tools often drift from the exact hex colors.

---

## Prompt A — Project context (paste first)

```
Design a modern, clean, user-friendly mobile e-commerce app called "Anime World Shop".
It sells anime merchandise: scale figures, chibi/Nendoroid figures, prize figures, plush & merch,
Gunpla model kits, and anime trading card games (TCG booster packs, booster boxes, starter decks,
sleeves, deck boxes, playmats). Customers browse by category and by anime series
(One Piece, Pokemon, Dragon Ball, Naruto, Demon Slayer, Jujutsu Kaisen, Spy x Family,
Chainsaw Man, Gundam, Yu-Gi-Oh!). Target users: anime fans and card collectors aged 15-35 in Cambodia.
Prices in USD. Payment: Cash on Delivery and Bakong KHQR. Languages: English and Khmer.

Platform: Android phone, frame "Android Compact" 412 x 917, Material Design 3.
Style: bright, fresh and playful but professional - clean white surfaces, generous spacing,
rounded cards, soft shadows, sky-blue to aqua gradients for hero areas, subtle sparkle/star
decorations inspired by anime (used sparingly). Do NOT use real anime characters or official logos;
use neutral placeholder product images (figure boxes, card packs).
Use auto layout everywhere, and build reusable components with variants.
Never use emoji anywhere in the UI; use Material Symbols (rounded) icons instead.
```

## Prompt B — Design system (paste second)

```
Create a design system page called "Design System" for Anime World Shop.

COLORS (light mode)
- Primary / sky blue: #0EA5E9 (buttons, links, active states)
- Primary dark: #0284C7 (pressed states, text on light backgrounds, behind white text)
- Accent / aqua: #06B6D4 (highlights, gradients end color)
- Sale / coral: #F43F5E (discount badges, wishlist heart, "Sold out")
- Success #22C55E, Warning #F59E0B, Error #EF4444
- Background #F8FAFC, Surface #FFFFFF, Border #E2E8F0
- Text primary #0F172A, Text secondary #64748B, Text disabled #94A3B8
- Brand gradient: linear 135deg from #0284C7 to #06B6D4

COLORS (dark mode)
- Background #0B1220, Surface #111827, Surface variant #1F2937, Border #334155
- Text primary #F1F5F9, Text secondary #94A3B8
- Primary #38BDF8, Accent #22D3EE, Coral #FB7185

TYPOGRAPHY
- Headings: Poppins SemiBold/Bold. Body: Inter Regular/Medium. Khmer text: Kantumruy Pro.
- Scale: Display 32/40, H1 24/32, H2 20/28, H3 18/26, Body L 16/24, Body M 14/20, Caption 12/16, Overline 11/16 uppercase.
- Prices: Poppins SemiBold; old price strike-through in Text secondary.

LAYOUT
- 8pt spacing grid (4, 8, 12, 16, 24, 32). Screen side padding 16. Corner radius: 12 inputs/buttons,
  16 cards, 24 bottom sheets, full for chips and avatars. Elevation: soft shadow 0 4 16 rgba(15,23,42,0.08).
- Minimum touch target 48 x 48. Text contrast WCAG AA.

COMPONENTS (with variants and states: default, pressed, disabled, loading, error)
- Buttons: Primary filled with SOLID #0284C7 (never a gradient; full width, 52 high, pill), Secondary outlined, Text button, Icon button, FAB
- Inputs: text field with label, prefix icon, suffix (show/hide password), helper and error text; search bar; OTP 6-box input
- Product card (grid, 2 columns): image 1:1 with rounded top, coral "-15%" badge top-left, heart toggle top-right,
  "Sold out" overlay variant, series name (aqua caption), product name (2 lines), price + old price, rating stars + count, small "+ cart" icon button
- Product card (horizontal list item) for cart, wishlist and order items
- Category tile (icon/image + name + product count), Series tile (round image + name)
- Chips: filter chip, choice chip, status chip (Pending amber, Confirmed blue, Shipped aqua, Delivered green, Cancelled grey)
- Quantity stepper (- 1 +), Rating stars (display + input), Price text, Sale badge, Cart badge on icon
- Bottom navigation bar, 5 items: Home, Categories, Wishlist, Cart (badge), Profile
- Top app bar (back, title, actions), Section header ("Featured" + "See all")
- Bottom sheet, Dialog (confirm), Snackbar/toast, Empty state (illustration + title + text + button),
  Error state (icon + message + Retry), Shimmer skeletons for card and list
- Order status timeline (vertical steps), Free-shipping progress bar, Promo banner (gradient, title, CTA)
- Settings list tile (icon, title, trailing switch / chevron / value)
```

---

## Prompt C — Screens (paste one batch at a time)

### C1 — Onboarding & authentication
```
Using the Anime World Shop design system, design these screens:

1. Splash: full-screen brand gradient (#0284C7 to #06B6D4), [LOGO] centered in a white circle
   with soft shadow, app name "Anime World Shop" in white Poppins Bold, tagline
   "Figures • Plush • Trading Cards", small white loading indicator near the bottom.
2. Onboarding (3 slides, show slide 1 and variants for 2 and 3): large illustration on top,
   title + short text, page dots, "Skip" top-right, "Next"/"Get Started" button.
   Slides: "Collect your favorite figures", "Rip packs, build your deck", "Fast delivery across Cambodia".
3. Login: [LOGO] small on top, "Welcome back", subtitle, email and password fields,
   "Forgot password?" link right-aligned, primary "Log In" button, divider "or",
   "Continue as guest" text button, bottom "Don't have an account? Sign up".
4. Register: back arrow, "Create account", full name, email, phone, password, confirm password,
   checkbox "I agree to the Terms", "Sign Up" button, "Already have an account? Log in".
   Also show the error state with red helper text under the email field ("Email is already registered").
5. Forgot Password: illustration, "Forgot password?", text, email field, "Send code" button.
6. Verify OTP: "Enter verification code", text "We sent a 6-digit code to d***@gmail.com",
   6 OTP boxes, "Verify" button, "Resend code in 00:45".
7. Reset Password: new password, confirm password, "Reset password" button,
   plus a success state with a check icon and "Back to login".
```

### C2 — Home & browsing
```
Design these Anime World Shop screens with the bottom navigation bar visible (active tab highlighted):

8. Home: top row with "Hi, Dara" + waving-hand icon and "What are you collecting today?", notification bell with
   red dot; search bar (tap opens Search); promo banner carousel with brand gradient
   ("TCG Week - up to 20% off booster boxes", "Shop now" button) and page dots;
   horizontal category chips (Scale Figures, Chibi Figures, Prize Figures, Plush & Merch, Model Kits,
   TCG Boosters, TCG Decks, TCG Accessories); "Shop by Anime" row of round series tiles;
   "Featured" 2-column product grid (4 cards, one with -11% coral badge, one Sold out);
   "New Arrivals" horizontal product list.
9. Categories: title "Categories", 2-column grid of 8 category tiles with image, name and
   "12 products" count, grouped under "Figures & Toys" and "Trading Card Games" headers.
10. Shop by Anime: 3-column grid of 10 series tiles (round image + name).
11. Product List: app bar with category title "TCG Boosters" and back arrow, row with
    "35 results", sort dropdown ("Newest") and Filter button with badge "2"; active filter chips
    ("One Piece ×", "Under $50 ×"); 2-column product grid; loading shimmer at the bottom for infinite scroll.
    Also show the empty state: "No products found" with "Clear filters" button.
```

### C3 — Search, filter, product details
```
Design these Anime World Shop screens:

12. Search: focused search field with back arrow and clear icon; "Recent searches" list with
    clock icons and remove ×; "Popular series" chips; second variant showing results for "luffy"
    as a product grid with result count.
13. Filter bottom sheet (tall, 85% height, rounded top 24): title "Filters" + "Reset"; sections:
    Category (choice chips), Anime series (chips, "See all"), Brand (checkbox list: Bandai,
    Good Smile Company, Banpresto, The Pokemon Company, Konami), Price range (range slider
    $0 - $200 with min/max fields), "In stock only" switch, Sort by (radio list: Newest,
    Price low to high, Price high to low, Name A-Z); sticky "Show 24 results" primary button.
14. Product Details: large image gallery (swipeable, page dots, back and heart buttons floating
    over the image); series chip "One Piece" (aqua) and brand "Good Smile Company";
    name "Monkey D. Luffy Gear 5 1/7 Scale Figure"; rating 4.8 with star icon (24 reviews);
    price "$169.00", old price "$189.00" strike-through, coral badge "-11%";
    stock text "Only 5 left" in amber; expandable description; "Reviews" preview with 2 reviews
    and "See all"; "You may also like" horizontal list; sticky bottom bar with quantity stepper
    and "Add to Cart" primary button. Variant: Sold out (button disabled "Sold out", coral label).
15. Image Gallery: black background, full-screen zoomable image, close button, thumbnails row.
16. Reviews: average 4.8 big number with stars, 5-star to 1-star horizontal bars with counts, list of
    reviews (avatar, name, stars, date, comment), "Write a review" button.
17. Write Review: product mini card, large tappable 5-star rating, comment text area, "Submit".
```

### C4 — Wishlist, cart, checkout
```
Design these Anime World Shop screens:

18. Wishlist: title "Wishlist (6)", 2-column product grid with filled coral hearts,
    "Move to cart" small button on each card; plus empty state
    ("Your wishlist is empty", "Explore products").
19. Cart: title "My Cart (3)", list of cart items (image, name, series, price, quantity stepper,
    delete icon); one item shown mid swipe-to-delete with red background; free-shipping progress bar
    "Add $12.50 more for FREE shipping"; summary card: Subtotal, Shipping $2.00, Total;
    sticky "Checkout" button. Plus empty cart state with illustration and "Start shopping".
20. Checkout: sections in cards - Shipping address (name, phone, address, "Change"),
    Payment method (radio cards: "Cash on Delivery", "Bakong KHQR" with KHQR mark),
    Order note field, Order summary (items collapsed "3 items", subtotal, shipping, total);
    sticky "Place Order - $57.50" button.
21. Address List: address cards with label chip (Home / Work), "Default" badge, radio select,
    edit and delete icons, "+ Add new address" button.
22. Add / Edit Address: label chips (Home, Work, Other), recipient name, phone, street,
    city/province dropdown (Phnom Penh, Siem Reap, Battambang, ...), postal code,
    "Set as default" switch, "Save address" button.
```

### C5 — Payment & orders
```
Design these Anime World Shop screens:

23. KHQR Payment: title "Scan to pay", white card in KHQR style (red header strip with "KHQR",
    merchant name "Anime World Shop", amount "$57.50"), large QR code in the middle, countdown
    "Expires in 04:59", text "Open any Bakong-supported banking app to scan", status row
    "Waiting for payment..." with spinner, secondary "Save QR" and "Cancel" buttons.
24. Order Confirmation: big success check animation area with confetti/sparkles,
    "Order placed!", order number "AWS-20261013-0001", total and payment method,
    "View order" primary and "Continue shopping" text button.
25. Order History: title "My Orders", scrollable tabs All / Pending / Shipped / Delivered / Cancelled,
    order cards (order number, date, status chip, 2-3 product thumbnails, "3 items", total, chevron).
    Plus empty state "No orders yet".
26. Order Details: status timeline (Placed → Confirmed → Shipped → Delivered with dates, current step
    highlighted), items list, shipping address card, payment card (method + Paid/Unpaid chip),
    totals; buttons depending on status: "Cancel order" (pending), "Pay now" (unpaid KHQR),
    "Write review" next to each item (delivered).
```

### C6 — Account, notifications, settings, info
```
Design these Anime World Shop screens:

27. Notifications: app bar with "Mark all read"; list grouped "Today" / "Earlier"; items with
    type icon (order = box, promo = tag, system = bell) in tinted circles, title, message,
    time, unread blue dot and light-blue background for unread. Plus empty state.
28. Profile: header with brand gradient, avatar with camera badge, name, email,
    3 stat boxes (Orders, Wishlist, Reviews); menu list: My Orders, Addresses, Notifications (badge 3),
    Settings, About App, Contact Us; "Log out" in red at the bottom; plus logout confirm dialog.
29. Edit Profile: large avatar with "Change photo" (bottom sheet: Camera / Gallery),
    full name, email (disabled), phone, "Save changes".
30. Change Password: current, new, confirm password fields with show/hide, password rules
    checklist, "Update password".
31. Settings: sections "Appearance" (Theme: System / Light / Dark segmented control),
    "Language" (English / ខ្មែរ with flags), "Notifications" (Order updates switch, Promotions switch),
    "Other" (Clear search history, App version 1.0.0).
32. About App: [LOGO], app name, version, short description, features list, team members with
    roles (4 avatars), tech stack chips (Flutter, Flask, MySQL).
33. Contact Us: illustration, list tiles with icons for Phone (+855 12 345 678), Email,
    Telegram, Facebook, shop address in Phnom Penh with small map preview, opening hours
    "Mon-Sun 9:00 - 21:00", "Send us a message" form (subject, message, Send).
```

### C7 — Admin panel (web, optional but recommended)
```
Design a desktop admin dashboard (frame 1440 x 1024) for Anime World Shop using the same colors:
left sidebar with [LOGO] and menu (Dashboard, Products, Categories, Series, Orders, Customers,
Notifications); Dashboard with 4 KPI cards (Revenue, Orders, Customers, Low stock), sales line chart,
orders-by-status donut, recent orders table; Products table page (image, name, category, series,
price, stock, status toggle, edit/delete) with search, filters and "+ Add product";
Add/Edit product form with image upload area (drag & drop, up to 5 images, choose primary);
Orders table with status chips and a status dropdown in the order detail drawer.
```

---

## Prompt D — Dark mode, Khmer, prototype (paste last)

```
1. Create dark mode versions of: Home, Product Details, Cart, Checkout, Profile and Settings,
   using the dark tokens from the design system (do not just invert colors; keep coral and
   sky blue readable, surfaces #111827 on background #0B1220).
2. Create Khmer language versions of Login, Home and Product Details using Kantumruy Pro;
   make sure longer Khmer text wraps without overflowing buttons and chips.
   Examples: "Log In" = "ចូលគណនី", "Add to Cart" = "បន្ថែមទៅកន្ត្រក", "Home" = "ទំព័រដើម",
   "Cart" = "កន្ត្រក", "Wishlist" = "ចូលចិត្ត", "Profile" = "គណនី".
3. Build a clickable prototype with these flows (Smart Animate, 300ms ease-out):
   - Splash → Onboarding → Login → Home
   - Login → Register; Login → Forgot Password → Verify OTP → Reset Password → Login
   - Home → Category → Product List → Filter sheet → Product Details → Add to Cart → Cart
   - Cart → Checkout → Bakong KHQR → Order Confirmation → Order Details
   - Profile → My Orders → Order Details; Profile → Settings (toggle dark mode)
   - Bottom navigation works on every main tab.
4. Organize the file into pages: "Cover", "Design System", "Components", "Auth", "Shop",
   "Cart & Checkout", "Orders", "Account", "Dark Mode", "Khmer", "Admin", "Prototype".
   Name every frame with its number and name, e.g. "14 - Product Details".
```

---

## Checklist after generating
- [ ] All 33 screens exist (the brief requires at least 20), numbered the same as `BUILD_PROMPT.md`
- [ ] Colors match the hex values exactly; only coral is used for sale/heart/sold-out
- [ ] Every list screen has loading, empty and error variants
- [ ] Components use auto layout and variants (easier to hand off to Flutter)
- [ ] Dark mode + Khmer frames (bonus features shown in the design too)
- [ ] Prototype flows work; export screenshots of key screens for the report and slides
- [ ] Share the Figma link (view access) in the README and the final report
