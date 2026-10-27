import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../helpers/format.dart';
import '../../../models/catalog.dart';

/// Small pieces shared by the three wishlist views.

/// Sum of today's prices.
double wishTotal(Iterable<Product> items) => items.fold(0, (s, p) => s + p.finalPrice);

/// How much the sale prices save compared with the normal prices.
double wishSavings(Iterable<Product> items) => items.fold(0, (s, p) => s + (p.price - p.finalPrice));

class WishTag extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  final bool small;

  const WishTag(this.text, {super.key, required this.background, this.foreground = Colors.white, this.small = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 7 : 9, vertical: small ? 3 : 4),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: foreground, fontSize: small ? 10 : 11, fontWeight: FontWeight.bold)),
      );
}

/// Today's price, with the old one struck through when on sale.
class WishPrice extends StatelessWidget {
  final Product product;
  final double size;

  const WishPrice({super.key, required this.product, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = Theme.of(context).brightness == Brightness.dark ? scheme.primary : AppTheme.primaryDark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(child: Text(formatPrice(product.finalPrice), maxLines: 1, style: TextStyle(fontSize: size, fontWeight: FontWeight.bold, color: accent))),
        if (product.onSale) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              formatPrice(product.price),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, decoration: TextDecoration.lineThrough, decorationColor: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }
}

/// "In stock", "Only 2 left" or "Sold out".
class StockLabel extends StatelessWidget {
  final Product product;

  const StockLabel({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = product;
    final (IconData icon, String text, Color color) = p.soldOut
        ? (Icons.block_rounded, 'Sold out', AppTheme.danger)
        : p.stock <= 5
            ? (Icons.local_fire_department_rounded, 'Only ${p.stock} left', dark ? AppTheme.amber : const Color(0xFFB45309))
            : (Icons.check_circle_rounded, 'In stock', AppTheme.success);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

/// Dark layer over a sold-out photo, optionally with a "Sold out" tag.
class SoldOutVeil extends StatelessWidget {
  final double radius;
  final bool label;

  const SoldOutVeil({super.key, this.radius = 16, this.label = true});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xFF0F172A).withValues(alpha: 0.45), borderRadius: BorderRadius.circular(radius)),
        child: label ? const Center(child: WishTag('Sold out', background: Colors.white, foreground: Color(0xFF0F172A))) : null,
      );
}

/// White circle with a filled red heart; tapping it removes the item.
class WishHeart extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const WishHeart({super.key, required this.onTap, this.size = 32});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Remove from wishlist',
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: Colors.black26,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(dimension: size, child: Icon(Icons.favorite_rounded, color: AppTheme.coral, size: size * 0.56)),
          ),
        ),
      );
}
