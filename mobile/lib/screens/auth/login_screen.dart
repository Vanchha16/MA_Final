import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/pill_text_field.dart';
import '../../widgets/sparkle.dart';
import '../../widgets/speech_bubble.dart';
import '../home/home_screen.dart';

/// Friendly login (Figma: "03 - Login · B · Playful"): soft color blobs,
/// logo mascot with a speech bubble, pill fields and a gradient button.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
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
  late final _bubblePop = CurvedAnimation(parent: _intro, curve: const Interval(0.35, 1, curve: Curves.easeOutBack));

  /// Gentle floating logo + twinkling sparkles. Not started when the user has
  /// turned off animations (accessibility) - see didChangeDependencies.
  late final _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _float.dispose();
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
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature is coming in the next update')));
  }

  void _fillDemo() {
    _email.text = 'demo@shop.com';
    _password.text = 'demo123';
    _clearServerErrors();
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
          Positioned.fill(child: _Backdrop(dark: dark, twinkle: _float)),
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
                            _mascot(),
                            const SizedBox(height: 22),
                            Text(
                              'Welcome back! 👋',
                              style: text.headlineMedium?.copyWith(fontSize: 30, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Your collection missed you',
                              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 24),
                            PillTextField(
                              fieldKey: const Key('login_email'),
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
                                onPressed: () => _comingSoon('Forgot password'), // TODO: Forgot Password screen
                                child: const Text('Forgot password?'),
                              ),
                            ),
                            if (_error != null) ...[
                              _ErrorBanner(message: _error!),
                              const SizedBox(height: 12),
                            ],
                            GradientButton(
                              key: const Key('login_submit'),
                              label: "Let's go!",
                              semanticLabel: 'Log in',
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('New here?', style: text.bodyMedium),
                                TextButton(
                                  onPressed: () => _comingSoon('Sign up'), // TODO: Register screen
                                  child: const Text('Create an account', style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                            // Only in debug builds: one-tap demo account for testing and the demo video
                            if (kDebugMode)
                              Center(
                                child: TextButton.icon(
                                  onPressed: _fillDemo,
                                  icon: const Icon(Icons.bolt_outlined, size: 18),
                                  label: const Text('Use demo account'),
                                ),
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

  /// Logo "mascot" floating gently, with a speech bubble that pops in.
  Widget _mascot() {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _float,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, -4 + 8 * Curves.easeInOut.transform(_float.value)),
            child: child,
          ),
          child: Image.asset('assets/logo_centered.png', width: 112, height: 112),
        ),
        const SizedBox(width: 4),
        ScaleTransition(
          scale: _bubblePop,
          alignment: Alignment.bottomLeft,
          child: const SpeechBubble(text: 'Hi again! ✨'),
        ),
      ],
    );
  }
}

/// Soft radial color blobs + a few sparkles behind the form.
class _Backdrop extends StatelessWidget {
  final bool dark;
  final Animation<double> twinkle;

  const _Backdrop({required this.dark, required this.twinkle});

  @override
  Widget build(BuildContext context) {
    final k = dark ? 0.55 : 1.0; // calmer blobs in dark mode
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        Widget blob(Color color, double alpha, double left, double top, double size) => Positioned(
              left: left * w,
              top: top * h,
              width: size * w,
              height: size * w,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [color.withValues(alpha: alpha * k), color.withValues(alpha: 0)],
                  ),
                ),
              ),
            );
        Widget sparkle(double left, double top, double size, Color color, double opacity) => Positioned(
              left: left * w,
              top: top * h,
              child: FadeTransition(
                opacity: Tween(begin: opacity * 0.4, end: opacity).animate(twinkle),
                child: Sparkle(size: size, color: color),
              ),
            );

        return IgnorePointer(
          child: Stack(
            children: [
              // Positions are fractions of the 412 x 917 Figma frame
              blob(const Color(0xFF22D3EE), 0.35, -0.29, -0.10, 0.87),
              blob(const Color(0xFFFB7185), 0.22, 0.61, 0.36, 0.68),
              blob(const Color(0xFF38BDF8), 0.30, -0.34, 0.70, 0.92),
              sparkle(0.80, 0.076, 18, AppTheme.accent, 0.8),
              sparkle(0.10, 0.33, 14, AppTheme.coral, 0.8),
              sparkle(0.87, 0.83, 16, AppTheme.primary, 0.6),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.sentiment_dissatisfied_outlined, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: scheme.onErrorContainer))),
        ],
      ),
    );
  }
}
