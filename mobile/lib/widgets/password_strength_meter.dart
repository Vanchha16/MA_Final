import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Password strength from 0 (empty) to 4 (strong).
/// +1 for each: 6+ chars, 10+ chars, upper+lower case, a digit, a symbol (max 4).
int passwordStrength(String password) {
  if (password.isEmpty) return 0;
  var score = 0;
  if (password.length >= 6) score++;
  if (password.length >= 10) score++;
  if (RegExp(r'[a-z]').hasMatch(password) && RegExp(r'[A-Z]').hasMatch(password)) score++;
  if (RegExp(r'\d').hasMatch(password)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
  return score.clamp(1, 4);
}

/// Four animated bars + a label ("Weak", "Fair", "Good", "Strong").
/// Hidden while the password is empty. (Figma: 04 - Register)
class PasswordStrengthMeter extends StatelessWidget {
  static const _labels = ['', 'Weak password', 'Fair password', 'Good password', 'Strong password 💪'];
  static const _amber = Color(0xFFF59E0B);
  static const _green = Color(0xFF16A34A);

  final String password;

  const PasswordStrengthMeter({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final score = passwordStrength(password);
    final scheme = Theme.of(context).colorScheme;
    final color = switch (score) {
      1 => AppTheme.coral,
      2 => _amber,
      _ => _green,
    };
    const duration = Duration(milliseconds: 250);

    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: score == 0
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: duration,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i < score ? color : scheme.outlineVariant.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  const SizedBox(width: 4),
                  Text(
                    _labels[score],
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
                  ),
                ],
              ),
            ),
    );
  }
}
