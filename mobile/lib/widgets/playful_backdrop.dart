import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'sparkle.dart';

/// A soft radial color blob. Positions/sizes are fractions of the screen width
/// (size, left) and height (top), taken from the 412 x 917 Figma frames.
class BlobSpec {
  final Color color;
  final double alpha, left, top, size;
  const BlobSpec(this.color, this.alpha, this.left, this.top, this.size);
}

class SparkleSpot {
  final double left, top, size, opacity;
  final Color color;
  const SparkleSpot(this.left, this.top, this.size, this.color, this.opacity);
}

/// Playful background used by the auth screens: pastel blobs + twinkling sparkles.
class PlayfulBackdrop extends StatefulWidget {
  final List<BlobSpec> blobs;
  final List<SparkleSpot> sparkles;

  const PlayfulBackdrop({super.key, required this.blobs, required this.sparkles});

  static const _aqua = Color(0xFF22D3EE);
  static const _coral = Color(0xFFFB7185);
  static const _sky = Color(0xFF38BDF8);

  /// Figma: 03 - Login
  const PlayfulBackdrop.login({super.key})
      : blobs = const [
          BlobSpec(_aqua, 0.35, -0.29, -0.10, 0.87),
          BlobSpec(_coral, 0.22, 0.61, 0.36, 0.68),
          BlobSpec(_sky, 0.30, -0.34, 0.70, 0.92),
        ],
        sparkles = const [
          SparkleSpot(0.80, 0.076, 18, AppTheme.accent, 0.8),
          SparkleSpot(0.10, 0.33, 14, AppTheme.coral, 0.8),
          SparkleSpot(0.87, 0.83, 16, AppTheme.primary, 0.6),
        ];

  /// Figma: 04 - Register
  const PlayfulBackdrop.register({super.key})
      : blobs = const [
          BlobSpec(_aqua, 0.32, 0.46, -0.13, 0.83),
          BlobSpec(_coral, 0.20, -0.36, 0.33, 0.73),
          BlobSpec(_sky, 0.28, 0.44, 0.71, 0.87),
        ],
        sparkles = const [
          SparkleSpot(0.85, 0.105, 16, AppTheme.accent, 0.8),
          SparkleSpot(0.93, 0.43, 12, AppTheme.coral, 0.8),
          SparkleSpot(0.06, 0.93, 14, AppTheme.primary, 0.6),
        ];

  @override
  State<PlayfulBackdrop> createState() => _PlayfulBackdropState();
}

class _PlayfulBackdropState extends State<PlayfulBackdrop> with SingleTickerProviderStateMixin {
  late final _twinkle = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _twinkle.value = 1;
      _twinkle.stop();
    } else if (!_twinkle.isAnimating) {
      _twinkle.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final k = dark ? 0.55 : 1.0; // calmer blobs in dark mode

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return Stack(
            children: [
              for (final b in widget.blobs)
                Positioned(
                  left: b.left * w,
                  top: b.top * h,
                  width: b.size * w,
                  height: b.size * w,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [b.color.withValues(alpha: b.alpha * k), b.color.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              for (final s in widget.sparkles)
                Positioned(
                  left: s.left * w,
                  top: s.top * h,
                  child: FadeTransition(
                    opacity: Tween(begin: s.opacity * 0.4, end: s.opacity).animate(_twinkle),
                    child: Sparkle(size: s.size, color: s.color),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
