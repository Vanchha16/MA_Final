import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Round white back button with a soft shadow (Figma: Back Button).
/// Pops the current screen unless [onPressed] is given.
class CircleBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const CircleBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          if (!dark)
            BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: IconButton.filled(
        tooltip: 'Back',
        onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
        style: IconButton.styleFrom(
          backgroundColor: dark ? scheme.surfaceContainerHigh : Colors.white,
          foregroundColor: scheme.onSurface,
          fixedSize: const Size(44, 44),
        ),
        icon: const Icon(Icons.arrow_back),
      ),
    );
  }
}
