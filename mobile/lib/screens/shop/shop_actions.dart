import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../models/cart.dart';
import '../../models/catalog.dart';
import '../../providers/shop_provider.dart';
import '../../services/catalog_service.dart';
import '../../widgets/cart_drive.dart';
import '../../widgets/product_image.dart';
import '../../widgets/login_required.dart';
import '../catalog/product_details_screen.dart';
import '../shell/main_shell.dart';

/// What happens when a product card's heart or plus is tapped, the same on
/// every screen: guests get the "Log in to continue" pop-up (and the action
/// goes on once they have logged in), errors show in a SnackBar.
class ShopActions {
  static void _snack(BuildContext context, String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action, persist: false, duration: const Duration(seconds: 4), behavior: SnackBarBehavior.floating));
  }

  /// True once the guest has logged in from the pop-up.
  static Future<bool> askToLogin(BuildContext context, String message, {IconData icon = Icons.lock_rounded}) =>
      showLoginRequired(context, message: message, icon: icon);

  static Future<void> toggleWishlist(BuildContext context, Product product) async {
    final shop = context.read<ShopProvider>();
    if (!shop.signedIn) {
      final ok = await askToLogin(context, 'Log in to save items to your wishlist.', icon: Icons.favorite_rounded);
      if (!ok || !context.mounted) return;
    }
    try {
      final added = await shop.toggleWishlist(product.id);
      if (context.mounted) _snack(context, added ? 'Saved to your wishlist' : 'Removed from your wishlist');
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, e.message);
    }
  }

  /// Returns the updated cart. Shows the "Added to cart" toast unless [toast]
  /// is false (Product Details shows its own sheet instead).
  /// Throws when nothing was added, so the card keeps its plus icon.
  static Future<Cart> addToCart(BuildContext context, Product product, {int quantity = 1, bool toast = true}) async {
    final shop = context.read<ShopProvider>();
    if (!shop.signedIn) {
      final ok = await askToLogin(context, 'Log in to add items to your cart.', icon: Icons.shopping_bag_rounded);
      if (!ok || !context.mounted) throw StateError('not signed in');
    }
    try {
      final cart = await shop.addToCart(product.id, quantity: quantity);
      if (toast && context.mounted) _addedToast(context, product, quantity);
      return cart;
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, e.message);
      rethrow;
    }
  }

  /// Dark floating toast with the photo, name and a View button
  /// (Figma: Add to cart C - Toast). It waits until the delivery cart has
  /// arrived, so the two never overlap at the bottom of the screen.
  static void _addedToast(BuildContext context, Product product, int quantity) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    messenger.hideCurrentSnackBar();

    void show() => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        key: const Key('added_toast'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? scheme.surfaceContainerHighest : const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.all(10),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            SizedBox.square(
              dimension: 48,
              child: ProductImage(url: product.imageUrl, kind: product.category.kind, iconSize: 22, borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quantity == 1 ? 'Added to cart' : 'Added $quantity to cart',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('added_toast_view'),
              onPressed: () {
                ScaffoldMessenger.maybeOf(navigator.context)?.hideCurrentSnackBar();
                openCart(navigator);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF0F172A),
                minimumSize: const Size(64, 40),
                shape: const StadiumBorder(),
              ),
              child: const Text('View', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ));

    // The card starts the drive right after this returns, so wait for this frame first.
    SchedulerBinding.instance.addPostFrameCallback((_) => CartDrive.whenIdle(() {
          if (messenger.mounted) show();
        }));
  }

  /// Goes back to the main tabs and shows the Cart tab.
  static void openCart(NavigatorState navigator) {
    navigator.popUntil((route) => route.isFirst);
    MainShell.requestedTab.value = MainShell.cartTab;
  }

  static void openProduct(BuildContext context, Product product, {CatalogService? catalog}) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product, catalogService: catalog)),
      );
}
