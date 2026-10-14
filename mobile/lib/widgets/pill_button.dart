import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Primary pill button: solid brand sky blue with a soft shadow
/// (Figma: Button / Primary, pill style). Buttons never use gradients.
/// Pass [color] for other solid variants, e.g. [PillButton.danger] for log out.
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? leadingIcon;

  /// Custom leading widget (e.g. an animated icon); used instead of [leadingIcon].
  final Widget? leading;
  final IconData? trailingIcon;
  final Color? color;
  final Color? foregroundColor;

  /// What screen readers announce, e.g. "Log in" for a playful "Let's go!" label.
  final String? semanticLabel;

  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.leadingIcon,
    this.leading,
    this.trailingIcon,
    this.color,
    this.foregroundColor,
    this.semanticLabel,
  });

  /// Solid red for log out and other destructive actions (Figma: Button / Danger).
  const PillButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.leadingIcon,
    this.leading,
    this.trailingIcon,
    this.semanticLabel,
  }) : color = AppTheme.danger,
       foregroundColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? scheme.primary;
    final fg = foregroundColor ?? scheme.onPrimary;
    const shape = StadiumBorder();

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled || loading ? 1 : 0.55,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: shape,
            color: bg,
            shadows: [BoxShadow(color: bg.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              child: SizedBox(
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: loading
                        ? SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (leading != null || leadingIcon != null) ...[
                                leading ?? Icon(leadingIcon, color: fg, size: 20),
                                const SizedBox(width: 8),
                              ],
                              // Shrinks with "..." in narrow spots (half-width dialog buttons, big text)
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (trailingIcon != null) ...[const SizedBox(width: 8), Icon(trailingIcon, color: fg, size: 20)],
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
