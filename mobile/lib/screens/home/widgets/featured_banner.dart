import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../models/catalog.dart';
import '../../../widgets/product_image.dart';
import '../../../widgets/sparkle.dart';

/// Swipeable promo banner built from featured products (Figma: Promo
/// Banner). Moves to the next slide every 5 s unless "reduce motion" is on.
class FeaturedBanner extends StatefulWidget {
  final List<Product> products;
  final ValueChanged<Product> onTap;

  const FeaturedBanner({super.key, required this.products, required this.onTap});

  @override
  State<FeaturedBanner> createState() => _FeaturedBannerState();
}

class _FeaturedBannerState extends State<FeaturedBanner> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!reduceMotion && widget.products.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_controller.hasClients) return;
        final next = (_page + 1) % widget.products.length;
        _controller.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.products.length;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: 124,
          child: PageView.builder(
            controller: _controller,
            itemCount: count,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _Slide(product: widget.products[i], onTap: () => widget.onTap(widget.products[i])),
          ),
        ),
        if (count > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? scheme.primary : scheme.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Slide extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _Slide({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final chip = p.onSale ? 'SAVE ${p.discountPercent}%' : (p.soldOut ? 'COMING BACK' : 'FEATURED');
    final subtitle = p.onSale ? 'Now ${formatPrice(p.finalPrice)}, was ${formatPrice(p.price)}' : '${p.series?.name ?? p.category.name}  ·  ${formatPrice(p.price)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.cardStart, AppTheme.cardEnd]),
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned(
                  right: -24,
                  top: -26,
                  child: Transform.rotate(
                    angle: -12 * math.pi / 180,
                    child: Opacity(opacity: 0.16, child: Image.asset('assets/logo_centered.png', width: 150)),
                  ),
                ),
                const Positioned(right: 110, top: 14, child: Sparkle(size: 12, color: Color(0xB3FFFFFF))),
                const Positioned(right: 18, bottom: 16, child: Sparkle(size: 9, color: Color(0xFFFBBF24))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppTheme.amber, borderRadius: BorderRadius.circular(10)),
                              child: Text(chip,
                                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            ),
                            const SizedBox(height: 6),
                            Text(p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.25, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(subtitle,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFE0F2FE), fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox.square(
                        dimension: 84,
                        child: ProductImage(
                          url: p.imageUrl,
                          kind: p.category.kind,
                          iconSize: 40,
                          borderRadius: BorderRadius.circular(20),
                        ),
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
