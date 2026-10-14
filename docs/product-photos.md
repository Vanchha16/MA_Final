# Product photos

Official product photos for the demo. **Do not commit them** - `backend/uploads/` is git-ignored
because the photos belong to their makers. Share the folder with the team (e.g. Google Drive).

## How to add photos

1. Create the folders (already done on the main dev PC):
   ```
   cd backend
   flask --app run import-images --make-folders
   ```
   Every product gets a folder in `backend/uploads/products/` with a `_PUT_PHOTOS_HERE.txt` note.
2. Save 1-2 photos per product in its folder, named `1.jpg`, `2.jpg` (png / webp also work).
   The first file is the main photo. Square photos on a white background look best.
3. Import (safe to run again after adding or changing photos):
   ```
   flask --app run import-images            # or --dry-run to only check
   ```
   Photos are shrunk to max 1000 px WebP in `backend/uploads/catalog/`. Restart the app to see them.

If the exact item does not exist officially, pick the closest official release and rename the
product (name and price) in `backend/app/seed.py` - its folder name is the new name in lower case
with dashes.

Add this credit to the README / About screen once photos are in:
> Product images belong to their respective owners and are used for educational purposes only.

## Folder list (35 products)


### Scale Figures

| # | Folder name | Product | Brand | Official source | Done |
|---|---|---|---|---|---|
| 1 | `monkey-d-luffy-gear-5-1-7-scale-figure` | Monkey D. Luffy Gear 5 1/7 Scale Figure | Good Smile Company | goodsmile.com | [ ] |
| 2 | `roronoa-zoro-three-sword-style-1-8-figure` | Roronoa Zoro Three-Sword Style 1/8 Figure | MegaHouse | megahouse.co.jp | [ ] |
| 3 | `rengoku-kyojuro-1-8-scale-figure` | Rengoku Kyojuro 1/8 Scale Figure | Aniplex | aniplex.co.jp | [ ] |
| 4 | `gojo-satoru-unlimited-void-1-7-figure` | Gojo Satoru Unlimited Void 1/7 Figure | Good Smile Company | goodsmile.com | [ ] |
| 5 | `makima-1-7-scale-figure` | Makima 1/7 Scale Figure | Kotobukiya | kotobukiya.co.jp | [ ] |

### Chibi Figures

| # | Folder name | Product | Brand | Official source | Done |
|---|---|---|---|---|---|
| 6 | `nendoroid-anya-forger` | Nendoroid Anya Forger | Good Smile Company | goodsmile.com | [ ] |
| 7 | `nendoroid-tanjiro-kamado` | Nendoroid Tanjiro Kamado | Good Smile Company | goodsmile.com | [ ] |
| 8 | `nendoroid-itadori-yuji` | Nendoroid Itadori Yuji | Good Smile Company | goodsmile.com | [ ] |
| 9 | `nendoroid-pikachu` | Nendoroid Pikachu | Good Smile Company | goodsmile.com | [ ] |

### Prize Figures

| # | Folder name | Product | Brand | Official source | Done |
|---|---|---|---|---|---|
| 10 | `son-goku-super-saiyan-prize-figure` | Son Goku Super Saiyan Prize Figure | Banpresto | bandaispirits.co.jp (Banpresto prize figures) | [ ] |
| 11 | `vegeta-final-flash-prize-figure` | Vegeta Final Flash Prize Figure | Banpresto | bandaispirits.co.jp (Banpresto prize figures) | [ ] |
| 12 | `naruto-uzumaki-sage-mode-prize-figure` | Naruto Uzumaki Sage Mode Prize Figure | Banpresto | bandaispirits.co.jp (Banpresto prize figures) | [ ] |
| 13 | `uchiha-itachi-prize-figure` | Uchiha Itachi Prize Figure | Banpresto | bandaispirits.co.jp (Banpresto prize figures) | [ ] |
| 14 | `nezuko-kamado-prize-figure` | Nezuko Kamado Prize Figure | SEGA | SEGA prize figures site (search "SEGA prize" + name) | [ ] |

### Plush & Merch

