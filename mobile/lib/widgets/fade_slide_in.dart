import 'package:flutter/material.dart';

/// Fades its child in while sliding it up a little - the entrance used by the
/// auth screens. Instant when "reduce motion" is on.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const FadeSlideIn({super.key, required this.child, this.duration = const Duration(milliseconds: 600)});

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: widget.duration);
  late final _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.value = 1;
    } else if (_controller.value == 0 && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(_curve),
          child: widget.child,
        ),
      );
}
