import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';

/// Cart quantity (picked from the quantity previews, C + typing): a small
/// "×2" chip that opens into minus / number / plus. The number can be typed.
/// It closes by itself a few seconds after the last change.
///
/// Changes show right away and are sent once the customer stops (or on
/// close), so fast taps make one request. At 1 the minus becomes a red
/// trash button. [keyPrefix] gives each part a test key, e.g. line_2_chip.
class QuantityChip extends StatefulWidget {
  final int value;
  final int max;

  /// The new amount, after the customer stops changing it. Null turns it off.
  final ValueChanged<int>? onChanged;
  final VoidCallback? onRemove;

  /// A typed amount was more than [max] (it is lowered to [max]).
  final ValueChanged<int>? onTooMany;
  final String keyPrefix;

  const QuantityChip({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    this.onRemove,
    this.onTooMany,
    this.keyPrefix = 'qty',
  });

  /// How long the stepper stays open after the last change.
  static const closeAfter = Duration(milliseconds: 2500);

  /// Quiet time before a change is sent.
  static const sendAfter = Duration(milliseconds: 450);

  @override
  State<QuantityChip> createState() => _QuantityChipState();
}

class _QuantityChipState extends State<QuantityChip> {
  late int _local = widget.value;
  bool _open = false;

  /// A change is shown but not sent yet.
  bool _waiting = false;
  Timer? _close, _send;
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        _close?.cancel();
        _text.selection = TextSelection(baseOffset: 0, extentOffset: _text.text.length);
      } else {
        _submitTyped();
      }
    });
  }

  @override
  void didUpdateWidget(QuantityChip old) {
    super.didUpdateWidget(old);
    // The server's answer wins unless a change is still waiting to be sent.
    if (widget.value != old.value && !_waiting) _show(widget.value);
  }

  @override
  void dispose() {
    _close?.cancel();
    _flush();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _show(int value) {
    _local = value;
    if (!_focus.hasFocus) _text.text = '$value';
    if (mounted) setState(() {});
  }

  void _openUp() {
    _text.text = '$_local';
    setState(() => _open = true);
    _keepOpen();
  }

  void _keepOpen() {
    _close?.cancel();
    if (_focus.hasFocus) return;
    _close = Timer(QuantityChip.closeAfter, () {
      if (!mounted) return;
      _flush();
      setState(() => _open = false);
    });
  }

  void _change(int value) {
    _show(value.clamp(1, widget.max));
    _waiting = true;
    _send?.cancel();
    _send = Timer(QuantityChip.sendAfter, _flush);
    _keepOpen();
  }

  /// Sends a waiting change now.
  void _flush() {
    _send?.cancel();
    if (!_waiting) return;
    _waiting = false;
    if (_local != widget.value) widget.onChanged?.call(_local);
  }

  void _submitTyped() {
    final typed = int.tryParse(_text.text);
    if (typed == null || typed < 1) {
      _text.text = '$_local'; // empty or 0: keep the old amount (use the trash to remove)
    } else {
      if (typed > widget.max) widget.onTooMany?.call(widget.max);
      _change(typed);
      _text.text = '$_local';
    }
    _keepOpen();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? scheme.primary : AppTheme.primaryDark;
    final enabled = widget.onChanged != null;
    final p = widget.keyPrefix;

    Widget round(String part, IconData icon, String tooltip, VoidCallback? onTap, {bool danger = false}) => IconButton.filled(
          key: Key('${p}_$part'),
          tooltip: tooltip,
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: danger ? AppTheme.danger : (dark ? scheme.surfaceContainerHighest : Colors.white),
            foregroundColor: danger ? Colors.white : accent,
            disabledBackgroundColor: Colors.transparent,
            fixedSize: const Size(32, 32),
            minimumSize: const Size(32, 32),
            padding: EdgeInsets.zero,
          ),
          icon: Icon(icon, size: 18),
        );

    final Widget child;
    if (!_open || !enabled) {
      child = Material(
        key: const ValueKey('closed'),
        color: dark ? scheme.surfaceContainerHighest : AppTheme.skyTint,
        shape: const StadiumBorder(),
        child: InkWell(
          key: Key('${p}_chip'),
          customBorder: const StadiumBorder(),
          onTap: enabled ? _openUp : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('×$_local', key: Key('${p}_value'), style: TextStyle(fontWeight: FontWeight.bold, color: enabled ? accent : scheme.onSurfaceVariant)),
                if (enabled) ...[const SizedBox(width: 4), Icon(Icons.unfold_more_rounded, size: 16, color: accent)],
              ],
            ),
          ),
        ),
      );
    } else {
      child = Container(
        key: const ValueKey('open'),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: dark ? scheme.surfaceContainerHigh : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(32)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _local == 1 && widget.onRemove != null
                ? round('trash', Icons.delete_outline_rounded, 'Remove', () {
                    _close?.cancel();
                    widget.onRemove!();
                  }, danger: true)
                : round('minus', Icons.remove_rounded, 'Less', _local > 1 ? () => _change(_local - 1) : null),
            SizedBox(
              width: 44,
              height: 32,
              child: TextField(
                key: Key('${p}_field'),
                controller: _text,
                focusNode: _focus,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 7),
                  filled: true,
                  fillColor: dark ? scheme.surfaceContainerHighest : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accent, width: 1.5)),
                ),
                onSubmitted: (_) => _focus.unfocus(),
                onTapOutside: (_) => _focus.unfocus(),
              ),
            ),
            round('plus', Icons.add_rounded, 'More', _local < widget.max ? () => _change(_local + 1) : null),
          ],
        ),
      );
    }

    return Semantics(
      label: 'Quantity $_local',
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedSwitcher(duration: const Duration(milliseconds: 150), child: child),
      ),
    );
  }
}
