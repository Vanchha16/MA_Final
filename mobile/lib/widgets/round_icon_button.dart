import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// 44px white circle icon button with a soft shadow and an optional red
/// "unread" dot (Figma: Top Bar bell / gear).
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool showDot;

  const RoundIconButton({super.key, required this.icon, required this.tooltip, this.onPressed, this.showDot = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? scheme.surfaceContainerHigh : Colors.white;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              if (!dark)
                BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.10), blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: IconButton.filled(
            tooltip: tooltip,
            onPressed: onPressed,
            style: IconButton.styleFrom(backgroundColor: bg, foregroundColor: scheme.onSurface, fixedSize: const Size(44, 44)),
            icon: Icon(icon, size: 22),
          ),
        ),
        if (showDot)
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle, border: Border.all(color: bg, width: 2)),
            ),
          ),
      ],
    );
  }
}
