import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/cart.dart';

/// The signed-in customer's cart. Every call returns the whole updated cart.
/// Pass [coupon] to keep a promo code applied while the cart changes.
class CartService {
  final _api = ApiClient.instance;

  Future<Cart> get({String? coupon}) async =>
      Cart.fromJson(await _api.get(ApiConstants.cart, query: {'coupon': ?coupon}));

  Future<Cart> add(int productId, {int quantity = 1, String? coupon}) async => Cart.fromJson(
      await _api.post(ApiConstants.cart, data: {'product_id': productId, 'quantity': quantity, 'coupon': ?coupon}));

  Future<Cart> update(int lineId, int quantity, {String? coupon}) async => Cart.fromJson(
      await _api.put('${ApiConstants.cart}/$lineId', data: {'quantity': quantity, 'coupon': ?coupon}));

  Future<Cart> remove(int lineId, {String? coupon}) async =>
      Cart.fromJson(await _api.delete('${ApiConstants.cart}/$lineId${coupon == null ? '' : '?coupon=$coupon'}'));

  Future<Cart> clear() async => Cart.fromJson(await _api.delete(ApiConstants.cart));

  /// Throws [ApiException] with the reason ("This promo code has expired") when it cannot be used.
  Future<Cart> applyCoupon(String code) async => Cart.fromJson(await _api.post('${ApiConstants.cart}/coupon', data: {'code': code}));
}
