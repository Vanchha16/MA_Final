import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Rounded "pill" text field with a soft sky-blue shadow (Figma: Login · B).
///
/// When focused it smoothly lifts a little, the shadow turns into a sky-blue
/// glow and the leading icon turns blue with a small bounce. Animations are
/// skipped when the system "reduce motion" setting is on.
class PillTextField extends StatefulWidget {
  static const double height = 56;
  static const double radius = 28;

  final Key? fieldKey;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final IconData icon;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final bool enabled;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;

  const PillTextField({
    super.key,
    this.fieldKey,
    required this.controller,
    this.focusNode,
    required this.label,
    required this.icon,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
  });

  @override
  State<PillTextField> createState() => _PillTextFieldState();
}

class _PillTextFieldState extends State<PillTextField> {
  static const _duration = Duration(milliseconds: 260);

  FocusNode? _ownFocusNode;
  FocusNode get _focusNode => widget.focusNode ?? (_ownFocusNode ??= FocusNode());
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(PillTextField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocusNode)?.removeListener(_onFocusChange);
      _focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focused != _focusNode.hasFocus) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = reduceMotion ? Duration.zero : _duration;

    final fillColor = !widget.enabled
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
        : (dark ? scheme.surfaceContainerHigh : Colors.white);
    final shape = BorderRadius.circular(PillTextField.radius);
    OutlineInputBorder border([Color? color, double width = 1.5]) => OutlineInputBorder(
          borderRadius: shape,
          borderSide: color == null ? BorderSide.none : BorderSide(color: color, width: width),
        );

    // Resting: faint shadow. Focused: larger sky-blue glow.
    final shadow = _focused
        ? BoxShadow(
            color: scheme.primary.withValues(alpha: dark ? 0.30 : 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          )
        : BoxShadow(
            color: AppTheme.primaryDark.withValues(alpha: dark || !widget.enabled ? 0 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          );
    final iconColor = _focused ? scheme.primary : scheme.onSurfaceVariant;

    return AnimatedScale(
      scale: _focused ? 1.015 : 1,
      duration: duration,
      curve: Curves.easeOutCubic,
      child: Stack(
        children: [
          // Shadow sits behind the input only, so error text below it stays clean
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: PillTextField.height,
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(borderRadius: shape, boxShadow: [shadow]),
            ),
          ),
          TextFormField(
            key: widget.fieldKey,
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onFieldSubmitted,
            validator: widget.validator,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              errorText: widget.errorText,
              filled: true,
              fillColor: fillColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: AnimatedScale(
                  scale: _focused ? 1.15 : 1,
                  duration: duration,
                  curve: Curves.easeOutBack,
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: iconColor),
                    duration: duration,
                    curve: Curves.easeOut,
                    builder: (_, color, _) => Icon(widget.icon, color: color),
                  ),
                ),
              ),
              suffixIcon: widget.suffix == null
                  ? null
                  : Padding(padding: const EdgeInsets.only(right: 6), child: widget.suffix),
              border: border(),
              enabledBorder: border(),
              disabledBorder: border(),
              focusedBorder: border(scheme.primary),
              errorBorder: border(scheme.error, 1),
              focusedErrorBorder: border(scheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
