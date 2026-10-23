import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/app_theme.dart';

/// What happens on screen when a product is saved to the wishlist (picked
/// option C): the tapped heart bursts (a ring and little hearts), then a heart
/// flies from it into the Wishlist tab, which bounces ([WishlistTabIcon]
/// registers itself as the target). Reduce-motion users get neither; the
/// "Saved to your wishlist" toast is shown by [ShopActions] either way.
class WishlistFx {
  static BuildContext? _origin;
  static final _targets = <GlobalKey, VoidCallback>{};

  /// The heart that was just tapped (heart buttons call this before toggling).
  static void tapped(BuildContext heart) => _origin = heart;

  static void register(GlobalKey key, VoidCallback onArrive) => _targets[key] = onArrive;
  static void unregister(GlobalKey key) => _targets.remove(key);

  /// Plays the effects from the heart that was tapped last.
  static void play() {
    final origin = _origin;
    _origin = null;
    if (origin == null || !origin.mounted || (MediaQuery.maybeDisableAnimationsOf(origin) ?? false)) return;
    final overlay = Overlay.maybeOf(origin, rootOverlay: true);
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    final heartBox = origin.findRenderObject() as RenderBox?;
    if (overlay == null || overlayBox == null || heartBox == null || !heartBox.attached) return;
    final from = overlayBox.globalToLocal(heartBox.localToGlobal(heartBox.size.center(Offset.zero)));
    _burst(overlay, from);
    _fly(overlay, overlayBox, from, delay: 220.ms);
  }

  static void _burst(OverlayState overlay, Offset at) {
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => Positioned(left: at.dx - 50, top: at.dy - 50, width: 100, height: 100, child: IgnorePointer(child: _Burst(onDone: () => entry.remove()))));
    overlay.insert(entry);
  }

  static void _fly(OverlayState overlay, RenderBox overlayBox, Offset from, {required Duration delay}) {
    MapEntry<GlobalKey, VoidCallback>? target;
    for (final t in _targets.entries) {
      final box = t.key.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.attached) target = t;
    }
    if (target == null) return;
    final box = target.key.currentContext!.findRenderObject() as RenderBox;
    final to = overlayBox.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
    final onArrive = target.value;
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => IgnorePointer(child: _FlyingHeart(from: from, to: to, delay: delay, onArrive: () {
          onArrive();
          entry.remove();
        })));
    overlay.insert(entry);
  }
}

/// A ring and eight little hearts flying out of the tapped heart.
class _Burst extends StatelessWidget {
  final VoidCallback onDone;

  const _Burst({required this.onDone});

  @override
  Widget build(BuildContext context) => Stack(alignment: Alignment.center, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.coral, width: 3)),
        ).animate(onComplete: (_) => onDone()).scaleXY(begin: 0.4, end: 2.2, duration: 600.ms, curve: Curves.easeOutCubic).fadeOut(duration: 600.ms),
        for (var i = 0; i < 8; i++)
          Icon(Icons.favorite_rounded, size: i.isEven ? 12 : 9, color: i % 3 == 0 ? AppTheme.amber : AppTheme.coral)
              .animate()
              .move(
                begin: Offset.zero,
                end: Offset(math.cos(i * math.pi / 4 - math.pi / 2) * 38, math.sin(i * math.pi / 4 - math.pi / 2) * 38),
                duration: 550.ms,
                curve: Curves.easeOutCubic,
              )
              .scaleXY(begin: 0.3, end: 1, duration: 250.ms)
              .then()
              .fadeOut(duration: 250.ms),
      ]);
}

/// A heart that arcs from the card into the Wishlist tab.
class _FlyingHeart extends StatefulWidget {
  final Offset from, to;
  final Duration delay;
  final VoidCallback onArrive;

  const _FlyingHeart({required this.from, required this.to, required this.delay, required this.onArrive});

  @override
  State<_FlyingHeart> createState() => _FlyingHeartState();
}

class _FlyingHeartState extends State<_FlyingHeart> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward().whenComplete(widget.onArrive);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          if (_c.value == 0) return const SizedBox.shrink();
          final t = Curves.easeInOutCubic.transform(_c.value);
          final a = widget.from, b = widget.to;
          // Arc: the control point sits above the higher of the two ends
          final control = Offset((a.dx + b.dx) / 2 + 40, math.min(a.dy, b.dy) - 120);
          final p = Offset(
            (1 - t) * (1 - t) * a.dx + 2 * (1 - t) * t * control.dx + t * t * b.dx,
            (1 - t) * (1 - t) * a.dy + 2 * (1 - t) * t * control.dy + t * t * b.dy,
          );
          final size = 26 - 10 * t;
          return Stack(children: [
            Positioned(
              left: p.dx - size / 2,
              top: p.dy - size / 2,
              child: Icon(Icons.favorite_rounded, size: size, color: AppTheme.coral, shadows: const [Shadow(color: Color(0x55F43F5E), blurRadius: 10)]),
            ),
          ]);
        },
      );
}
