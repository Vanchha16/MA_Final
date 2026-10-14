import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/format.dart';
import '../models/cart.dart';
import '../models/catalog.dart';
import 'pill_button.dart';
import 'product_image.dart';

/// "Added to your cart" sheet after Add to cart on Product Details
/// (Figma: Add to cart A - Added sheet): what was added, the cart size and
/// total, how close the cart is to free delivery, Keep shopping / View cart.
/// Returns true when View cart is tapped.
Future<bool?> showAddedToCartSheet(BuildContext context, {required Product product, required int quantity, required Cart cart}) {
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _AddedSheet(product: product, quantity: quantity, cart: cart),
  );
}

class _AddedSheet extends StatelessWidget {
  final Product product;
  final int quantity;
  final Cart cart;

  const _AddedSheet({required this.product, required this.quantity, required this.cart});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? scheme.primary : AppTheme.primaryDark;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final items = '${cart.count} ${cart.count == 1 ? 'item' : 'items'}';

    Widget check = Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
    );
    if (!reduceMotion) check = check.animate().scaleXY(begin: 0.4, duration: 320.ms, curve: Curves.easeOutBack);

    return Padding(
      key: const Key('added_sheet'),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              check,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Added to your cart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      '$items · ${formatPrice(cart.subtotal)} in your cart',
                      key: const Key('added_sheet_summary'),
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: dark ? scheme.surfaceContainerHigh : const Color(0xFFF6F9FE),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 60,
                  child: ProductImage(url: product.imageUrl, kind: product.category.kind, iconSize: 26, borderRadius: BorderRadius.circular(14)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: formatPrice(product.finalPrice), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: accent)),
                          TextSpan(text: '  ×  $quantity', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _FreeDelivery(cart: cart),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: PillButton(
                  key: const Key('added_sheet_keep'),
                  label: 'Keep shopping',
                  color: dark ? scheme.surfaceContainerHighest : AppTheme.skyTint,
                  foregroundColor: accent,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PillButton(
                  key: const Key('added_sheet_view'),
                  label: 'View cart',
                  leadingIcon: Icons.shopping_cart_rounded,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "You get FREE delivery" (green, full bar) or "Add $X more for free delivery".
class _FreeDelivery extends StatelessWidget {
  final Cart cart;

  const _FreeDelivery({required this.cart});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final free = cart.toFreeShipping == 0;
    final color = free ? AppTheme.success : (Theme.of(context).brightness == Brightness.dark ? scheme.primary : AppTheme.primaryDark);
    final progress = free ? 1.0 : (cart.subtotal / cart.freeShippingMin).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_shipping_outlined, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                free ? 'You get FREE delivery' : 'Add ${formatPrice(cart.toFreeShipping)} more for free delivery',
                key: const Key('added_sheet_delivery'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
          color: color,
          backgroundColor: color.withValues(alpha: 0.15),
        ),
      ],
    );
  }
}
