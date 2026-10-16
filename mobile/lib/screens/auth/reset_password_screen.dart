import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/icon_circle.dart';
import '../../widgets/password_strength_meter.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/pill_text_field.dart';
import 'reset_success_screen.dart';

/// Step 3 of 3: choose a new password (Figma: "07 - Reset Password").
class ResetPasswordScreen extends StatefulWidget {
  final String resetToken;

  const ResetPasswordScreen({super.key, required this.resetToken});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _service = AuthService();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await _service.resetPassword(widget.resetToken, _password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ResetSuccessScreen()));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.errors?['new_password'] as String? ?? e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: FadeSlideIn(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(alignment: Alignment.centerLeft, child: CircleBackButton()),
                  const SizedBox(height: 20),
                  const Center(child: IconCircle(icon: Icons.lock_outline_rounded)),
                  const SizedBox(height: 24),
                  Text('Create a new password', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Make it strong and different from your old one.',
                    style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  PillTextField(
                    fieldKey: const Key('reset_password'),
                    maxLength: 72,
                    controller: _password,
                    label: 'New password',
                    icon: Icons.lock_outline,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: (_) => setState(() => _error = null), // also refreshes the meter
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter a new password';
                      if (v.length < 6) return 'Use at least 6 characters';
                      return null;
                    },
                    suffix: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  PasswordStrengthMeter(password: _password.text),
                  const SizedBox(height: 14),
                  PillTextField(
                    fieldKey: const Key('reset_confirm'),
                    maxLength: 72,
                    controller: _confirm,
                    label: 'Confirm new password',
                    icon: Icons.lock_outline,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please confirm your password';
                      if (v != _password.text) return "Passwords don't match";
                      return null;
                    },
                    suffix: IconButton(
                      tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                      icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    ErrorBanner(message: _error!),
                    const SizedBox(height: 12),
                  ],
                  PillButton(
                    key: const Key('reset_submit'),
                    label: 'Reset password',
                    trailingIcon: Icons.arrow_forward_rounded,
                    loading: _saving,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
