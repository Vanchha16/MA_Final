import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The circle wipe when the theme changes (picked from the Settings previews, C):
/// a picture of the screen is taken, the theme changes underneath, and the
/// picture is cut away by a circle that grows from where the customer tapped.
///
/// Put it around the app (MaterialApp.builder) and call
/// `ThemeReveal.of(context).run(tapPoint, () => change the theme)`.
class ThemeReveal extends StatefulWidget {
  final Widget child;

  const ThemeReveal({super.key, required this.child});

  static const duration = Duration(milliseconds: 650);

  static ThemeRevealState? maybeOf(BuildContext context) => context.findAncestorStateOfType<ThemeRevealState>();

  @override
  State<ThemeReveal> createState() => ThemeRevealState();
}

class ThemeRevealState extends State<ThemeReveal> with SingleTickerProviderStateMixin {
  final _boundary = GlobalKey();
  late final AnimationController _controller;
  ui.Image? _before;
  Offset _center = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: ThemeReveal.duration);
  }

  @override
  void dispose() {
    _controller.dispose();
    _before?.dispose();
    super.dispose();
  }

  /// Runs [change] behind a circle that grows from [center] (global position).
  /// Without animations (reduce motion, or no picture possible) it just changes.
  Future<void> run(Offset center, VoidCallback change) async {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final box = _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (reduceMotion || box == null || _controller.isAnimating) {
      change();
      return;
    }
    try {
      final picture = await box.toImage(pixelRatio: MediaQuery.devicePixelRatioOf(context));
      if (!mounted) return;
      setState(() {
        _before = picture;
        _center = box.globalToLocal(center);
      });
    } catch (_) {
      change();
      return;
    }
    change();
    await _controller.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _before?.dispose();
      _before = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.expand,
      children: [
        RepaintBoundary(key: _boundary, child: widget.child),
        if (_before != null)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => LayoutBuilder(builder: (context, size) {
                // Far enough to reach every corner
                final corners = [Offset.zero, Offset(size.maxWidth, 0), Offset(0, size.maxHeight), Offset(size.maxWidth, size.maxHeight)];
                final reach = corners.map((c) => (c - _center).distance).reduce(math.max);
                final radius = Curves.easeInCubic.transform(_controller.value) * reach;
                return ClipPath(
                  clipper: _OutsideCircle(_center, radius),
                  child: RawImage(image: _before, fit: BoxFit.fill, width: size.maxWidth, height: size.maxHeight),
                );
              }),
            ),
          ),
      ],
    );
  }
}

/// Everything except a circle: the old screen with a hole that grows.
class _OutsideCircle extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  _OutsideCircle(this.center, this.radius);

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(_OutsideCircle old) => old.radius != radius || old.center != center;
}
