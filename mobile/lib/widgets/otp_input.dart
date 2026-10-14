import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';

import '../core/theme/app_theme.dart';
import 'shake.dart';

/// Six rounded boxes for a one-time code (Figma: Code Boxes), built on the
/// pinput package: typing, backspace, pasting a whole code and SMS/email
/// autofill all work. The box for the next digit gets the same sky-blue glow
/// as focused inputs, and the boxes shake when [hasError] turns on.
class OtpInput extends StatefulWidget {
  final int length;
  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final bool hasError;
  final bool autofocus;
  final Key? fieldKey;

  const OtpInput({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
    this.onChanged,
    this.hasError = false,
    this.autofocus = true,
    this.fieldKey,
  });

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  static const _gap = 10.0;
  final _shakeKey = GlobalKey<ShakeState>();

  @override
  void didUpdateWidget(OtpInput old) {
    super.didUpdateWidget(old);
    // Wrong or missing code: shake the boxes
    if (!old.hasError && widget.hasError) _shakeKey.currentState?.shake();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Shake(
      key: _shakeKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boxWidth = (constraints.maxWidth - _gap * (widget.length - 1)) / widget.length;
          BoxDecoration box({Color border = Colors.transparent, bool glow = false}) => BoxDecoration(
                color: dark ? scheme.surfaceContainerHigh : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(width: 2, color: border),
                boxShadow: [
                  if (!dark)
                    BoxShadow(
                      color: AppTheme.primaryDark.withValues(alpha: glow ? 0.25 : 0.10),
                      blurRadius: glow ? 24 : 18,
                      offset: Offset(0, glow ? 10 : 6),
                    ),
                ],
              );
          final base = PinTheme(
            width: boxWidth,
            height: 60,
            textStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: scheme.onSurface),
            decoration: box(),
          );

          return Pinput(
            key: widget.fieldKey,
            length: widget.length,
            controller: widget.controller,
            autofocus: widget.autofocus,
            onChanged: widget.onChanged,
            onCompleted: widget.onCompleted,
            forceErrorState: widget.hasError,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            closeKeyboardWhenCompleted: false,
            animationDuration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
            separatorBuilder: (_) => const SizedBox(width: _gap),
            defaultPinTheme: base,
            focusedPinTheme: base.copyWith(decoration: box(border: scheme.primary, glow: true)),
            errorPinTheme: base.copyWith(decoration: box(border: scheme.error)),
            cursor: Container(width: 2, height: 26, color: scheme.primary),
          );
        },
      ),
    );
  }
}
