import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/order.dart';

/// Placed / Paid / Shipped / Delivered with ticks that pop in one by one and a
/// line that grows (picked from the order-history previews, C). When the order
/// moves on (e.g. after "Got it") it animates from where it was. The current
/// step pulses.
class OrderTracker extends StatelessWidget {
  final Order order;

  /// Wait before filling on first show, so cards fill one after another.
  final Duration delay;
  final bool large;

  /// False shows it already filled (e.g. after a refresh, or a card leaving the list).
  final bool fillOnShow;

  const OrderTracker({super.key, required this.order, this.delay = Duration.zero, this.large = false, this.fillOnShow = true});

  List<String> get _labels {
    final pickup = order.deliveryMethod == DeliveryMethod.pickup;
    return ['Placed', order.paymentMethod == PaymentMethod.cod ? 'Confirmed' : 'Paid', pickup ? 'Ready' : 'Shipped', pickup ? 'Picked up' : 'Delivered'];
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final done = order.stepsDone.toDouble();
    return _Delayed(
      delay: reduceMotion || !fillOnShow ? Duration.zero : delay,
      builder: (started) => TweenAnimationBuilder<double>(
        key: const Key('order_tracker'),
        tween: Tween(begin: fillOnShow ? 0 : done, end: started || !fillOnShow ? done : 0),
        duration: reduceMotion ? Duration.zero : Duration(milliseconds: 220 * order.stepsDone + 200),
        curve: Curves.easeInOut,
        builder: (context, p, _) =>
            _Steps(progress: p, labels: _labels, current: order.stage.active ? order.stepsDone : null, large: large, reduceMotion: reduceMotion),
      ),
    );
  }
}

/// Builds with false until [delay] has passed, then true (only once).
class _Delayed extends StatefulWidget {
  final Duration delay;
  final Widget Function(bool started) builder;

  const _Delayed({required this.delay, required this.builder});

  @override
  State<_Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<_Delayed> {
  late bool _started = widget.delay == Duration.zero;

  @override
  void initState() {
    super.initState();
    if (!_started) {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _started = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(_started);
}

class _Steps extends StatelessWidget {
  final double progress;
  final List<String> labels;

  /// Index of the step being waited for, or null when the order is over.
  final int? current;
  final bool large, reduceMotion;

  const _Steps({required this.progress, required this.labels, required this.current, required this.large, required this.reduceMotion});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final idle = dark ? scheme.surfaceContainerHighest : const Color(0xFFE2E8F0);
    final dot = large ? 28.0 : 22.0;
    final children = <Widget>[];
    for (var i = 0; i < 4; i++) {
      final tick = Curves.easeOutBack.transform((progress - i).clamp(0.0, 1.0));
      final isCurrent = current == i && progress >= i - 0.01;
      Widget circle = Container(
        width: dot,
        height: dot,
        decoration: BoxDecoration(shape: BoxShape.circle, color: isCurrent ? scheme.primary : idle),
        child: isCurrent ? Icon(Icons.circle, size: dot * 0.36, color: scheme.onPrimary) : null,
      );
      if (isCurrent && !reduceMotion) {
        circle = Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary.withValues(alpha: 0.35)),
            ).animate(onPlay: (c) => c.repeat()).scaleXY(begin: 1, end: 1.9, duration: 1100.ms, curve: Curves.easeOut).fadeOut(duration: 1100.ms),
            circle,
          ],
        );
      }
      children.add(
        Column(
          children: [
            SizedBox.square(
              dimension: dot,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  circle,
                  if (tick > 0)
                    Opacity(
                      opacity: tick.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: math.max(tick, 0),
                        child: Container(
                          key: Key('step_done_$i'),
                          width: dot,
                          height: dot,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.success),
                          child: Icon(Icons.check_rounded, size: dot * 0.64, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: large ? 64 : 54,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  labels[i],
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: large ? 12 : 10.5,
                    fontWeight: current == i ? FontWeight.bold : FontWeight.w500,
                    color: i < progress.round() || current == i ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      if (i < 3) {
        children.add(
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: dot / 2 - 1.5, left: 2, right: 2), // through the middle of the dots
              child: Stack(
                children: [
                  Container(
                    height: 3,
                    decoration: BoxDecoration(color: idle, borderRadius: BorderRadius.circular(2)),
                  ),
                  FractionallySizedBox(
                    widthFactor: (progress - (i + 1)).clamp(0.0, 1.0),
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(color: AppTheme.success, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

/// The line under the tracker: what is happening now.
(String, Color, IconData) orderStatusLine(BuildContext context, Order order) {
  final pickup = order.deliveryMethod == DeliveryMethod.pickup;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final primary = Theme.of(context).colorScheme.primary;
  const violet = Color(0xFF7C3AED);
  return switch (order.stage) {
    OrderStage.toPay => ('Waiting for your KHQR payment', dark ? AppTheme.amber : const Color(0xFFB45309), Icons.qr_code_2_rounded),
    OrderStage.waitingConfirm => ('Waiting for the shop to confirm', primary, Icons.hourglass_top_rounded),
    OrderStage.packing => (pickup ? 'Packing your order · ready soon' : 'Packing your order · ships soon', primary, Icons.inventory_2_rounded),
    OrderStage.onTheWay => (
      pickup ? 'Ready to pick up at our Toul Kork shop' : 'On the way · arrives tomorrow, 9:00 - 18:00',
      dark ? const Color(0xFFA78BFA) : violet,
      pickup ? Icons.storefront_rounded : Icons.local_shipping_rounded,
    ),
    OrderStage.delivered => ('Delivered · enjoy your order!', AppTheme.success, Icons.celebration_rounded),
    OrderStage.cancelled => ('Cancelled', Theme.of(context).colorScheme.onSurfaceVariant, Icons.cancel_rounded),
  };
}
