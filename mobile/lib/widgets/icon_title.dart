import 'package:flutter/material.dart';

/// Screen title followed by a decorative icon, e.g. "Welcome back!" + waving hand.
/// The project uses Material icons instead of emoji.
class IconTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color iconColor;
  final double? fontSize;

  const IconTitle(this.text, {super.key, required this.icon, required this.iconColor, this.fontSize});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: fontSize, fontWeight: FontWeight.bold);
    return Row(
      children: [
        Flexible(child: Text(text, style: style)),
        const SizedBox(width: 8),
        Icon(icon, size: (fontSize ?? 28) * 0.95, color: iconColor),
      ],
    );
  }
}
