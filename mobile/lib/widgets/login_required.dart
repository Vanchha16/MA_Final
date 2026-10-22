import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import 'pill_button.dart';

/// "Log in to continue" pop-up for guests (picked layout A: centred, like the
/// Log out confirm). It springs in, the icon pops with a ripple and the rest
/// slides up in turn; with "reduce motion" on it only fades. Log in / Create account open the auth screens and come back
/// here; returns true when the guest is now logged in, so the action can go on.
Future<bool> showLoginRequired(BuildContext context, {required String message, IconData icon = Icons.lock_rounded}) async {
  final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  final choice = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black54,
    transitionDuration: Duration(milliseconds: reduceMotion ? 150 : 360),
    pageBuilder: (_, _, _) => _LoginRequiredDialog(message: message, icon: icon, reduceMotion: reduceMotion),
    // Springs in (fade, scale up with a little overshoot, rises a few pixels); quicker on the way out
    transitionBuilder: (_, animation, _, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut, reverseCurve: Curves.easeIn);
      if (reduceMotion) return FadeTransition(opacity: fade, child: child);
      final spring = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(spring),
          child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(spring), child: child),
        ),
      );
    },
  );
  if (choice == null || !context.mounted) return false;
  final screen = choice == 'register' ? const RegisterScreen(returnOnSuccess: true) : const LoginScreen(returnOnSuccess: true);
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => screen));
  return ok == true;
}

class _LoginRequiredDialog extends StatelessWidget {
  final String message;
  final IconData icon;
  final bool reduceMotion;

  const _LoginRequiredDialog({required this.message, required this.icon, required this.reduceMotion});

  /// The icon pops in with a bounce and one ring ripples out behind it.
  Widget _icon(ColorScheme scheme) {
    final circle = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Icon(icon, color: scheme.primary, size: 30),
    );
    if (reduceMotion) return circle;
    final ring = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scheme.primary.withValues(alpha: 0.45), width: 2),
      ),
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        // Hidden until it starts, then grows and fades out
        ring.animate(delay: 260.ms).custom(
          duration: 750.ms,
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Opacity(
            opacity: v == 0 ? 0 : 0.9 * (1 - v),
            child: Transform.scale(scale: 1 + 0.7 * v, child: child),
          ),
        ),
        circle.animate(delay: 120.ms).scaleXY(begin: 0.3, end: 1, duration: 650.ms, curve: Curves.elasticOut).fadeIn(duration: 160.ms),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      key: const Key('login_required'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: _icon(scheme)),
            const SizedBox(height: 14),
            ...[
                  const Text(
                    'Log in to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 22),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ]
                .animate(interval: 60.ms, delay: 140.ms)
                .fadeIn(duration: reduceMotion ? 1.ms : 280.ms)
                .moveY(begin: reduceMotion ? 0 : 10, end: 0, duration: 320.ms, curve: Curves.easeOutCubic),
            ...[
                  PillButton(
                    key: const Key('login_required_login'),
                    label: 'Log in',
                    leadingIcon: Icons.login_rounded,
                    onPressed: () => Navigator.of(context).pop('login'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: OutlinedButton(
                      key: const Key('login_required_register'),
                      onPressed: () => Navigator.of(context).pop('register'),
                      style: OutlinedButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size(0, 52)),
                      child: const Text('Create account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                  TextButton(key: const Key('login_required_later'), onPressed: () => Navigator.of(context).pop(), child: const Text('Not now, keep browsing')),
                ]
                .animate(interval: 60.ms, delay: 260.ms)
                .fadeIn(duration: reduceMotion ? 1.ms : 280.ms)
                .moveY(begin: reduceMotion ? 0 : 14, end: 0, duration: 340.ms, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }
}
