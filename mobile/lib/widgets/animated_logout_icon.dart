import 'package:flutter/material.dart';

/// Logout icon whose arrow slides out of the door, disappears, then slides
/// back in from the door and settles (recreated from the reference animation
/// in docs/figma/, drawn in code so it stays sharp and takes any color).
///
/// The motion plays for [playDuration], then rests for [pause] before looping.
/// Shows the static icon when the system "reduce motion" setting is on.
class AnimatedLogoutIcon extends StatefulWidget {
  final double size;
  final Color color;
  final Duration playDuration;
  final Duration pause;

  const AnimatedLogoutIcon({
    super.key,
    this.size = 24,
    required this.color,
    this.playDuration = const Duration(milliseconds: 1140),
    this.pause = const Duration(milliseconds: 2400),
  });

  @override
  State<AnimatedLogoutIcon> createState() => _AnimatedLogoutIconState();
}

class _AnimatedLogoutIconState extends State<AnimatedLogoutIcon> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: widget.playDuration + widget.pause);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.value = 1; // arrow at rest
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playShare = widget.playDuration.inMicroseconds / (widget.playDuration + widget.pause).inMicroseconds;
    return Semantics(
      label: 'Log out',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _LogoutPainter(
            color: widget.color,
            // 0..1 through the motion, then held at 1 during the pause
            progress: (_controller.value / playShare).clamp(0.0, 1.0),
          ),
        ),
      ),
    );
  }
}

class _LogoutPainter extends CustomPainter {
  final Color color;
  final double progress;

  _LogoutPainter({required this.color, required this.progress});

  /// Arrow offset (in 24px icon units) over the motion:
  /// drift + exit to the right, hidden, then enter from the door and settle.
  static double arrowOffset(double t) {
    // Curves assert 0 <= t <= 1, and the division can land a hair above 1
    double phase(double from, double length) => ((t - from) / length).clamp(0.0, 1.0);
    if (t < 0.45) return 16 * Curves.easeInCubic.transform(phase(0, 0.45)); // slides out
    if (t < 0.58) return 16; // fully gone (incl. the round line cap)
    return -13 * (1 - Curves.easeOutBack.transform(phase(0.58, 0.42))); // back in
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Door: an open bracket with rounded corners
    canvas.drawPath(
      Path()
        ..moveTo(10, 4)
        ..lineTo(7, 4)
        ..arcToPoint(const Offset(5, 6), radius: const Radius.circular(2), clockwise: false)
        ..lineTo(5, 18)
        ..arcToPoint(const Offset(7, 20), radius: const Radius.circular(2), clockwise: false)
        ..lineTo(10, 20),
      stroke,
    );

    // Arrow: only visible between the door and the right edge
    canvas.clipRect(const Rect.fromLTRB(6.4, 0, 23, 24));
    canvas.translate(arrowOffset(progress), 0);
    canvas.drawLine(const Offset(10, 12), const Offset(20, 12), stroke);
    canvas.drawPath(
      Path()
        ..moveTo(16, 8)
        ..lineTo(20, 12)
        ..lineTo(16, 16),
      stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoutPainter old) => old.progress != progress || old.color != color;
}
