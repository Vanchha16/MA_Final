import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/catalog.dart';

/// Product photo, or a soft tinted tile with an icon for the product type
/// while there is no photo yet (or it fails to load).
class ProductImage extends StatelessWidget {
  final String? url;
  final ProductKind kind;
  final double iconSize;
  final BorderRadius borderRadius;

  const ProductImage({
    super.key,
    required this.url,
    required this.kind,
    this.iconSize = 56,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  static const _base = {
    ProductKind.figure: Color(0xFF0EA5E9),
    ProductKind.plush: Color(0xFFF43F5E),
    ProductKind.kit: Color(0xFF64748B),
    ProductKind.tcg: Color(0xFFF59E0B),
  };

  static const _icon = {
    ProductKind.figure: Icons.auto_awesome_rounded,
    ProductKind.plush: Icons.favorite_rounded,
    ProductKind.kit: Icons.precision_manufacturing_rounded,
    ProductKind.tcg: Icons.style_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder(kind: kind, iconSize: iconSize);
    return ClipRRect(
      borderRadius: borderRadius,
      child: url == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => placeholder,
            ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final ProductKind kind;
  final double iconSize;

  const _Placeholder({required this.kind, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = ProductImage._base[kind]!;
    final surface = dark ? scheme.surfaceContainerHigh : Colors.white;
    Color tint(double a) => Color.alphaBlend(base.withValues(alpha: a), surface);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark ? [tint(0.16), tint(0.30)] : [tint(0.12), tint(0.28)],
        ),
      ),
      child: Center(
        child: Icon(ProductImage._icon[kind], size: iconSize, color: base.withValues(alpha: dark ? 0.75 : 0.55)),
      ),
    );
  }
}
