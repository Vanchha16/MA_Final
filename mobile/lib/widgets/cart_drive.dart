import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/app_theme.dart';
import '../models/catalog.dart';
import 'product_image.dart';

/// "Delivery cart" add-to-cart animation (picked from the drop previews, J):
/// a little cart drives in under the product, the photo hops into it, then
/// it drives off into the Cart tab (or the cart button on screens without
/// the tab bar), which bounces when it arrives.
///
/// [CartTabIcon] and [CartButton] register themselves as places to drive to;
/// the tab wins when both are on screen. With no target the cart drives off
/// the right edge. Reduce-motion users only get the "Added to cart" toast.
class CartDrive {
  static final _targets = <GlobalKey, ({int priority, VoidCallback onArrive})>{};

  static const duration = Duration(milliseconds: 1400);

  static int _driving = 0;
  static final _whenIdle = <VoidCallback>[];

  /// Runs [callback] once no cart is driving (right away if none is).
  static void whenIdle(VoidCallback callback) => _driving == 0 ? callback() : _whenIdle.add(callback);

  static void _finished() {
    _driving--;
    if (_driving > 0) return;
    final callbacks = [..._whenIdle];
    _whenIdle.clear();
    for (final callback in callbacks) {
      callback();
    }
  }

  /// How many carts reached a target (for tests).
  @visibleForTesting
  static int arrivals = 0;

  /// Higher [priority] is picked first (the Cart tab uses 1, buttons 0).
  static void register(GlobalKey key, VoidCallback onArrive, {int priority = 0}) =>
      _targets[key] = (priority: priority, onArrive: onArrive);

  static void unregister(GlobalKey key) => _targets.remove(key);

