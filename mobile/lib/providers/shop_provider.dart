import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../services/shop_service.dart';

/// Wishlist hearts and the cart badge, shared by every product card.
/// Loads when a user signs in and clears on log out. Heart taps update
/// instantly and roll back if the server call fails.
class ShopProvider extends ChangeNotifier {
  final ShopService _service;

  ShopProvider({ShopService? service}) : _service = service ?? ShopService();

  bool _signedIn = false;
  Set<int> _wishlist = {};
  int _cartCount = 0;

  bool get signedIn => _signedIn;
  int get cartCount => _cartCount;
  bool isWishlisted(int productId) => _wishlist.contains(productId);

  /// Called by the provider tree whenever the auth state changes.
  void setSignedIn(bool value) {
    if (value == _signedIn) return;
    _signedIn = value;
    if (value) {
      refresh();
    } else {
      _wishlist = {};
      _cartCount = 0;
      // Called while the provider tree builds, so tell listeners afterwards
      Future.microtask(notifyListeners);
    }
  }

  Future<void> refresh() async {
    if (!_signedIn) return;
    try {
      final (ids, count) = await (_service.wishlistIds(), _service.cartCount()).wait;
      _wishlist = ids;
      _cartCount = count;
      notifyListeners();
    } catch (_) {
      // Hearts and the badge are extras; the screens show their own errors.
    }
  }

  /// Returns true when the product is now in the wishlist.
  /// Rolls back and rethrows [ApiException] if the server says no.
  Future<bool> toggleWishlist(int productId) async {
    final adding = !_wishlist.contains(productId);
    _set(productId, adding);
    try {
      adding ? await _service.addToWishlist(productId) : await _service.removeFromWishlist(productId);
      return adding;
    } on ApiException {
      _set(productId, !adding);
      rethrow;
    }
  }

  Future<void> addToCart(int productId, {int quantity = 1}) async {
    _cartCount = await _service.addToCart(productId, quantity: quantity);
    notifyListeners();
  }

  void _set(int productId, bool inWishlist) {
    _wishlist = {..._wishlist};
    inWishlist ? _wishlist.add(productId) : _wishlist.remove(productId);
    notifyListeners();
  }
}
