import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import 'action_prompt.dart';

/// "Log in to continue" pop-up for guests (picked layout A: centred, like the
/// Log out confirm, animated by [showActionPrompt]). Log in / Create account
/// open the auth screens and come back here; returns true when the guest is now
/// logged in, so the action can go on.
Future<bool> showLoginRequired(BuildContext context, {required String message, IconData icon = Icons.lock_rounded}) async {
  final choice = await showActionPrompt(
    context,
    keyPrefix: 'login_required',
    icon: icon,
    title: 'Log in to continue',
    message: message,
    primaryLabel: 'Log in',
    primaryIcon: Icons.login_rounded,
    secondaryLabel: 'Create account',
    laterLabel: 'Not now, keep browsing',
  );
  if (choice == null || !context.mounted) return false;
  final screen = choice == 'secondary' ? const RegisterScreen(returnOnSuccess: true) : const LoginScreen(returnOnSuccess: true);
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => screen));
  return ok == true;
}
