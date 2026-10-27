import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/cart.dart';
import '../models/catalog.dart';
import '../services/shop_service.dart';

/// Wishlist hearts, the cart badge and the bell's unread count, shared by every screen.
/// Loads when a user signs in and clears on log out. Heart taps update
/// instantly and roll back if the server call fails.
class ShopProvider extends ChangeNotifier {
  final ShopService _service;

  ShopProvider({ShopService? service}) : _service = service ?? ShopService();

  bool _signedIn = false;
  Set<int> _wishlist = {};

  /// Products whose heart request is still on its way; more taps on them wait.
  final _heartBusy = <int>{};
  int _cartCount = 0;
  int _unread = 0;

  bool get signedIn => _signedIn;
  int get cartCount => _cartCount;
  int get unreadNotifications => _unread;
  bool isWishlisted(int productId) => _wishlist.contains(productId);

  /// The saved product ids, so the Wishlist tab can notice hearts tapped elsewhere.
  Set<int> get wishlistIds => _wishlist;

  /// Called by the provider tree whenever the auth state changes.
  void setSignedIn(bool value) {
    if (value == _signedIn) return;
    _signedIn = value;
    if (value) {
      refresh();
    } else {
      _wishlist = {};
      _cartCount = 0;
      _unread = 0;
      // Called while the provider tree builds, so tell listeners afterwards
      Future.microtask(notifyListeners);
    }
  }

  Future<void> refresh() async {
    if (!_signedIn) return;
    try {
      final (ids, count, unread) = await (_service.wishlistIds(), _service.cartCount(), _service.unreadNotifications()).wait;
      _wishlist = ids;
      _cartCount = count;
      _unread = unread;
      notifyListeners();
    } catch (_) {
      // Hearts and the badge are extras; the screens show their own errors.
    }
  }

  /// Returns true when the product is now in the wishlist, false when it was
  /// taken off, and null when a request for it is still on its way (a quick
  /// second tap is ignored, so an "add" and a "remove" can't race on the server).
  /// Rolls back and rethrows [ApiException] if the server says no.
  Future<bool?> toggleWishlist(int productId) async {
    if (!_heartBusy.add(productId)) return null;
    final adding = !_wishlist.contains(productId);
    _set(productId, adding);
    try {
      adding ? await _service.addToWishlist(productId) : await _service.removeFromWishlist(productId);
      return adding;
    } on ApiException {
      _set(productId, !adding);
      rethrow;
    } finally {
      _heartBusy.remove(productId);
    }
  }

  /// The saved products for the Wishlist tab (also refreshes the hearts).
  Future<List<Product>> loadWishlist() async {
    final items = await _service.wishlistItems();
    _setIds({for (final p in items) p.id});
    return items;
  }

  Future<void> removeManyFromWishlist(List<int> productIds) async => _setIds(await _service.removeManyFromWishlist(productIds));

  /// Undo for a removal.
  Future<void> restoreWishlist(List<int> productIds) async => _setIds(await _service.addManyToWishlist(productIds));

  Future<MoveToCartResult> moveToCart(List<int> productIds) async {
    final result = await _service.moveToCart(productIds);
    _cartCount = result.cartCount;
    _setIds(result.wishlistIds);
    return result;
  }

  void _setIds(Set<int> ids) {
    _wishlist = ids;
    notifyListeners();
  }

  /// The Notifications screen reports the count after each change.
  void setUnreadNotifications(int count) {
    if (count == _unread) return;
    _unread = count;
    notifyListeners();
  }

  /// Checks for new messages (e.g. after placing an order or coming back to a screen).
  Future<void> refreshUnread() async {
    if (!_signedIn) return;
    try {
      setUnreadNotifications(await _service.unreadNotifications());
    } catch (_) {
      // Only the badge
    }
  }

  /// The Cart screen reports the count after each change it makes.
  void setCartCount(int count) {
    if (count == _cartCount) return;
    _cartCount = count;
    notifyListeners();
  }

  /// Returns the updated cart, for the "Added to your cart" sheet.
  Future<Cart> addToCart(int productId, {int quantity = 1}) async {
    final cart = await _service.addToCart(productId, quantity: quantity);
    _cartCount = cart.count;
    notifyListeners();
    return cart;
  }

  void _set(int productId, bool inWishlist) {
    _wishlist = {..._wishlist};
    inWishlist ? _wishlist.add(productId) : _wishlist.remove(productId);
    notifyListeners();
  }
}
