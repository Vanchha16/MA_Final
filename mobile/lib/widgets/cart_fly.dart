import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/catalog.dart';
import 'product_image.dart';

/// Flies a product photo into the cart button on the same screen, then
/// bounces that button (Figma: Add to cart C - Toast + flying photo).
///
/// Every [CartButton] registers itself here; the photo goes to the one on
/// the screen the user is looking at. Screens without a cart button (and
/// reduce-motion users) only get the "Added to cart" toast.
class CartFly {
  static final _targets = <GlobalKey, VoidCallback>{};

  static const duration = Duration(milliseconds: 700);

  /// How many photos reached a cart button (for tests).
  @visibleForTesting
  static int landings = 0;

  static void register(GlobalKey key, VoidCallback onLand) => _targets[key] = onLand;

  static void unregister(GlobalKey key) => _targets.remove(key);

  /// The cart button on the same page as [from] that is on screen right now
  /// (not a hidden tab, not scrolled away).
  static GlobalKey? _targetFor(BuildContext from, Rect screen) {
    final route = ModalRoute.of(from);
    for (final key in _targets.keys.toList().reversed) {
      final context = key.currentContext;
      if (context == null || ModalRoute.of(context) != route || !Visibility.of(context)) continue;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !screen.contains(box.localToGlobal(box.size.center(Offset.zero)))) continue;
      return key;
    }
    return null;
  }

  /// Starts the flight from the photo at [from] and returns right away.
  static void run(BuildContext from, Product product) {
    if (MediaQuery.maybeDisableAnimationsOf(from) ?? false) return;
    final source = from.findRenderObject() as RenderBox?;
    if (source == null || !source.attached) return;
    final overlay = Overlay.maybeOf(from, rootOverlay: true);
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    if (overlay == null || overlayBox == null) return;

    final target = _targetFor(from, Offset.zero & overlayBox.size);
    if (target == null) return;
    final targetBox = target.currentContext!.findRenderObject() as RenderBox;

    final size = math.min(source.size.shortestSide, 120.0);
    final start = overlayBox.globalToLocal(source.localToGlobal(source.size.center(Offset.zero)));
    final end = overlayBox.globalToLocal(targetBox.localToGlobal(targetBox.size.center(Offset.zero)));
    final travel = end - start;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: start.dx - size / 2,
        top: start.dy - size / 2,
        width: size,
        height: size,
        child: IgnorePointer(
          child: DecoratedBox(
            key: const Key('cart_fly'),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.30), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: ClipOval(child: ProductImage(url: product.imageUrl, kind: product.category.kind, iconSize: size * 0.4)),
          )
              // Scale first so the moves below are not scaled with it.
              .animate(
                onComplete: (_) {
                  entry.remove();
                  landings++;
                  _targets[target]?.call();
                },
              )
              .scaleXY(begin: 1, end: 28 / size, duration: duration, curve: Curves.easeInCubic)
              // x eases in while y eases out, so the photo curves up and over
              .moveX(end: travel.dx, duration: duration, curve: Curves.easeInSine)
              .moveY(end: travel.dy, duration: duration, curve: Curves.easeOutCubic)
              .fadeOut(delay: duration * 0.8, duration: duration * 0.2),
        ),
      ),
    );
    overlay.insert(entry);
  }
}
