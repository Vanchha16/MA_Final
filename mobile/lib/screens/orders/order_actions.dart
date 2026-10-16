import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../models/order.dart';
import '../../providers/shop_provider.dart';
import '../shop/shop_actions.dart';

/// Shared by My orders and Order details.
class OrderActions {
  static void snack(BuildContext context, String message, {SnackBarAction? action}) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action, persist: false, behavior: SnackBarBehavior.floating));

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
    snack(
      context,
      added == 0
          ? 'These items are not available right now'
          : skipped == 0
              ? 'Added $what to your cart'
              : 'Added $what to your cart. $skipped no longer available.',
      action: added == 0 ? null : SnackBarAction(label: 'View', onPressed: () => ShopActions.openCart(navigator)),
    );
  }
}
