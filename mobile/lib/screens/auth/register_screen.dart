import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/icon_title.dart';
import '../../widgets/mascot_greeting.dart';
import '../../widgets/password_strength_meter.dart';
import '../../widgets/pill_text_field.dart';
import '../home/home_screen.dart';

/// Create account (Figma: "04 - Register"), same playful style as Login.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  // Cambodian numbers: 0XX XXX XXX(X) or +855 XX XXX XXX(X)
  static final _phoneRe = RegExp(r'^(\+855|0)\d{8,9}$');

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final _termsTap = TapGestureRecognizer()..onTap = () => _comingSoon('Terms of Service');
  late final _privacyTap = TapGestureRecognizer()..onTap = () => _comingSoon('Privacy Policy');

  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _agreed = false;
  bool _termsError = false;
  String? _error;
  Map<String, dynamic> _fieldErrors = {};

  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  late final _contentFade = CurvedAnimation(parent: _intro, curve: Curves.easeOut);

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    _termsTap.dispose();
    _privacyTap.dispose();
    _intro.dispose();
    super.dispose();
  }

  static String _normalizePhone(String v) => v.replaceAll(RegExp(r'[\s\-().]'), '');

  void _clearServerErrors() {
    if (_error != null || _fieldErrors.isNotEmpty) {
      setState(() {
        _error = null;
        _fieldErrors = {};
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    _clearServerErrors();
    final formOk = _formKey.currentState!.validate();
    setState(() => _termsError = !_agreed);
    if (!formOk || !_agreed) return;

    final phone = _normalizePhone(_phone.text);
    try {
      await context.read<AuthProvider>().register(
            fullName: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            phone: phone.isEmpty ? null : phone,
          );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = e.errors ?? {};
        _error = _fieldErrors.isNotEmpty ? 'Please fix the highlighted fields' : e.message;
      });
    }
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature is coming in the next update')));
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final linkStyle = TextStyle(color: scheme.primary, fontWeight: FontWeight.w600);

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: FadeTransition(
                opacity: _contentFade,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(_contentFade),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _BackButton(onPressed: () => Navigator.of(context).maybePop()),
                          ),
                          const SizedBox(height: 16),
                          const MascotGreeting(message: 'Nice to meet you!', icon: Icons.celebration_rounded, logoSize: 76),
                          const SizedBox(height: 16),
                          const IconTitle('Create account', icon: Icons.auto_awesome, iconColor: AppTheme.accent),
                          const SizedBox(height: 6),
                          Text(
                            'Start your anime collection today',
                            style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 20),
                          PillTextField(
                            fieldKey: const Key('register_name'),
                            controller: _name,
                            label: 'Full name',
                            icon: Icons.person_outline,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            errorText: _fieldErrors['full_name'] as String?,
                            onChanged: (_) => _clearServerErrors(),
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) return 'Please enter your name';
                              if (value.length < 2) return 'Name is too short';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          PillTextField(
                            fieldKey: const Key('register_email'),
                            controller: _email,
                            label: 'Email',
                            hint: 'you@example.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            errorText: _fieldErrors['email'] as String?,
                            onChanged: (_) => _clearServerErrors(),
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) return 'Please enter your email';
                              if (!_emailRe.hasMatch(value)) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          PillTextField(
                            fieldKey: const Key('register_phone'),
                            controller: _phone,
                            label: 'Phone (optional)',
                            hint: '012 345 678',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.telephoneNumber],
                            errorText: _fieldErrors['phone'] as String?,
                            onChanged: (_) => _clearServerErrors(),
                            validator: (v) {
                              final value = _normalizePhone(v ?? '');
                              if (value.isEmpty) return null;
                              if (!_phoneRe.hasMatch(value)) return 'Enter a valid phone, e.g. 012 345 678';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          PillTextField(
                            fieldKey: const Key('register_password'),
                            controller: _password,
                            label: 'Password',
                            icon: Icons.lock_outline,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            errorText: _fieldErrors['password'] as String?,
                            onChanged: (_) {
                              _clearServerErrors();
                              setState(() {}); // refresh the strength meter
                            },
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Please create a password';
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
                            fieldKey: const Key('register_confirm'),
                            controller: _confirm,
                            label: 'Confirm password',
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
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Checkbox(
                                key: const Key('register_terms'),
                                value: _agreed,
                                isError: _termsError,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                onChanged: (v) => setState(() {
                                  _agreed = v ?? false;
                                  if (_agreed) _termsError = false;
                                }),
                              ),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    style: text.bodyMedium,
                                    children: [
                                      const TextSpan(text: 'I agree to the '),
                                      TextSpan(text: 'Terms', style: linkStyle, recognizer: _termsTap),
                                      const TextSpan(text: ' & '),
                                      TextSpan(text: 'Privacy Policy', style: linkStyle, recognizer: _privacyTap),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            child: _termsError
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                                    child: Text(
                                      'Please accept the Terms to continue',
                                      style: TextStyle(color: scheme.error, fontSize: 12),
                                    ),
                                  )
                                : const SizedBox(width: double.infinity),
                          ),
                          const SizedBox(height: 12),
                          if (_error != null) ...[
                            ErrorBanner(message: _error!),
                            const SizedBox(height: 12),
                          ],
                          PillButton(
                            key: const Key('register_submit'),
                            label: 'Create account',
                            trailingIcon: Icons.arrow_forward_rounded,
                            loading: loading,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            // Wrap (not Row) so the link drops to a new line with large text instead of overflowing
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('Already have an account?', style: text.bodyMedium),
                              TextButton(
                                key: const Key('register_to_login'),
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
            ),
          ),
        ],
      ),
    );
  }
}

/// Round white back button with a soft shadow (Figma: Back Button).
class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          if (!dark)
            BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: IconButton.filled(
        tooltip: 'Back',
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: dark ? scheme.surfaceContainerHigh : Colors.white,
          foregroundColor: scheme.onSurface,
          fixedSize: const Size(44, 44),
        ),
        icon: const Icon(Icons.arrow_back),
      ),
    );
  }
}
