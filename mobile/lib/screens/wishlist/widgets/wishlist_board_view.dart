import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../models/catalog.dart';
import '../../../widgets/product_image.dart';
import '../../shop/shop_actions.dart';
import 'wishlist_parts.dart';

enum _BoardTab { all, sale, soldOut }

/// Board view (Figma: Wishlist C - Collection board): a "saved for later"
/// total, All / On sale / Sold out tabs and a Pinterest-style grid of tall
/// and short cards. The heart removes (with Undo); the cart button adds one
/// to the cart and keeps the item saved.
class WishlistBoardView extends StatefulWidget {
  final List<Product> items;
  final ValueChanged<Product> onRemove, onOpen;
  final Future<void> Function() onRefresh;

  const WishlistBoardView({super.key, required this.items, required this.onRemove, required this.onOpen, required this.onRefresh});

  @override
  State<WishlistBoardView> createState() => _WishlistBoardViewState();
}

class _WishlistBoardViewState extends State<WishlistBoardView> {
  _BoardTab _tab = _BoardTab.all;

  List<Product> get _shown => switch (_tab) {
        _BoardTab.all => widget.items,
        _BoardTab.sale => widget.items.where((p) => p.onSale && !p.soldOut).toList(),
        _BoardTab.soldOut => widget.items.where((p) => p.soldOut).toList(),
      };

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        key: const Key('board_list'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            sliver: SliverList.list(children: [
              _Summary(items: widget.items),
              const SizedBox(height: 14),
              _Tabs(value: _tab, items: widget.items, onChanged: (t) => setState(() => _tab = t)),
            ]),
          ),
          if (shown.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _tab == _BoardTab.sale ? 'None of your saved items are on sale right now.' : 'Everything you saved is in stock.',
                  key: const Key('board_tab_empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childCount: shown.length,
                // Tall, short, short, tall... so the two columns stagger
                itemBuilder: (context, i) => _Tile(
                  key: Key('board_tile_${shown[i].id}'),
                  product: shown[i],
                  tall: i % 4 == 0 || i % 4 == 3,
                  onRemove: () => widget.onRemove(shown[i]),
                  onOpen: () => widget.onOpen(shown[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Saved for later $646 · 6 items · 4 on sale · save $48" with three photos.
class _Summary extends StatelessWidget {
  final List<Product> items;

  const _Summary({required this.items});

  @override
  Widget build(BuildContext context) {
    final onSale = items.where((p) => p.onSale).length;
    final savings = wishSavings(items);
    return Container(
      key: const Key('board_summary'),
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.cardStart, AppTheme.cardEnd]),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SAVED FOR LATER', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(formatPrice(wishTotal(items)), key: const Key('board_total'), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                Text(
                  [
                    '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                    if (onSale > 0) '$onSale on sale',
                    if (savings > 0) 'save ${formatPrice(savings)}',
                  ].join(' · '),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 48 + 26.0 * (items.take(3).length - 1),
            height: 52,
            child: Stack(
              children: [
                for (final (i, p) in items.take(3).indexed)
                  Positioned(
                    left: i * 26.0,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: SizedBox.square(
                        dimension: 44,
                        child: ProductImage(url: p.imageUrl, kind: p.category.kind, iconSize: 18, borderRadius: BorderRadius.circular(22)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final _BoardTab value;
  final List<Product> items;
  final ValueChanged<_BoardTab> onChanged;

  const _Tabs({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? scheme.primary : AppTheme.primaryDark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: dark ? scheme.surfaceContainerHigh : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          for (final (tab, label) in [(_BoardTab.all, 'All'), (_BoardTab.sale, 'On sale'), (_BoardTab.soldOut, 'Sold out')])
            Expanded(
              child: GestureDetector(
                key: Key('board_tab_${tab.name}'),
                onTap: () => onChanged(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tab == value ? (dark ? scheme.surfaceContainerHighest : Colors.white) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [if (tab == value && !dark) BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
                  ),
                  child: Text(label,
                      style: TextStyle(fontWeight: tab == value ? FontWeight.bold : FontWeight.w500, color: tab == value ? accent : scheme.onSurfaceVariant)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatefulWidget {
  final Product product;
  final bool tall;
  final VoidCallback onRemove, onOpen;

  const _Tile({super.key, required this.product, required this.tall, required this.onRemove, required this.onOpen});

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _adding = false;

  Future<void> _add() async {
    setState(() => _adding = true);
    try {
      await ShopActions.addToCart(context, widget.product);
    } catch (_) {
      // ShopActions already showed the reason
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: dark ? scheme.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: widget.tall ? 0.8 : 1.15,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductImage(url: p.imageUrl, kind: p.category.kind, iconSize: 44, borderRadius: BorderRadius.zero),
                    if (p.soldOut) const SoldOutVeil(radius: 0),
                    if (p.onSale && !p.soldOut)
                      Positioned(left: 10, top: 10, child: WishTag('Save ${formatPrice(p.price - p.finalPrice)}', background: AppTheme.coral)),
                    Positioned(right: 8, top: 8, child: WishHeart(key: Key('board_heart_${p.id}'), size: 30, onTap: widget.onRemove)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: WishPrice(product: p, size: 15)),
                        IconButton.filled(
                          key: Key('board_add_${p.id}'),
                          tooltip: p.soldOut ? 'Sold out' : 'Add to cart',
                          onPressed: p.soldOut || _adding ? null : _add,
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.primaryDark,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: dark ? scheme.surfaceContainerHighest : const Color(0xFFE2E8F0),
                            fixedSize: const Size(36, 36),
                            minimumSize: const Size(36, 36),
                            padding: EdgeInsets.zero,
                          ),
                          icon: _adding
                              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.add_shopping_cart_rounded, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
