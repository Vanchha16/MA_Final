import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import 'pill_button.dart';

/// "Log in to continue" pop-up for guests (picked layout A: centred, like the
/// Log out confirm). Log in / Create account open the auth screens and come back
/// here; returns true when the guest is now logged in, so the action can go on.
Future<bool> showLoginRequired(BuildContext context, {required String message, IconData icon = Icons.lock_rounded}) async {
  final choice = await showDialog<String>(context: context, builder: (_) => _LoginRequiredDialog(message: message, icon: icon));
  if (choice == null || !context.mounted) return false;
  final screen = choice == 'register' ? const RegisterScreen(returnOnSuccess: true) : const LoginScreen(returnOnSuccess: true);
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => screen));
  return ok == true;
}

class _LoginRequiredDialog extends StatelessWidget {
  final String message;
  final IconData icon;

  const _LoginRequiredDialog({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      key: const Key('login_required'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: scheme.primary, size: 30),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Log in to continue', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 22),
          PillButton(key: const Key('login_required_login'), label: 'Log in', leadingIcon: Icons.login_rounded, onPressed: () => Navigator.of(context).pop('login')),
          const SizedBox(height: 10),
          OutlinedButton(
            key: const Key('login_required_register'),
            onPressed: () => Navigator.of(context).pop('register'),
            style: OutlinedButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size(0, 52)),
            child: const Text('Create account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const Key('login_required_later'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not now, keep browsing'),
          ),
        ]),
      ),
    );
  }
}
