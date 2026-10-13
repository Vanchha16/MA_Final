import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/icon_circle.dart';
import '../../widgets/pill_button.dart';

/// Shown after a successful password reset (Figma: "07b - Reset Success").
class ResetSuccessScreen extends StatefulWidget {
  const ResetSuccessScreen({super.key});

  @override
  State<ResetSuccessScreen> createState() => _ResetSuccessScreenState();
}

class _ResetSuccessScreenState extends State<ResetSuccessScreen> with SingleTickerProviderStateMixin {
  late final _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final _scale = CurvedAnimation(parent: _pop, curve: Curves.easeOutBack);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _pop.value = 1;
    } else if (_pop.value == 0 && !_pop.isAnimating) {
      _pop.forward();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ScaleTransition(
                    scale: Tween(begin: 0.4, end: 1.0).animate(_scale),
                    child: const IconCircle(icon: Icons.check_circle_rounded, color: AppTheme.success, size: 148),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Password updated!',
                  textAlign: TextAlign.center,
                  style: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can now log in with your new password. Happy collecting!',
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                PillButton(
                  key: const Key('back_to_login'),
                  label: 'Back to Login',
                  trailingIcon: Icons.arrow_forward_rounded,
                  // Login is the first screen of the auth flow
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