  /// A registered target on the same page as [from] that is on screen now
  /// (not in a hidden tab, not scrolled away).
  static GlobalKey? _targetFor(BuildContext from, Rect screen) {
    final route = ModalRoute.of(from);
    GlobalKey? best;
    var bestPriority = -1;
    for (final MapEntry(:key, :value) in _targets.entries) {
      final context = key.currentContext;
      if (context == null || ModalRoute.of(context) != route || !Visibility.of(context)) continue;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !screen.contains(box.localToGlobal(box.size.center(Offset.zero)))) continue;
      if (value.priority > bestPriority) {
        best = key;
        bestPriority = value.priority;
      }
    }
    return best;
  }

  /// Starts the animation for the product whose photo is at [photo] inside
  /// the card at [card], and returns right away.
  static void run({required BuildContext photo, required BuildContext card, required Product product}) {
    if (MediaQuery.maybeDisableAnimationsOf(photo) ?? false) return;
    final photoBox = photo.findRenderObject() as RenderBox?;
    final cardBox = card.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(photo, rootOverlay: true);
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    if (photoBox == null || cardBox == null || overlay == null || overlayBox == null || !photoBox.attached || !cardBox.attached) return;

    Offset local(RenderBox box, Offset point) => overlayBox.globalToLocal(box.localToGlobal(point));
    final screen = Offset.zero & overlayBox.size;
    final target = _targetFor(photo, screen);
    final targetBox = target?.currentContext?.findRenderObject() as RenderBox?;

    final photoCenter = local(photoBox, photoBox.size.center(Offset.zero));
    final cardBottom = local(cardBox, cardBox.size.bottomLeft(Offset.zero)).dy;
    // The cart drives along a "road" just under the card, kept above the tab bar.
    final road = math.min(cardBottom + 26, screen.height - 110);
    final path = _Path(
      enter: Offset(-40, road),
      stop: Offset(photoCenter.dx, road),
      photo: photoCenter,
      photoSize: math.min(photoBox.size.shortestSide, 110),
      end: targetBox == null ? Offset(screen.width + 60, road) : local(targetBox, targetBox.size.center(Offset.zero)),
      shrink: targetBox != null,
    );

    _driving++;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: IgnorePointer(
          child: _DriveHost(
            onDone: () {
              if (target != null) {
                arrivals++;
                _targets[target]?.onArrive();
              }
              entry.remove();
            },
            builder: (finish) => Animate(
              onComplete: (_) => finish(),
              effects: [
                CustomEffect(duration: duration, builder: (context, t, _) => _DriveFrame(path: path, product: product, t: t)),
              ],
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
  }
}

/// Ends the drive exactly once: when it arrives, or if the overlay goes
/// away first (e.g. the app is closed), so [CartDrive.whenIdle] never hangs.
class _DriveHost extends StatefulWidget {
  final VoidCallback onDone;

  /// Builds the animation; it calls the given function when it arrives.
  final Widget Function(VoidCallback finish) builder;

  const _DriveHost({required this.onDone, required this.builder});

  @override
  State<_DriveHost> createState() => _DriveHostState();
}

class _DriveHostState extends State<_DriveHost> {
  bool _done = false;

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
    CartDrive._finished();
  }

  @override
  void dispose() {
    if (!_done) {
      _done = true;
      CartDrive._finished();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_finish);
}

/// Where the cart and the photo go, in overlay coordinates.
class _Path {
  final Offset enter, stop, photo, end;
  final double photoSize;

  /// Shrink into the target (false when driving off the screen).
  final bool shrink;

  const _Path({required this.enter, required this.stop, required this.photo, required this.photoSize, required this.end, required this.shrink});
}

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
double _lerp(double a, double b, double u) => a + (b - a) * u;
double _bump(double u) => u <= 0 || u >= 1 ? 0 : math.sin(math.pi * u);

/// One frame at [t] (0-1): drive in (0-0.25), photo hops in (0.2-0.48),
/// the cart bounces with its load (0.48-0.58), drives to the target (0.58-1).
class _DriveFrame extends StatelessWidget {
  final _Path path;
  final Product product;
  final double t;

  const _DriveFrame({required this.path, required this.product, required this.t});

  static const _cartSize = 46.0;

  Widget _photo(double size) => SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 5))],
          ),
          child: ClipOval(child: ProductImage(url: product.imageUrl, kind: product.category.kind, iconSize: size * 0.45)),
        ),
      );

  Widget _at(Offset c, double w, Widget child, [double? h]) =>
      Positioned(left: c.dx - w / 2, top: c.dy - (h ?? w) / 2, width: w, height: h ?? w, child: child);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = Theme.of(context).brightness == Brightness.dark ? scheme.primary : AppTheme.primaryDark;
    final children = <Widget>[];

    // The photo hops out of the card and drops into the cart.
    final hop = _seg(t, 0.2, 0.48);
    if (hop > 0 && hop < 1) {
      final x = _lerp(path.photo.dx, path.stop.dx, hop);
      final y = _lerp(path.photo.dy, path.stop.dy - 14, hop * hop) - 70 * _bump(hop) * (1 - hop * 0.4);
      final s = _lerp(path.photoSize, _cartSize * 0.5, Curves.easeOut.transform(hop));
      children.add(_at(Offset(x, y), s, _photo(s)));
    }

    Offset c;
    var size = _cartSize, tilt = 0.0, opacity = 1.0;
    var loaded = false, lines = false;
    if (t < 0.25) {
      final e = Curves.easeOutCubic.transform(_seg(t, 0, 0.25));
      c = Offset.lerp(path.enter, path.stop, e)!;
      tilt = 0.08 * (1 - e);
      lines = e < 0.9;
    } else if (t < 0.58) {
      c = path.stop;
      size = _cartSize * (1 + 0.08 * _bump(_seg(t, 0.48, 0.58)));
      loaded = t >= 0.48;
    } else {
      final u = _seg(t, 0.58, 1);
      final e = Curves.easeInCubic.transform(u);
      c = Offset.lerp(path.stop, path.end, e)!;
      if (path.shrink) {
        size = _lerp(_cartSize, 20, e);
        opacity = _lerp(1, 0.6, e);
      }
      tilt = -0.12 * _bump(_seg(t, 0.58, 0.75)); // a little wheelie when it sets off
      loaded = true;
      lines = true;
    }

    if (lines) {
      for (var k = 0; k < 3; k++) {
        children.add(Positioned(
          left: c.dx - size / 2 - 18 - k * 4,
          top: c.dy - size * 0.15 + k * 7,
          width: 14 - k * 3.0,
          height: 2.5,
          child: DecoratedBox(decoration: BoxDecoration(color: color.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2))),
        ));
      }
    }
    children.add(_at(
      c,
      size,
      Opacity(
        key: const Key('cart_drive'),
        opacity: opacity,
        child: Transform.rotate(
          angle: tilt,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (loaded) Positioned(top: -size * 0.12, child: _photo(size * 0.5)),
              Icon(Icons.shopping_cart_rounded, size: size, color: color),
            ],
          ),
        ),
      ),
    ));
    return Stack(clipBehavior: Clip.none, children: children);
  }
}
