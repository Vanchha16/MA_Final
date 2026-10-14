# Product photos

Official product photos for the demo (downloaded from each brand's own site, see the Source column). **Do not commit them** - `backend/uploads/` is git-ignored
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
| 1 | `p-o-p-sa-maximum-monkey-d-luffy-gear-5-figure` | P.O.P SA-MAXIMUM Monkey D. Luffy Gear 5 Figure | MegaHouse | [link](https://en.megahobby.jp/products/portrait-of-pirates-one-piece-sa-maximum-monkey-d-luffy-gear-5) | [x] |
| 2 | `p-o-p-sa-maximum-roronoa-zoro-three-thousand-worlds-1-8-figure` | P.O.P SA-MAXIMUM Roronoa Zoro Three Thousand Worlds 1/8 Figure | MegaHouse | [link](https://en.megahobby.jp/products/portrait-of-pirates-one-piece-sa-maximum-roronoa-zoro-ver-three-thousand-worlds) | [x] |
| 3 | `rengoku-kyojuro-mugen-train-1-8-scale-figure` | Rengoku Kyojuro Mugen Train 1/8 Scale Figure | Aniplex | [link](https://online.aniplex.co.jp/itemRiDUkGaa.html) | [x] |
| 4 | `satoru-gojo-tokyo-jujutsu-high-school-ver-1-7-figure` | Satoru Gojo Tokyo Jujutsu High School Ver. 1/7 Figure | Good Smile Company | [link](https://www.goodsmile.com/en/product/54549) | [x] |
| 5 | `f-nex-makima-1-7-scale-figure` | F:NEX Makima 1/7 Scale Figure | FuRyu | [link](https://www.furyu.jp/news/2022/10/chainsawman_makima/) | [x] |

### Chibi Figures

| # | Folder name | Product | Brand | Official source | Done |
|---|---|---|---|---|---|
| 6 | `nendoroid-anya-forger` | Nendoroid Anya Forger | Good Smile Company | [link](https://www.goodsmile.info/en/product/12801/Nendoroid+Anya+Forger.html) | [x] |
| 7 | `nendoroid-tanjiro-kamado` | Nendoroid Tanjiro Kamado | Good Smile Company | [link](https://www.goodsmile.com/en/product/6382) | [x] |
| 8 | `nendoroid-yuji-itadori` | Nendoroid Yuji Itadori | Good Smile Company | [link](https://www.goodsmile.com/en/product/7867) | [x] |
| 9 | `nendoroid-ash-pikachu` | Nendoroid Ash & Pikachu | Good Smile Company | [link](https://www.goodsmile.info/en/product/6516/Nendoroid+Ash+Pikachu.html) | [x] |

### Prize Figures

| # | Folder name | Product | Brand | Official source | Done |
|---|---|---|---|---|---|
| 10 | `grandista-son-goku-super-saiyan-prize-figure` | Grandista Son Goku Super Saiyan Prize Figure | Banpresto | [link](https://bsp-prize.jp/item/2739494/) | [x] |
| 11 | `grandista-vegeta-super-saiyan-prize-figure` | Grandista Vegeta Super Saiyan Prize Figure | Banpresto | [link](https://bsp-prize.jp/item/2739496/) | [x] |
| 12 | `memorable-saga-special-naruto-uzumaki-sage-mode-prize-figure` | Memorable Saga Special Naruto Uzumaki Sage Mode Prize Figure | Banpresto | [link](https://bsp-prize.jp/item/2756258/) | [x] |
| 13 | `grandista-uchiha-itachi-prize-figure` | Grandista Uchiha Itachi Prize Figure | Banpresto | [link](https://bsp-prize.jp/item/2735444/) | [x] |
| 14 | `xross-link-nezuko-kamado-prize-figure` | Xross Link Nezuko Kamado Prize Figure | SEGA | [link](https://segaplaza.jp/prize/D120863/) | [x] |

### Plush & Merch

| # | Folder name | Product | Brand | Official source | Done |
|---|---|---|---|---|---|
| 15 | `poke-piece-pikachu-big-plush-28-cm` | Poke Piece Pikachu Big Plush 28 cm | Banpresto | [link](https://bsp-prize.jp/item/2687437/) | [x] |
| 16 | `tony-tony-chopper-plush-sepia-s` | Tony Tony Chopper Plush Sepia (S) | ONE PIECE BASE SHOP | [link](https://baseshop.onepiece-base.com/item/okm7mg5i5ko9) | [x] |

### Prize Figures

| # | Folder name | Product | Brand | Official source | Done |
|---|---|---|---|---|---|
| 17 | `luminasta-anya-forger-summer-vacation-figure` | Luminasta Anya Forger Summer Vacation Figure | SEGA | [link](https://segaplaza.jp/prize/D121860/) | [x] |

### Plush & Merch

| # | Folder name | Product | Brand | Official source | Done |
|---|---|---|---|---|---|
| 18 | `nesoberi-pochita-plush` | Nesoberi Pochita Plush | SEGA | [link](https://segaplaza.jp/prize/B122309/) | [x] |

### Model Kits

| # | Folder name | Product | Brand | Official source | Done |
|---|---|---|---|---|---|
| 19 | `rg-1-144-rx-78-2-gundam-ver-2-0` | RG 1/144 RX-78-2 Gundam Ver.2.0 | Bandai Spirits | [link](https://bandai-hobby.net/item/01_5261/) | [x] |
| 20 | `hg-1-144-gundam-aerial` | HG 1/144 Gundam Aerial | Bandai Spirits | [link](https://bandai-hobby.net/item/01_4257/) | [x] |
| 21 | `mg-1-100-freedom-gundam-ver-2-0` | MG 1/100 Freedom Gundam Ver.2.0 | Bandai Spirits | [link](https://bandai-hobby.net/item/01_542/) | [x] |

### TCG Boosters

| # | Folder name | Product | Brand | Official source | Done |
|---|---|---|---|---|---|
| 22 | `one-piece-card-game-romance-dawn-op-01-booster-box-24-packs` | One Piece Card Game Romance Dawn OP-01 Booster Box (24 packs) | Bandai | [link](https://en.onepiece-cardgame.com/products/boosters/op01.php) | [x] |
| 23 | `one-piece-card-game-romance-dawn-op-01-booster-pack` | One Piece Card Game Romance Dawn OP-01 Booster Pack | Bandai | [link](https://en.onepiece-cardgame.com/products/boosters/op01.php) | [x] |
| 24 | `pokemon-tcg-battle-partners-booster-box-30-packs` | Pokemon TCG Battle Partners Booster Box (30 packs) | The Pokemon Company | [link](https://www.pokemon-card.com/ex/sv9/index.html) | [x] |
| 25 | `pokemon-tcg-battle-partners-booster-pack` | Pokemon TCG Battle Partners Booster Pack | The Pokemon Company | [link](https://www.pokemon-card.com/ex/sv9/index.html) | [x] |
| 26 | `pokemon-tcg-deck-build-box-battle-partners` | Pokemon TCG Deck Build Box Battle Partners | The Pokemon Company | [link](https://www.pokemon-card.com/ex/sv9/index.html) | [x] |
| 27 | `yu-gi-oh-revolution-booster-box` | Yu-Gi-Oh! Revolution Booster Box | Konami | [link](https://www.yugioh-card.com/japan/products/rv01/) | [x] |
| 28 | `dragon-ball-super-fusion-world-awakened-pulse-fb01-booster-box` | Dragon Ball Super Fusion World Awakened Pulse FB01 Booster Box | Bandai | [link](https://www.dbs-cardgame.com/fw/en/products/01_5.html) | [x] |

### TCG Starter Decks

| # | Folder name | Product | Brand | Official source | Done |
|---|---|---|---|---|---|
| 29 | `one-piece-card-game-starter-deck-straw-hat-crew-st-01` | One Piece Card Game Starter Deck Straw Hat Crew ST-01 | Bandai | [link](https://en.onepiece-cardgame.com/products/decks/st01-04.php) | [x] |
| 30 | `yu-gi-oh-structure-deck-power-of-the-fellows` | Yu-Gi-Oh! Structure Deck Power of the Fellows | Konami | [link](https://www.yugioh-card.com/japan/products/sd48/) | [x] |
| 31 | `pokemon-tcg-start-deck-generations` | Pokemon TCG Start Deck Generations | The Pokemon Company | [link](https://www.pokemon-card.com/ex/svm/index.html) | [x] |

### TCG Accessories

| # | Folder name | Product | Brand | Official source | Done |
|---|---|---|---|---|---|
| 32 | `dragon-shield-matte-sleeves-black-100` | Dragon Shield Matte Sleeves Black (100) | Dragon Shield | [link](https://www.dragonshield.com/products/black-matte-sleeves) | [x] |
| 33 | `ultra-pro-eclipse-pro-100-deck-box` | Ultra PRO Eclipse PRO 100+ Deck Box | Ultra Pro | [link](https://ultrapro.com/products/eclipse-pro-100-deck-box) | [x] |
| 34 | `ultra-pro-black-stitched-playmat-starfield` | Ultra PRO Black Stitched Playmat Starfield | Ultra Pro | https://ultrapro.com (Edge of Eternities Black Stitched Playmat - Starfield Maestros) | [x] |
| 35 | `vault-x-9-pocket-exo-tec-zip-binder-360-cards` | Vault X 9-Pocket Exo-Tec Zip Binder (360 cards) | Vault X | [link](https://us.vaultx.com/products/9-pocket-exo-tec-zip-binder) | [x] |
