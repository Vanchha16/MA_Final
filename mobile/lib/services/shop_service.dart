import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/cart.dart';

/// Wishlist and cart calls (signed-in users only).
class ShopService {
  final _api = ApiClient.instance;

  Future<Set<int>> wishlistIds() async {
    final data = await _api.get(ApiConstants.wishlist);
    return {for (final id in data['ids'] as List) id as int};
  }

  Future<void> addToWishlist(int productId) => _api.post('${ApiConstants.wishlist}/$productId');

  Future<void> removeFromWishlist(int productId) => _api.delete('${ApiConstants.wishlist}/$productId');

  /// Number of items in the cart (sum of quantities).
  Future<int> cartCount() async => (await _api.get(ApiConstants.cart))['count'] as int;

  /// Adds to the cart and returns the whole updated cart (count and totals).
  Future<Cart> addToCart(int productId, {int quantity = 1}) async =>
      Cart.fromJson(await _api.post(ApiConstants.cart, data: {'product_id': productId, 'quantity': quantity}));
}
