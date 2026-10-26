import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/order.dart';

/// A payment method's logo (picked option A): the Bakong mark on Bakong red for
/// KHQR, ABA's round logo for ABA PayWay, a cash icon for cash on delivery.
/// Used at checkout and on the admin Payment methods page.
class PaymentLogo extends StatelessWidget {
  final PaymentMethod method;

  const PaymentLogo(this.method, {super.key});

  static const _size = 44.0;

  @override
  Widget build(BuildContext context) {
    final (Color background, Widget child) = switch (method) {
      PaymentMethod.khqr => (AppTheme.bakongRed, Image.asset('assets/payment/bakong.png', key: const Key('pay_logo_khqr'), width: 35, semanticLabel: 'Bakong KHQR')),
      PaymentMethod.aba => (Colors.transparent, Image.asset('assets/payment/aba.png', key: const Key('pay_logo_aba'), width: _size, height: _size, semanticLabel: 'ABA Bank')),
      PaymentMethod.cod => (AppTheme.success.withValues(alpha: 0.13), const Icon(Icons.payments_rounded, color: AppTheme.success, size: 24)),
    };
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(13)),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
