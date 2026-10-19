import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/error_banner.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/icon_title.dart';
import '../../widgets/mascot_greeting.dart';
import '../../widgets/pill_text_field.dart';
import '../admin/admin_shell.dart';
import '../shell/main_shell.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

/// Friendly login (Figma: "03 - Login"): clean solid light background,
/// logo mascot with a speech bubble, pill fields and a solid pill button.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  /// Message from the server (e.g. wrong password), shown above the button.
  String? _error;

  /// Per-field messages from the server's 422 `errors` map.
  Map<String, dynamic> _fieldErrors = {};

  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();
  late final _contentFade = CurvedAnimation(parent: _intro, curve: const Interval(0, 0.6, curve: Curves.easeOut));
  @override
  void dispose() {
    _intro.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

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
    if (!_formKey.currentState!.validate()) return;
    try {
      await context.read<AuthProvider>().login(_email.text.trim(), _password.text);
      _goHome();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _fieldErrors = e.errors ?? {};
      });
    }
  }

  void _goHome() {
    if (!mounted) return;
    // Clear the auth screens (and any guest shell underneath) and open the app
    final admin = context.read<AuthProvider>().user?.isAdmin ?? false;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => admin ? const AdminShell() : const MainShell()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: FadeTransition(
                  opacity: _contentFade,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(_contentFade),
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const MascotGreeting(message: 'Hi again!', icon: Icons.auto_awesome),
                            const SizedBox(height: 22),
                            const IconTitle(
                              'Welcome back!',
                              icon: Icons.waving_hand_rounded,
                              iconColor: AppTheme.amber,
                              fontSize: 30,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Your collection missed you',
                              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 24),
                            PillTextField(
                              fieldKey: const Key('login_email'),
                              maxLength: 150,
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
                            const SizedBox(height: 16),
                            PillTextField(
                              fieldKey: const Key('login_password'),
                              maxLength: 200,
                              controller: _password,
                              label: 'Password',
                              icon: Icons.lock_outline,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              errorText: _fieldErrors['password'] as String?,
                              onChanged: (_) => _clearServerErrors(),
                              onFieldSubmitted: (_) => _submit(),
                              validator: (v) => (v == null || v.isEmpty) ? 'Please enter your password' : null,
                              suffix: IconButton(
                                tooltip: _obscure ? 'Show password' : 'Hide password',
                                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                key: const Key('login_to_forgot'),
                                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => ForgotPasswordScreen(initialEmail: _email.text.trim()),
                                )),
                                child: const Text('Forgot password?'),
                              ),
                            ),
                            if (_error != null) ...[
                              ErrorBanner(message: _error!),
                              const SizedBox(height: 12),
                            ],
                            PillButton(
                              key: const Key('login_submit'),
                              label: 'Login',
                              trailingIcon: Icons.arrow_forward_rounded,
                              loading: loading,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: loading ? null : _goHome,
                              style: OutlinedButton.styleFrom(
                                shape: const StadiumBorder(),
                                backgroundColor: dark ? scheme.surfaceContainerHigh : Colors.white,
                              ),
                              icon: const Icon(Icons.storefront_outlined),
                              label: const Text('Just browsing'),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              // Wrap (not Row) so the link drops to a new line with large text instead of overflowing
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text('New here?', style: text.bodyMedium),
                                TextButton(
                                  key: const Key('login_to_register'),
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                  ),
                                  child: const Text('Create an account', style: TextStyle(fontWeight: FontWeight.w600)),
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
          ),
        ],
      ),
    );
  }
}
