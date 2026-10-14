import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Minus, the number and plus in a soft pill. Buttons turn off at [min] and
/// [max]. [keyPrefix] gives each part a test key, e.g. 'qty' -> qty_minus.
class QuantityStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int>? onChanged;
  final bool compact;
  final String keyPrefix;

  const QuantityStepper({
    super.key,
    required this.value,
    this.min = 1,
    required this.max,
    required this.onChanged,
    this.compact = false,
    this.keyPrefix = 'qty',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final size = compact ? 32.0 : 44.0;

    Widget button(IconData icon, String tooltip, String part, VoidCallback? onPressed) => IconButton.filled(
          key: Key('${keyPrefix}_$part'),
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: dark ? scheme.surfaceContainerHighest : Colors.white,
            foregroundColor: dark ? scheme.primary : AppTheme.primaryDark,
            disabledBackgroundColor: Colors.transparent,
            fixedSize: Size(size, size),
            minimumSize: Size(size, size),
            padding: EdgeInsets.zero,
          ),
          icon: Icon(icon, size: compact ? 18 : 20),
        );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainerHigh : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(size),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, 'Less', 'minus', onChanged != null && value > min ? () => onChanged!(value - 1) : null),
          SizedBox(
            width: compact ? 28 : 34,
            child: Text(
              '$value',
              key: Key('${keyPrefix}_value'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: compact ? 15 : 17, fontWeight: FontWeight.bold),
            ),
          ),
          button(Icons.add_rounded, 'More', 'plus', onChanged != null && value < max ? () => onChanged!(value + 1) : null),
        ],
      ),
    );
  }
}
