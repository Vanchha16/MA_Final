import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import 'shake.dart';

/// Six rounded boxes for a one-time code (Figma: Code Boxes).
///
/// One invisible TextField sits on top of the boxes, so typing, backspace,
/// pasting a whole code and SMS/email autofill all work like a normal field.
/// The box for the next digit gets the same sky-blue glow as focused inputs.
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
  final _focus = FocusNode();
  final _shakeKey = GlobalKey<ShakeState>();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(OtpInput old) {
    super.didUpdateWidget(old);
    // Wrong or missing code: shake the boxes
    if (!old.hasError && widget.hasError) _shakeKey.currentState?.shake();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _onChanged(String value) {
    widget.onChanged?.call(value);
    if (value.length == widget.length) widget.onCompleted?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
    final activeIndex = code.length.clamp(0, widget.length - 1);

    final boxes = Stack(
      children: [
        Row(
          children: [
            for (var i = 0; i < widget.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: dark ? scheme.surfaceContainerHigh : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      width: 2,
                      color: widget.hasError
                          ? scheme.error
                          : (_focus.hasFocus && i == activeIndex ? scheme.primary : Colors.transparent),
                    ),
                    boxShadow: [
                      if (!dark)
                        BoxShadow(
                          color: AppTheme.primaryDark.withValues(alpha: _focus.hasFocus && i == activeIndex ? 0.25 : 0.10),
                          blurRadius: _focus.hasFocus && i == activeIndex ? 24 : 18,
                          offset: Offset(0, _focus.hasFocus && i == activeIndex ? 10 : 6),
                        ),
                    ],
                  ),
                  child: i < code.length
                      ? Text(code[i], style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: scheme.onSurface))
                      : (_focus.hasFocus && i == activeIndex
                          ? Container(width: 2, height: 26, color: scheme.primary)
                          : null),
                ),
              ),
            ],
          ],
        ),
        // The real input: invisible, covering the boxes so a tap anywhere focuses it
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              key: widget.fieldKey,
              controller: widget.controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              showCursor: false,
              enableInteractiveSelection: false,
              decoration: const InputDecoration.collapsed(hintText: ''),
              onChanged: _onChanged,
            ),
          ),
        ),
      ],
    );
    return Shake(key: _shakeKey, child: boxes);
  }
}