| # | Folder name | Product | Brand | Official source | Done |
|---|---|---|---|---|---|
| 15 | `pikachu-plush-30-cm` | Pikachu Plush 30 cm | The Pokemon Company | pokemoncenter.com | [ ] |
| 16 | `chopper-plush-keychain` | Chopper Plush Keychain | Bandai | Bandai official site / en.onepiece-cardgame.com for One Piece cards | [ ] |
| 17 | `anya-forger-acrylic-stand` | Anya Forger Acrylic Stand | Toho | Toho animation store (search name) | [ ] |
| 18 | `pochita-plush` | Pochita Plush | SEGA | SEGA prize figures site (search "SEGA prize" + name) | [ ] |

### Model Kits

| # | Folder name | Product | Brand | Official source | Done |
|---|---|---|---|---|---|
| 19 | `rg-1-144-rx-78-2-gundam` | RG 1/144 RX-78-2 Gundam | Bandai Spirits | bandai-hobby.net (Gunpla) | [ ] |
| 20 | `hg-1-144-gundam-aerial` | HG 1/144 Gundam Aerial | Bandai Spirits | bandai-hobby.net (Gunpla) | [ ] |
| 21 | `mg-1-100-freedom-gundam-2-0` | MG 1/100 Freedom Gundam 2.0 | Bandai Spirits | bandai-hobby.net (Gunpla) | [ ] |

### TCG Boosters

| # | Folder name | Product | Brand | Official source | Done |
|---|---|---|---|---|---|
| 22 | `one-piece-card-game-booster-box-24-packs` | One Piece Card Game Booster Box (24 packs) | Bandai | Bandai official site / en.onepiece-cardgame.com for One Piece cards | [ ] |
| 23 | `one-piece-card-game-booster-pack` | One Piece Card Game Booster Pack | Bandai | Bandai official site / en.onepiece-cardgame.com for One Piece cards | [ ] |
| 24 | `pokemon-tcg-booster-box-36-packs` | Pokemon TCG Booster Box (36 packs) | The Pokemon Company | pokemoncenter.com | [ ] |
| 25 | `pokemon-tcg-booster-pack` | Pokemon TCG Booster Pack | The Pokemon Company | pokemoncenter.com | [ ] |
| 26 | `pokemon-tcg-elite-trainer-box` | Pokemon TCG Elite Trainer Box | The Pokemon Company | pokemoncenter.com | [ ] |
| 27 | `yu-gi-oh-booster-box-24-packs` | Yu-Gi-Oh! Booster Box (24 packs) | Konami | yugioh-card.com | [ ] |
| 28 | `dragon-ball-super-fusion-world-booster-box` | Dragon Ball Super Fusion World Booster Box | Bandai | Bandai official site / en.onepiece-cardgame.com for One Piece cards | [ ] |

### TCG Starter Decks

| # | Folder name | Product | Brand | Official source | Done |
|---|---|---|---|---|---|
| 29 | `one-piece-card-game-starter-deck-straw-hat-crew` | One Piece Card Game Starter Deck - Straw Hat Crew | Bandai | Bandai official site / en.onepiece-cardgame.com for One Piece cards | [ ] |
| 30 | `yu-gi-oh-structure-deck` | Yu-Gi-Oh! Structure Deck | Konami | yugioh-card.com | [ ] |
| 31 | `pokemon-tcg-battle-deck` | Pokemon TCG Battle Deck | The Pokemon Company | pokemoncenter.com | [ ] |

### TCG Accessories

| # | Folder name | Product | Brand | Official source | Done |
|---|---|---|---|---|---|
| 32 | `dragon-shield-matte-sleeves-100` | Dragon Shield Matte Sleeves (100) | Dragon Shield | dragonshield.com | [ ] |
| 33 | `ultra-pro-deck-box-100` | Ultra Pro Deck Box 100+ | Ultra Pro | ultrapro.com | [ ] |
| 34 | `rubber-playmat-60-x-35-cm` | Rubber Playmat 60 x 35 cm | Ultra Pro | ultrapro.com | [ ] |
| 35 | `9-pocket-card-binder-360-cards` | 9-Pocket Card Binder (360 cards) | Vault X | vaultx.com | [ ] |
