import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../shell/main_shell.dart';
import '../../widgets/sparkle.dart';

/// Light & clean splash: pale sky background, twinkling sparkles and an aqua
/// progress bar. Dark mode uses a navy version.
///
/// The first frame matches the native launch screen (flutter_native_splash in
/// pubspec.yaml): a small logo centered on a plain background. The logo then
/// grows and moves up while the background tint, title and sparkles fade in,
/// so there is no flash or jump when Flutter takes over.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1400);
  static const _logoSize = 230.0;
  // Native splash shows the logo at ~130dp; 130 / 230 ≈ 0.565
  static const _nativeLogoScale = 0.565;
  // Logo center sits this far above the screen center once the title is shown:
  // (logo 230 + gap 20 + title 36 + gap 6 + tagline 24 - logo 230) / 2
  static const _logoShift = 43.0;

  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();
  late final _progress = AnimationController(vsync: this, duration: _duration)..forward();
  late final _twinkle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  late final _logoMove = CurvedAnimation(parent: _intro, curve: Curves.easeOutBack);
  late final _bgFade = CurvedAnimation(parent: _intro, curve: const Interval(0, 0.7));
  late final _textFade = CurvedAnimation(parent: _intro, curve: const Interval(0.35, 1, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final auth = context.read<AuthProvider>();
    await Future.wait([auth.tryAutoLogin(), Future.delayed(_duration)]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => auth.isLoggedIn ? const MainShell() : const LoginScreen(),
    ));
  }

  @override
  void dispose() {
    _intro.dispose();
    _progress.dispose();
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = Theme.of(context).textTheme;

    // Base color = native splash color, so the first frame matches it exactly
    final baseColor = dark ? const Color(0xFF0B1220) : Colors.white;
    final tintColors = dark
        ? const [Color(0xFF0B1220), Color(0xFF0F1E33)]
        : const [Colors.white, Color(0xFFE0F2FE)];
    final titleColor = dark ? const Color(0xFF38BDF8) : AppTheme.primaryDark;
    final taglineColor = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: baseColor,
        body: Stack(
          children: [
            Positioned.fill(
              child: FadeTransition(
                opacity: _bgFade,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: tintColors,
                    ),
                  ),
                ),
              ),
            ),
            // Decorative sparkles: (x, y) as Flutter Alignment, size, color
            for (final s in _sparkles)
              Align(
                alignment: Alignment(s.x, s.y),
                child: FadeTransition(
                  opacity: _textFade,
                  child: FadeTransition(
                    opacity: Tween(begin: s.minOpacity, end: 1.0).animate(_twinkle),
                    child: Sparkle(size: s.size, color: s.color),
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _logoMove,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, _logoShift * (1 - _logoMove.value)),
                      child: Transform.scale(
                        scale: lerpDouble(_nativeLogoScale, 1, _logoMove.value),
                        child: child,
                      ),
                    ),
                    child: Image.asset('assets/logo_centered.png', width: _logoSize),
                  ),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _textFade,
                    child: Column(
                      children: [
                        Text(
                          'Anime World Shop',
                          style: text.headlineMedium?.copyWith(
                            color: titleColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Figures • Plush • Trading Cards',
                          style: text.bodyLarge?.copyWith(color: taglineColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.82),
              child: FadeTransition(
                opacity: _textFade,
                child: SizedBox(
                  width: 140,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (_, _) => LinearProgressIndicator(
                        value: _progress.value,
                        minHeight: 6,
                        color: AppTheme.accent,
                        backgroundColor: AppTheme.accent.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparkleSpec {
  final double x, y, size, minOpacity;
  final Color color;
  const _SparkleSpec(this.x, this.y, this.size, this.color, [this.minOpacity = 0.25]);
}

const _coral = Color(0xFFF43F5E);

// Minimum size 14 so small sparkles still read as stars on a real phone
const _sparkles = [
  _SparkleSpec(-0.75, -0.80, 22, AppTheme.primary),
  _SparkleSpec(0.70, -0.68, 14, AppTheme.accent, 0.4),
  _SparkleSpec(-0.35, -0.55, 14, _coral, 0.5),
  _SparkleSpec(0.85, -0.25, 18, AppTheme.primary, 0.3),
  _SparkleSpec(-0.88, 0.15, 14, AppTheme.accent),
  _SparkleSpec(0.78, 0.48, 20, AppTheme.accent, 0.3),
  _SparkleSpec(-0.62, 0.62, 16, _coral, 0.35),
  _SparkleSpec(0.30, 0.68, 14, AppTheme.primary, 0.5),
];
