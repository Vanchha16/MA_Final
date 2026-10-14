import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../services/profile_service.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/icon_circle.dart';
import '../../widgets/password_strength_meter.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/pill_text_field.dart';

/// Change password while signed in: current + new + confirm.
class ChangePasswordScreen extends StatefulWidget {
  final ProfileService? service;

  const ChangePasswordScreen({super.key, this.service});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  late final _service = widget.service ?? ProfileService();
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _obscure = [true, true, true];
  bool _saving = false;
  String? _error;
  Map<String, dynamic> _fieldErrors = {};

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _fieldErrors = {};
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await _service.changePassword(_current.text, _next.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Password changed')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = e.errors ?? {};
        _error = _fieldErrors.isNotEmpty ? null : e.message;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _eye(int i) => IconButton(
        tooltip: _obscure[i] ? 'Show password' : 'Hide password',
        icon: Icon(_obscure[i] ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        onPressed: () => setState(() => _obscure[i] = !_obscure[i]),
      );

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
                  const Center(child: IconCircle(icon: Icons.lock_rounded)),
                  const SizedBox(height: 24),
                  Text('Change password', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Enter your current password, then choose a new one.',
                      style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  PillTextField(
                    fieldKey: const Key('cp_current'),
                    controller: _current,
                    label: 'Current password',
                    icon: Icons.lock_outline,
                    obscureText: _obscure[0],
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.password],
                    errorText: _fieldErrors['current_password'] as String?,
                    validator: (v) => (v == null || v.isEmpty) ? 'Please enter your current password' : null,
                    suffix: _eye(0),
                  ),
                  const SizedBox(height: 14),
                  PillTextField(
                    fieldKey: const Key('cp_new'),
                    controller: _next,
                    label: 'New password',
                    icon: Icons.lock_outline,
                    obscureText: _obscure[1],
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    errorText: _fieldErrors['new_password'] as String?,
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter a new password';
                      if (v.length < 6) return 'Use at least 6 characters';
                      if (v == _current.text) return 'Choose a different password';
                      return null;
                    },
                    suffix: _eye(1),
                  ),
                  PasswordStrengthMeter(password: _next.text),
                  const SizedBox(height: 14),
                  PillTextField(
                    fieldKey: const Key('cp_confirm'),
                    controller: _confirm,
                    label: 'Confirm new password',
                    icon: Icons.lock_outline,
                    obscureText: _obscure[2],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) => v != _next.text ? "Passwords don't match" : null,
                    suffix: _eye(2),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    ErrorBanner(message: _error!),
                    const SizedBox(height: 12),
                  ],
                  PillButton(key: const Key('cp_submit'), label: 'Update password', loading: _saving, onPressed: _submit),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
