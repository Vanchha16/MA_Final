import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/format.dart';
import '../models/catalog.dart';
import 'product_card.dart';
import 'product_image.dart';

/// One product as a row (List view on the Product List): photo on the left,
/// series, name, rating and price on the right, heart and add-to-cart.
class ProductTile extends StatelessWidget {
  final Product product;
  final bool wishlisted;
  final VoidCallback? onTap;
  final VoidCallback? onToggleWishlist;
  final Future<void> Function()? onAddToCart;

  const ProductTile({
    super.key,
    required this.product,
    this.wishlisted = false,
    this.onTap,
    this.onToggleWishlist,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? scheme.primary : AppTheme.primaryDark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: Material(
        color: dark ? scheme.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('product_${p.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: 104,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(tag: ProductCard.heroTag(p.id), child: ProductImage(url: p.imageUrl, kind: p.category.kind, iconSize: 40, borderRadius: BorderRadius.circular(14))),
                      if (p.soldOut)
                        DecoratedBox(
                          decoration: BoxDecoration(color: const Color(0x730F172A), borderRadius: BorderRadius.circular(14)),
                          child: const Center(
                            child: Text('Sold out', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      if (p.onSale && !p.soldOut)
                        Positioned(
                          left: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.coral, borderRadius: BorderRadius.circular(8)),
                            child: Text('-${p.discountPercent}%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (p.series?.name ?? p.category.name).toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold, color: accent),
                            ),
                          ),
                          InkWell(
                            key: Key('heart_${p.id}'),
                            customBorder: const CircleBorder(),
                            onTap: onToggleWishlist,
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                wishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 20,
                                color: AppTheme.coral,
                                semanticLabel: wishlisted ? 'Remove from wishlist' : 'Add to wishlist',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.3, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          RatingBarIndicator(
                            rating: p.rating,
                            itemCount: 5,
                            itemSize: 13,
                            unratedColor: scheme.outlineVariant,
                            itemBuilder: (_, _) => const Icon(Icons.star_rounded, color: AppTheme.amber),
                          ),
                          const SizedBox(width: 4),
                          Text(p.reviewCount == 0 ? 'New' : '(${p.reviewCount})', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Text(formatPrice(p.finalPrice), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accent)),
                                if (p.onSale)
                                  Text(
                                    formatPrice(p.price),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: scheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _AddButton(key: Key('add_${p.id}'), enabled: !p.soldOut, onAdd: onAddToCart),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  final bool enabled;
  final Future<void> Function()? onAdd;

  const _AddButton({super.key, required this.enabled, this.onAdd});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _busy = false;

  Future<void> _add() async {
    if (_busy || widget.onAdd == null) return;
    setState(() => _busy = true);
    try {
      await widget.onAdd!();
    } catch (_) {
      // The caller already showed why
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filled(
      tooltip: widget.enabled ? 'Add to cart' : 'Sold out',
      onPressed: widget.enabled && !_busy ? _add : null,
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        disabledBackgroundColor: scheme.surfaceContainerHighest,
        fixedSize: const Size(34, 34),
        minimumSize: const Size(34, 34),
        padding: EdgeInsets.zero,
      ),
      icon: _busy
          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.add_rounded, size: 20),
    );
  }
}
