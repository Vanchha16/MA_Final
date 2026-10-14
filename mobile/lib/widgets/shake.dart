import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Shakes its child left and right (flutter_animate `shakeX`), like a head
/// saying "no". Used to point at a field that still has an error. Call
/// [ShakeState.shake] through a `GlobalKey<ShakeState>`. Does nothing when
/// "reduce motion" is on.
class Shake extends StatefulWidget {
  final Widget child;

  /// How far each swing goes, in pixels.
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

class ShakeState extends State<Shake> {
  AnimationController? _controller;

  /// Starts a shake. Safe to call at any time, even during a build: the
  /// shake starts on the next frame.
  void shake() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) return;
      _controller?.forward(from: 0);
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child
        .animate(autoPlay: false, onInit: (c) => _controller = c)
        .shakeX(duration: widget.duration, hz: 6, amount: widget.distance);
  }
}
