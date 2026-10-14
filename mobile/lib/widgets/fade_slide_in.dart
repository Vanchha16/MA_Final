import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Fades its child in while sliding it up a little (flutter_animate) - the
/// entrance used by the auth screens. Instant when "reduce motion" is on.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const FadeSlideIn({super.key, required this.child, this.duration = const Duration(milliseconds: 600)});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return child
        .animate()
        .fadeIn(duration: duration, curve: Curves.easeOut)
        .slideY(begin: 0.03, end: 0, duration: duration, curve: Curves.easeOut);
  }
}
