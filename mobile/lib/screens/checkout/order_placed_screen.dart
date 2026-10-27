import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import '../../helpers/format.dart';
import '../../models/order.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/pill_button.dart';
import '../orders/orders_screen.dart';
import '../shell/main_shell.dart';
import 'khqr_payment_screen.dart';

/// Shown right after Place order: the order number, what happens next
/// (pay with KHQR, or pay the rider / at the shop) and where to go now.
class OrderPlacedScreen extends StatelessWidget {
  final Order order;

  const OrderPlacedScreen({super.key, required this.order});

  void _backToShop(BuildContext context, int tab) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    MainShell.requestedTab.value = tab;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final khqr = order.paymentMethod.online;
    final pickup = order.deliveryMethod == DeliveryMethod.pickup;

    Widget check = Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: dark ? 0.2 : 0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            color: AppTheme.success,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 46),
        ),
      ),
    );
    if (!reduceMotion) {
      check = check
          .animate()
          .scaleXY(begin: 0.3, duration: 450.ms, curve: Curves.easeOutBack)
          .fadeIn(duration: 200.ms);
    }

    Widget row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToShop(context, 0);
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            children: [
              Center(child: check),
              const SizedBox(height: 20),
              Text(
                'Order placed!',
                key: const Key('placed_title'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                khqr
                    ? 'One more step: pay with ${order.paymentMethod.shortName} to confirm it.'
                    : 'Thank you! We are getting it ready.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Center(
                child: ActionChip(
                  key: const Key('placed_number'),
                  avatar: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(
                    order.number,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: order.number));
                    AppToast.success(context, 'Order number copied');
                  },
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: dark ? scheme.surfaceContainer : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    if (!dark)
                      BoxShadow(
                        color: AppTheme.primaryDark.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                  ],
                ),
                child: Column(
                  children: [
                    row(
                      Icons.shopping_bag_outlined,
                      'Items',
                      '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
                    ),
                    row(
                      pickup
                          ? Icons.storefront_rounded
                          : Icons.local_shipping_outlined,
                      pickup ? 'Pick up' : 'Deliver to',
                      pickup
                          ? 'Today at our Toul Kork shop'
                          : (order.shippingAddress ?? ''),
                    ),
                    if (!pickup)
                      row(
                        Icons.schedule_rounded,
                        'Arrives',
                        'Tomorrow, 9:00 - 18:00',
                      ),
                    row(
                      switch (order.paymentMethod) {
                        PaymentMethod.khqr => Icons.qr_code_2_rounded,
                        PaymentMethod.aba => Icons.account_balance_rounded,
                        PaymentMethod.cod => Icons.payments_outlined,
                      },
                      'Payment',
                      order.paymentMethod.label,
                    ),
                    const Divider(height: 22),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          formatPrice(order.total),
                          key: const Key('placed_total'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                key: const Key('placed_next'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (khqr ? AppTheme.amber : AppTheme.success).withValues(
                    alpha: dark ? 0.18 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      khqr
                          ? Icons.hourglass_top_rounded
                          : Icons.payments_rounded,
                      color: khqr
                          ? (dark ? AppTheme.amber : const Color(0xFFB45309))
                          : AppTheme.success,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        khqr
                            ? 'Waiting for your payment of ${formatPrice(order.total)}.'
                            : 'Pay ${formatPrice(order.total)} ${pickup ? 'at the shop' : 'to the rider'} in USD or riel.',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (khqr) ...[
                PillButton(
                  key: const Key('placed_pay'),
                  label: 'Pay ${formatPrice(order.total)} with ${order.paymentMethod.shortName}',
                  leadingIcon: order.paymentMethod == PaymentMethod.aba ? Icons.account_balance_rounded : Icons.qr_code_2_rounded,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => KhqrPaymentScreen(order: order))),
                ),
                const SizedBox(height: 12),
              ],
              PillButton(
                key: const Key('placed_shop'),
                label: 'Continue shopping',
                leadingIcon: Icons.storefront_outlined,
                color: khqr
                    ? (dark ? scheme.surfaceContainerHighest : AppTheme.skyTint)
                    : null,
                foregroundColor: khqr ? scheme.primary : null,
                onPressed: () => _backToShop(context, 0),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('placed_orders'),
                onPressed: () {
                  final navigator = Navigator.of(context)..popUntil((route) => route.isFirst);
                  navigator.push(MaterialPageRoute(builder: (_) => const OrdersScreen()));
                },
                child: const Text('View my orders'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
