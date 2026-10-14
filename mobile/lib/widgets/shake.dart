import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Shakes its child left and right, like a head saying "no". Used to point
/// at a field that still has an error. Call [ShakeState.shake] through a
/// `GlobalKey<ShakeState>`. Does nothing when "reduce motion" is on.
class Shake extends StatefulWidget {
  final Widget child;

  /// How far the first swing goes, in pixels. Later swings get smaller.
  final double distance;
  final Duration duration;

  const Shake({
    super.key,
    required this.child,
    this.distance = 10,
    this.duration = const Duration(milliseconds: 480),
  });

  @override
  State<Shake> createState() => ShakeState();
}

class ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: widget.duration);

  /// Starts a shake. Safe to call at any time, even during a build: the
  /// shake starts on the next frame.
  void shake() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) return;
      _controller.forward(from: 0);
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (_, child) {
        final t = _controller.value;
        // Three left-right swings that fade out, ending back at 0
        final dx = math.sin(t * math.pi * 6) * widget.distance * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
