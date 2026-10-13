import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Rounded "pill" text field with a soft sky-blue shadow (Figma: Login · B).
class PillTextField extends StatelessWidget {
  static const double height = 56;
  static const double radius = 28;

  final Key? fieldKey;
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final String? errorText;
  final bool obscureText;
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
    required this.label,
    required this.icon,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = dark ? scheme.surfaceContainerHigh : Colors.white;
    final shape = BorderRadius.circular(radius);
    OutlineInputBorder border([Color? color, double width = 1.5]) => OutlineInputBorder(
          borderRadius: shape,
          borderSide: color == null ? BorderSide.none : BorderSide(color: color, width: width),
        );

    return Stack(
      children: [
        // Shadow sits behind the input only, so error text below it stays clean
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              boxShadow: [
                if (!dark)
                  BoxShadow(
                    color: AppTheme.primaryDark.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
          ),
        ),
        TextFormField(
          key: fieldKey,
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            errorText: errorText,
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(icon),
            ),
            suffixIcon: suffix == null
                ? null
                : Padding(padding: const EdgeInsets.only(right: 6), child: suffix),
            border: border(),
            enabledBorder: border(),
            focusedBorder: border(scheme.primary),
            errorBorder: border(scheme.error, 1),
            focusedErrorBorder: border(scheme.error),
          ),
        ),
      ],
    );
  }
}
