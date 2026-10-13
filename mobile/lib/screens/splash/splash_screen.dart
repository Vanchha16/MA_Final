import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';

/// Light & clean splash: pale sky background, logo zooms in, twinkling
/// sparkles and an aqua progress bar. Dark mode uses a navy version.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 2200);

  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();
  late final _progress = AnimationController(vsync: this, duration: _duration)..forward();
  late final _twinkle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  late final _logoScale = CurvedAnimation(parent: _intro, curve: Curves.easeOutBack);
  late final _logoFade = CurvedAnimation(parent: _intro, curve: const Interval(0, 0.6));
  late final _textFade = CurvedAnimation(parent: _intro, curve: const Interval(0.4, 1, curve: Curves.easeOut));

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
      builder: (_) => auth.isLoggedIn ? const HomeScreen() : const LoginScreen(),
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

    final bgColors = dark
        ? const [Color(0xFF0B1220), Color(0xFF0F1E33)]
        : const [Colors.white, Color(0xFFE0F2FE)];
    final titleColor = dark ? const Color(0xFF38BDF8) : AppTheme.primaryDark;
    final taglineColor = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: bgColors,
            ),
          ),
          child: Stack(
            children: [
              // Decorative sparkles: (x, y) as a fraction of the screen, size, color
              for (final s in _sparkles)
                Align(
                  alignment: Alignment(s.x, s.y),
                  child: FadeTransition(
                    opacity: Tween(begin: s.minOpacity, end: 1.0).animate(_twinkle),
                    child: _Sparkle(size: s.size, color: s.color),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.6, end: 1.0).animate(_logoScale),
                        child: Image.asset('assets/logo_centered.png', width: 230),
                      ),
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
            ],
          ),
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

const _sparkles = [
  _SparkleSpec(-0.75, -0.80, 22, AppTheme.primary),
  _SparkleSpec(0.70, -0.68, 14, AppTheme.accent, 0.4),
  _SparkleSpec(-0.35, -0.55, 10, _coral, 0.5),
  _SparkleSpec(0.85, -0.25, 18, AppTheme.primary, 0.3),
  _SparkleSpec(-0.88, 0.15, 12, AppTheme.accent),
  _SparkleSpec(0.78, 0.48, 20, AppTheme.accent, 0.3),
  _SparkleSpec(-0.62, 0.62, 16, _coral, 0.35),
  _SparkleSpec(0.30, 0.68, 10, AppTheme.primary, 0.5),
];

/// Four-point anime-style sparkle.
class _Sparkle extends StatelessWidget {
  final double size;
  final Color color;

  const _Sparkle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SparklePainter(color));
}

class _SparklePainter extends CustomPainter {
  final Color color;

  _SparklePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, cx = w / 2, cy = h / 2;
    final path = Path()
      ..moveTo(cx, 0)
      ..quadraticBezierTo(cx, cy, w, cy)
      ..quadraticBezierTo(cx, cy, cx, h)
      ..quadraticBezierTo(cx, cy, 0, cy)
      ..quadraticBezierTo(cx, cy, cx, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}
