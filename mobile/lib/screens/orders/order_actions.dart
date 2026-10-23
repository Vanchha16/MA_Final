import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/format.dart';
import '../../models/order.dart';
import '../../providers/shop_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/action_prompt.dart';
import '../shop/shop_actions.dart';

/// Shared by My orders and Order details.
class OrderActions {
  static const cancelReasons = ['Changed my mind', 'Ordered by mistake', 'Found a better price', 'It takes too long'];

  /// "Cancel this order?" with optional reason chips. Returns the reason ('' for
  /// none) when the customer confirms, null when they keep the order.
  static Future<String?> askToCancel(BuildContext context, Order order) async {
    final reason = ValueNotifier<String?>(null);
    final paidOnline = order.paymentStatus == 'paid' && order.paymentMethod.online;
    final choice = await showActionPrompt(
      context,
      keyPrefix: 'cancel_order',
      icon: Icons.remove_shopping_cart_rounded,
      danger: true,
      title: 'Cancel this order?',
      message: paidOnline
          ? 'We put the items back on sale and send ${formatPrice(order.total)} back to you within 3 working days.'
          : 'We put the items back on sale. This can\'t be undone.',
      extra: _ReasonChips(reason: reason),
      primaryLabel: 'Cancel order',
      primaryIcon: Icons.close_rounded,
      laterLabel: 'Keep my order',
    );
    final picked = reason.value;
    reason.dispose();
    return choice == 'primary' ? (picked ?? '') : null;
  }

  /// Puts every product of [order] back in the cart (same amounts). Items that
  /// are sold out or no longer sold are skipped and counted in the message.
  static Future<void> buyAgain(BuildContext context, Order order) async {
    final shop = context.read<ShopProvider>();
    final navigator = Navigator.of(context);
    var added = 0, skipped = 0;
    for (final line in order.lines) {
      if (line.productId == null) {
        skipped++;
        continue;
      }
      try {
        await shop.addToCart(line.productId!, quantity: line.quantity);
        added += line.quantity;
      } on ApiException {
        skipped++;
      }
    }
    if (!context.mounted) return;
    final what = added == 1 ? '1 item' : '$added items';
    if (added == 0) return AppToast.warning(context, 'These items are not available right now');
    AppToast.success(
      context,
      skipped == 0 ? 'Added $what to your cart' : 'Added $what to your cart. $skipped no longer available.',
      action: 'View',
      onAction: () => ShopActions.openCart(navigator),
    );
  }
}

/// "Why are you cancelling?" chips (optional, one at a time).
class _ReasonChips extends StatelessWidget {
  final ValueNotifier<String?> reason;

  const _ReasonChips({required this.reason});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
        valueListenable: reason,
        builder: (context, picked, _) => Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, r) in OrderActions.cancelReasons.indexed)
              ChoiceChip(
                key: Key('cancel_reason_$i'),
                label: Text(r),
                selected: picked == r,
                showCheckmark: false,
                shape: const StadiumBorder(),
                onSelected: (on) => reason.value = on ? r : null,
              ),
          ],
        ),
      );
}
