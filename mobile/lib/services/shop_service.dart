import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/cart.dart';
import '../models/catalog.dart';

/// Wishlist and cart calls (signed-in users only).
class ShopService {
  final _api = ApiClient.instance;

  Future<Set<int>> wishlistIds() async {
    final data = await _api.get(ApiConstants.wishlist);
    return {for (final id in data['ids'] as List) id as int};
  }

  Future<void> addToWishlist(int productId) => _api.post('${ApiConstants.wishlist}/$productId');

  Future<void> removeFromWishlist(int productId) => _api.delete('${ApiConstants.wishlist}/$productId');

  /// The saved products, newest first.
  Future<List<Product>> wishlistItems() async {
    final data = await _api.get(ApiConstants.wishlist);
    return [for (final p in data['items'] as List) Product.fromJson(p)];
  }

  /// Returns the ids still in the wishlist.
  Future<Set<int>> removeManyFromWishlist(List<int> productIds) async =>
      _ids(await _api.post(ApiConstants.wishlistBatchRemove, data: {'product_ids': productIds}));

  /// Puts products back (Undo). Returns the ids now in the wishlist.
  Future<Set<int>> addManyToWishlist(List<int> productIds) async =>
      _ids(await _api.post(ApiConstants.wishlistBatchAdd, data: {'product_ids': productIds}));

  /// Adds one of each to the cart and takes them off the wishlist.
  Future<MoveToCartResult> moveToCart(List<int> productIds) async =>
      MoveToCartResult.fromJson(await _api.post(ApiConstants.wishlistMoveToCart, data: {'product_ids': productIds}));

  static Set<int> _ids(dynamic data) => {for (final id in data['ids'] as List) id as int};

  /// Unread messages, for the bell badge.
  Future<int> unreadNotifications() async => (await _api.get('${ApiConstants.notifications}/unread-count'))['unread'] as int;

  /// Number of items in the cart (sum of quantities).
  Future<int> cartCount() async => (await _api.get(ApiConstants.cart))['count'] as int;

  /// Adds to the cart and returns the whole updated cart (count and totals).
  Future<Cart> addToCart(int productId, {int quantity = 1}) async =>
      Cart.fromJson(await _api.post(ApiConstants.cart, data: {'product_id': productId, 'quantity': quantity}));
}

/// What "Move to cart" did: sold-out items (or full cart lines) are skipped and stay saved.
class MoveToCartResult {
  final List<int> moved, skipped;
  final Set<int> wishlistIds;
  final int cartCount;

  const MoveToCartResult({required this.moved, required this.skipped, required this.wishlistIds, required this.cartCount});

  factory MoveToCartResult.fromJson(Map<String, dynamic> json) => MoveToCartResult(
        moved: [for (final id in json['moved'] as List) id as int],
        skipped: [for (final id in json['skipped'] as List) id as int],
        wishlistIds: ShopService._ids(json),
        cartCount: json['cart_count'] as int,
      );
}
