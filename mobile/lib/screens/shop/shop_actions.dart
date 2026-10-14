import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../models/catalog.dart';
import '../../providers/shop_provider.dart';
import '../../services/catalog_service.dart';
import '../auth/login_screen.dart';
import '../catalog/product_details_screen.dart';

/// What happens when a product card's heart or plus is tapped, the same on
/// every screen: guests are asked to log in, errors show in a SnackBar.
class ShopActions {
  static void _snack(BuildContext context, String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action, behavior: SnackBarBehavior.floating));
  }

  static void askToLogin(BuildContext context, String message) => _snack(
        context,
        message,
        action: SnackBarAction(
          label: 'Log in',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
        ),
      );

  static Future<void> toggleWishlist(BuildContext context, Product product) async {
    final shop = context.read<ShopProvider>();
    if (!shop.signedIn) return askToLogin(context, 'Log in to save items to your wishlist');
    try {
      final added = await shop.toggleWishlist(product.id);
      if (context.mounted) _snack(context, added ? 'Saved to your wishlist' : 'Removed from your wishlist');
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, e.message);
    }
  }

  /// Throws when nothing was added, so the card keeps its plus icon.
  static Future<void> addToCart(BuildContext context, Product product, {int quantity = 1}) async {
    final shop = context.read<ShopProvider>();
    if (!shop.signedIn) {
      askToLogin(context, 'Log in to add items to your cart');
      throw StateError('not signed in');
    }
    try {
      await shop.addToCart(product.id, quantity: quantity);
      if (context.mounted) _snack(context, quantity == 1 ? 'Added to cart' : 'Added $quantity to cart');
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, e.message);
      rethrow;
    }
  }

  static void openProduct(BuildContext context, Product product, {CatalogService? catalog}) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product, catalogService: catalog)),
      );
}
