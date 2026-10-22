import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/app_theme.dart';
import 'pill_button.dart';

/// The animated pop-up shared by "Log in to continue", "Add a delivery address"
/// and "Cancel this order?": an icon, a title, a message, an optional extra
/// widget (e.g. reason chips), a solid primary button (red when [danger]), an
/// optional outlined second button and a "not now" link.
///
/// It springs in (fade, scale from 85% with a little overshoot, rises a few
/// pixels) and shrinks away quickly; the icon pops with a bounce and one ripple,
/// and the text and buttons slide up in turn. With "reduce motion" on it only fades.
/// Returns 'primary', 'secondary', or null for "not now" / tapping outside.
Future<String?> showActionPrompt(
  BuildContext context, {
  required String keyPrefix,
  required IconData icon,
  required String title,
  required String message,
  required String primaryLabel,
  required IconData primaryIcon,
  String? secondaryLabel,
  String laterLabel = 'Not now',
  Widget? extra,
  bool danger = false,
}) {
  final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black54,
    transitionDuration: Duration(milliseconds: reduceMotion ? 150 : 360),
    pageBuilder: (_, _, _) => _ActionPrompt(
      keyPrefix: keyPrefix,
      icon: icon,
      title: title,
      message: message,
      primaryLabel: primaryLabel,
      primaryIcon: primaryIcon,
      secondaryLabel: secondaryLabel,
      laterLabel: laterLabel,
      extra: extra,
      danger: danger,
      reduceMotion: reduceMotion,
    ),
    transitionBuilder: (_, animation, _, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut, reverseCurve: Curves.easeIn);
      if (reduceMotion) return FadeTransition(opacity: fade, child: child);
      final spring = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(spring),
          child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(spring), child: child),
        ),
      );
    },
  );
}

class _ActionPrompt extends StatelessWidget {
  final String keyPrefix, title, message, primaryLabel, laterLabel;
  final String? secondaryLabel;
  final IconData icon, primaryIcon;
  final Widget? extra;

  /// Red icon and a solid red primary button, for things like cancelling.
  final bool danger;
  final bool reduceMotion;

  const _ActionPrompt({
    required this.keyPrefix,
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.secondaryLabel,
    required this.laterLabel,
    required this.extra,
    required this.danger,
    required this.reduceMotion,
  });

  /// The icon pops in with a bounce and one ring ripples out behind it.
  Widget _icon(ColorScheme scheme) {
    final tint = danger ? AppTheme.danger : scheme.primary;
    final circle = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Icon(icon, color: tint, size: 30),
    );
    if (reduceMotion) return circle;
    final ring = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: tint.withValues(alpha: 0.45), width: 2)),
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        // Hidden until it starts, then grows and fades out
        ring.animate(delay: 260.ms).custom(
          duration: 750.ms,
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Opacity(opacity: v == 0 ? 0 : 0.9 * (1 - v), child: Transform.scale(scale: 1 + 0.7 * v, child: child)),
        ),
        circle.animate(delay: 120.ms).scaleXY(begin: 0.3, end: 1, duration: 650.ms, curve: Curves.elasticOut).fadeIn(duration: 160.ms),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = secondaryLabel;
    return Dialog(
      key: Key(keyPrefix),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: _icon(scheme)),
            const SizedBox(height: 14),
            ...[
                  Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 22),
                    child: Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant)),
                  ),
                  if (extra != null) Padding(padding: const EdgeInsets.only(bottom: 20), child: extra),
                ]
                .animate(interval: 60.ms, delay: 140.ms)
                .fadeIn(duration: reduceMotion ? 1.ms : 280.ms)
                .moveY(begin: reduceMotion ? 0 : 10, end: 0, duration: 320.ms, curve: Curves.easeOutCubic),
            ...[
                  danger
                      ? PillButton.danger(
                          key: Key('${keyPrefix}_primary'),
                          label: primaryLabel,
                          leadingIcon: primaryIcon,
                          onPressed: () => Navigator.of(context).pop('primary'),
                        )
                      : PillButton(
                          key: Key('${keyPrefix}_primary'),
                          label: primaryLabel,
                          leadingIcon: primaryIcon,
                          onPressed: () => Navigator.of(context).pop('primary'),
                        ),
                  if (secondary != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: OutlinedButton(
                        key: Key('${keyPrefix}_secondary'),
                        onPressed: () => Navigator.of(context).pop('secondary'),
                        style: OutlinedButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size(0, 52)),
                        child: Text(secondary, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton(key: Key('${keyPrefix}_later'), onPressed: () => Navigator.of(context).pop(), child: Text(laterLabel)),
                  ),
                ]
                .animate(interval: 60.ms, delay: 260.ms)
                .fadeIn(duration: reduceMotion ? 1.ms : 280.ms)
                .moveY(begin: reduceMotion ? 0 : 14, end: 0, duration: 340.ms, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }
}
