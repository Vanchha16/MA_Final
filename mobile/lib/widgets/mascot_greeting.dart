import 'package:flutter/material.dart';

import 'speech_bubble.dart';

/// The logo "mascot" floating gently, with a speech bubble that pops in.
/// Used at the top of the auth screens ("Hi again!", "Nice to meet you!").
class MascotGreeting extends StatefulWidget {
  final String message;
  final IconData? icon;
  final double logoSize;

  const MascotGreeting({super.key, required this.message, this.icon, this.logoSize = 112});

  @override
  State<MascotGreeting> createState() => _MascotGreetingState();
}

class _MascotGreetingState extends State<MascotGreeting> with TickerProviderStateMixin {
  late final _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  late final _bubbleScale = CurvedAnimation(parent: _pop, curve: const Interval(0.35, 1, curve: Curves.easeOutBack));
  late final _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _pop.value = 1;
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _float,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, -4 + 8 * Curves.easeInOut.transform(_float.value)),
            child: child,
          ),
          child: Image.asset('assets/logo_centered.png', width: widget.logoSize, height: widget.logoSize),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: ScaleTransition(
            scale: _bubbleScale,
            alignment: Alignment.bottomLeft,
            child: SpeechBubble(text: widget.message, icon: widget.icon),
          ),
        ),
      ],
    );
  }
}
