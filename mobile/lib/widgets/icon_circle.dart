import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Big icon inside a soft tinted circle, used as the illustration at the top
/// of the password screens (Figma: Icon Circle).
class IconCircle extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;

  const IconCircle({super.key, required this.icon, this.color, this.size = 128});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = color ?? Theme.of(context).colorScheme.primary;
    // Brand icons sit on the light sky tint; other colors (e.g. success green) get their own soft tint
    final bg = color == null
        ? (dark ? const Color(0xFF0F1E33) : const Color(0xFFE0F2FE))
        : iconColor.withValues(alpha: dark ? 0.20 : 0.12);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: [
          if (!dark)
            BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Icon(icon, size: size * 0.47, color: iconColor),
    );
  }
}
