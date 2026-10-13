import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// White speech bubble with a tail on the bottom-left, used for friendly
/// mascot messages ("Hi again!" + sparkle icon). Matches Figma: Login · B.
class SpeechBubble extends StatelessWidget {
  static const double _tail = 8;

  final String text;
  final IconData? icon;

  const SpeechBubble({super.key, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = dark ? scheme.surfaceContainerHigh : Colors.white;
    final textColor = dark ? scheme.primary : AppTheme.primaryDark;

    return CustomPaint(
      painter: _BubblePainter(color: color, shadow: !dark),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_tail + 16, 14, 16, _tail + 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                text,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 6),
              Icon(icon, size: 18, color: textColor),
            ],
          ],
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final Color color;
  final bool shadow;

  _BubblePainter({required this.color, required this.shadow});

  @override
  void paint(Canvas canvas, Size size) {
    const tail = SpeechBubble._tail;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(tail, 0, size.width, size.height - tail),
      const Radius.circular(20),
    );
    final path = Path()
      ..addRRect(body)
      ..moveTo(tail + 26, size.height - tail)
      ..lineTo(tail + 6, size.height)
      ..lineTo(tail + 14, size.height - tail - 12)
      ..close();
    if (shadow) {
      canvas.drawShadow(path, AppTheme.primaryDark.withValues(alpha: 0.35), 6, false);
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.color != color || old.shadow != shadow;
}
