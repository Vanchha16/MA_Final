import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/format.dart';
import '../models/catalog.dart';
import 'cart_fly.dart';
import 'product_image.dart';

/// Grid card used everywhere products are listed (Figma: Product Card):
/// photo with sale badge, wishlist heart and series tag, then brand, name,
/// price (old price struck through) and a solid round add-to-cart button.
class ProductCard extends StatefulWidget {
  /// Height of everything below the square photo, at normal text size.
  static const double infoHeight = 118;

  final Product product;
  final bool wishlisted;
  final VoidCallback? onTap;
  final VoidCallback? onToggleWishlist;

  /// Returns when the item is in the cart; throw to keep the plus icon.
  final Future<void> Function()? onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    this.wishlisted = false,
    this.onTap,
    this.onToggleWishlist,
    this.onAddToCart,
  });

  /// Shared with Product Details so the photo animates between the two.
  static String heroTag(int productId) => 'product-photo-$productId';

  /// Grid row height for a card of [width], so photos stay square.
  static double heightFor(double width, TextScaler scaler) => width - 16 + 8 + scaler.scale(infoHeight);

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  final _photo = GlobalKey();
  bool _adding = false;
  bool _added = false;

  Future<void> _add() async {
    if (_adding || widget.onAddToCart == null) return;
    setState(() => _adding = true);
    try {
      await widget.onAddToCart!();
      if (!mounted) return;
      final photo = _photo.currentContext;
      if (photo != null && photo.mounted) CartFly.run(photo, widget.product);
      setState(() => _added = true);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) setState(() => _added = false);
    } catch (_) {
      // The caller already showed the reason.
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? scheme.primary : AppTheme.primaryDark;
    final cardColor = dark ? scheme.surfaceContainer : Colors.white;

    return Semantics(
      container: true,
      label: '${p.name}, ${formatPrice(p.finalPrice)}${p.soldOut ? ', sold out' : ''}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6)),
          ],
        ),
        child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('product_${p.id}'),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  key: _photo,
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(tag: ProductCard.heroTag(p.id), child: ProductImage(url: p.imageUrl, kind: p.category.kind)),
                      if (p.soldOut)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(child: _Tag('Sold out', background: Colors.white, foreground: Color(0xFF0F172A))),
                        ),
                      if (p.onSale && !p.soldOut)
                        Positioned(left: 8, top: 8, child: _Tag('-${p.discountPercent}%', background: AppTheme.coral, foreground: Colors.white)),
                      if (p.series != null)
                        Positioned(
                          left: 8,
                          bottom: 8,
                          right: 8,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _Tag(p.series!.name, background: Colors.white.withValues(alpha: 0.88), foreground: AppTheme.primaryDark, small: true),
                          ),
                        ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: _HeartButton(key: Key('heart_${p.id}'), on: widget.wishlisted, onTap: widget.onToggleWishlist),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.brand ?? p.category.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      // Always two lines tall so prices line up across the row
                      SizedBox(
                        height: MediaQuery.textScalerOf(context).scale(13 * 1.38 * 2),
                        child: Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, height: 1.38, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Prices take the free space, so the button always sits at the right edge
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(formatPrice(p.finalPrice),
                                      maxLines: 1, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accent)),
                                ),
                                if (p.onSale) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      formatPrice(p.price),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant,
                                        decoration: TextDecoration.lineThrough,
                                        decorationColor: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _AddButton(
                            key: Key('add_${p.id}'),
                            enabled: !p.soldOut,
                            busy: _adding && !_added,
                            done: _added,
                            onTap: _add,
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
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color background, foreground;
  final bool small;

  const _Tag(this.text, {required this.background, required this.foreground, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: small ? 3 : 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: foreground, fontSize: small ? 10 : 11, fontWeight: small ? FontWeight.w600 : FontWeight.bold),
      ),
    );
  }
}

class _HeartButton extends StatelessWidget {
  final bool on;
  final VoidCallback? onTap;

  const _HeartButton({super.key, required this.on, this.onTap});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: on ? 'Remove from wishlist' : 'Add to wishlist',
          child: SizedBox.square(
            dimension: 32,
            child: AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
              transitionBuilder: (child, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: child),
              child: Icon(
                on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey(on),
                size: 18,
                color: AppTheme.coral,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final bool enabled, busy, done;
  final VoidCallback onTap;

  const _AddButton({super.key, required this.enabled, required this.busy, required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bg = !enabled ? scheme.surfaceContainerHighest : (done ? AppTheme.success : AppTheme.primaryDark);
    return Tooltip(
      message: enabled ? 'Add to cart' : 'Sold out',
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox.square(
            dimension: 32,
            child: AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
              child: busy
                  ? const Padding(
                      key: ValueKey('busy'),
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      done ? Icons.check_rounded : Icons.add_rounded,
                      key: ValueKey(done),
                      size: 18,
                      color: enabled ? Colors.white : scheme.onSurfaceVariant,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmering card shape shown while products load.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(color: dark ? scheme.surfaceContainer : Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Shimmer.fromColors(
        enabled: !reduceMotion,
        baseColor: dark ? scheme.surfaceContainerHighest : const Color(0xFFE8F1FA),
        highlightColor: dark ? scheme.surfaceContainerHigh : const Color(0xFFF7FBFF),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
            ),
            const SizedBox(height: 10),
            bar(70, 10),
            const SizedBox(height: 8),
            bar(double.infinity, 12),
            const SizedBox(height: 6),
            bar(100, 12),
            const Spacer(),
            Row(children: [bar(48, 16), const Spacer(), Container(width: 32, height: 32, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))]),
          ],
        ),
      ),
    );
  }
}
