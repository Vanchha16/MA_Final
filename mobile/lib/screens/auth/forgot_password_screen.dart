import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/icon_circle.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/pill_text_field.dart';
import 'verify_code_screen.dart';

/// Step 1 of 3: ask for a reset code (Figma: "05 - Forgot Password").
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _service = AuthService();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final email = _email.text.trim();
    setState(() => _sending = true);
    try {
      final request = await _service.requestResetCode(email);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VerifyCodeScreen(email: email, request: request),
      ));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.errors?['email'] as String? ?? e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
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
                  const Center(child: IconCircle(icon: Icons.lock_reset_rounded)),
                  const SizedBox(height: 24),
                  Text('Forgot password?', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    "No worries! Enter the email you signed up with and we'll send you a 6-digit code.",
                    style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  PillTextField(
                    fieldKey: const Key('forgot_email'),
                    maxLength: 150,
                    controller: _email,
                    label: 'Email',
                    hint: 'you@example.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    onFieldSubmitted: (_) => _send(),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Please enter your email';
                      if (!_emailRe.hasMatch(value)) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) ...[
                    ErrorBanner(message: _error!),
                    const SizedBox(height: 12),
                  ],
                  PillButton(
                    key: const Key('forgot_submit'),
                    label: 'Send code',
                    trailingIcon: Icons.arrow_forward_rounded,
                    loading: _sending,
                    onPressed: _send,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Remember your password?', style: text.bodyMedium),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Login', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
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
