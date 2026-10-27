import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/app_theme.dart';
import '../helpers/format.dart';

/// "Nice! Promo code applied" (picked option D): a card above the checkout bar
/// with a piggy-bank badge, a burst of sparkles and the saving counting up.
/// Shown as a floating SnackBar so it hides itself and on leaving the screen.
void showCouponApplied(BuildContext context, {required String code, required double saved}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      key: const Key('coupon_applied_toast'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.none,
      persist: false,
      duration: const Duration(seconds: 4),
      content: CouponAppliedCard(code: code, saved: saved),
    ));
}

class CouponAppliedCard extends StatelessWidget {
  final String code;
  final double saved;

  const CouponAppliedCard({super.key, required this.code, required this.saved});

  static const _badge = 48.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final card = dark ? scheme.surfaceContainerHigh : Colors.white;

    final amount = still
        ? Text('You saved ${formatPrice(saved)}', style: _amountStyle(scheme))
        // Counts up from $0 to the saving
        : Animate().custom(
            delay: 300.ms,
            duration: 800.ms,
            curve: Curves.easeOutCubic,
            builder: (_, t, _) => Text('You saved ${formatPrice((saved * t * 100).round() / 100)}', style: _amountStyle(scheme)),
          );

    Widget body = Semantics(
      liveRegion: true,
      label: 'Promo code $code applied. You saved ${formatPrice(saved)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: _badge / 2),
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, _badge / 2 + 4, 24, 18),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Nice! Promo code applied', style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              amount,
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(code, style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6)),
              ),
            ]),
          ),
          Positioned(
            top: -_badge / 2,
            child: Container(
              width: _badge,
              height: _badge,
              decoration: BoxDecoration(color: AppTheme.amber, shape: BoxShape.circle, border: Border.all(color: card, width: 4)),
              child: const Icon(Icons.savings_rounded, color: Colors.white, size: 24),
            ),
          ),
          if (!still)
            for (var i = 0; i < 10; i++) _Sparkle(index: i),
        ]),
      ),
    );
    if (!still) body = body.animate().fadeIn(duration: 200.ms).scaleXY(begin: 0.6, end: 1, duration: 500.ms, curve: Curves.easeOutBack);
    return Center(child: body);
  }

  TextStyle _amountStyle(ColorScheme scheme) => TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: scheme.onSurface);
}

/// One of the little stars flying out of the badge.
class _Sparkle extends StatelessWidget {
  final int index;

  const _Sparkle({required this.index});

  @override
  Widget build(BuildContext context) {
    // A fan over the badge, so no star crosses the text below it
    final angle = -math.pi + index * math.pi / 9;
    final even = index.isEven;
    return Positioned(
      top: -CouponAppliedCard._badge / 2 + 16,
      child: IgnorePointer(
        child: Icon(
          even ? Icons.auto_awesome : Icons.star_rounded,
          size: even ? 16 : 12,
          color: index % 3 == 0 ? AppTheme.success : AppTheme.amber,
        )
            .animate(delay: 300.ms)
            .move(begin: Offset.zero, end: Offset(math.cos(angle) * 84, math.sin(angle) * 50 - 6), duration: 800.ms, curve: Curves.easeOutCubic)
            .scaleXY(begin: 0.3, end: 1, duration: 300.ms)
            .then(delay: 200.ms)
            .fadeOut(duration: 400.ms),
      ),
    );
  }
}
