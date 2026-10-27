import 'package:ecommerce_app/api/api_client.dart';
import 'package:ecommerce_app/models/cart.dart';
import 'package:ecommerce_app/models/catalog.dart';
import 'package:ecommerce_app/services/cart_service.dart';

import 'shop_fakes.dart';

/// In-memory cart with the same money rules as the API:
/// free delivery from $50 (else $2), WELCOME10 = 10% (max $20), ANIME5 = $5 from $30, OLDCODE expired.
class FakeCartService extends CartService {
  final List<(int id, Product product, int qty)> _lines = [];
  int _nextId = 1;
  bool fail = false;

  /// How many quantity changes reached the "server".
  int updates = 0;

  FakeCartService({Map<int, int> items = const {}}) {
    items.forEach((productId, qty) => _lines.add((_nextId++, demoProducts.firstWhere((p) => p.id == productId), qty)));
  }

  int get count => _lines.fold(0, (sum, l) => sum + l.$3);

  Cart _cart(String? coupon) {
    final subtotal = _lines.fold<double>(0, (s, l) => s + l.$2.finalPrice * l.$3);
    final sale = _lines.fold<double>(0, (s, l) => s + (l.$2.price - l.$2.finalPrice) * l.$3);
    final (c, err) = coupon == null ? (null, null) : _coupon(coupon, subtotal);
    final discount = c?.discount ?? 0;
    final shipping = subtotal == 0 || subtotal >= 50 ? 0.0 : 2.0;
    return Cart(
      lines: [for (final l in _lines) CartLine(id: l.$1, quantity: l.$3, subtotal: l.$2.finalPrice * l.$3, product: l.$2)],
      count: count,
      subtotal: subtotal,
      discount: discount,
      shippingFee: shipping,
      total: subtotal - discount + shipping,
      savings: sale + discount,
      coupon: c,
      couponError: err,
    );
  }

  (AppliedCoupon?, String?) _coupon(String code, double subtotal) {
    switch (code.toUpperCase()) {
      case 'WELCOME10':
        final off = (subtotal * 0.10).clamp(0, 20).toDouble();
        return (AppliedCoupon(code: 'WELCOME10', description: '10% off your order (up to \$20)', discount: off), null);
      case 'ANIME5':
        if (subtotal < 30) return (null, 'Spend \$30 or more to use ANIME5');
        return (const AppliedCoupon(code: 'ANIME5', description: '\$5 off orders from \$30', discount: 5), null);
      case 'OLDCODE':
        return (null, 'This promo code has expired');
      default:
        return (null, 'This promo code does not exist');
    }
  }

  void _check() {
    if (fail) throw ApiException('Cannot connect to server. Check your internet connection.');
  }

  @override
  Future<Cart> get({String? coupon}) async {
    _check();
    return _cart(coupon);
  }

  @override
  Future<Cart> add(int productId, {int quantity = 1, String? coupon}) async {
    _check();
    final i = _lines.indexWhere((l) => l.$2.id == productId);
    if (i >= 0) {
      _lines[i] = (_lines[i].$1, _lines[i].$2, _lines[i].$3 + quantity);
    } else {
      _lines.insert(0, (_nextId++, demoProducts.firstWhere((p) => p.id == productId), quantity));
    }
    return _cart(coupon);
  }

  @override
  Future<Cart> update(int lineId, int quantity, {String? coupon}) async {
    _check();
    updates++;
    final i = _lines.indexWhere((l) => l.$1 == lineId);
    if (quantity > _lines[i].$2.stock) throw ApiException('Only ${_lines[i].$2.stock} available for this item', statusCode: 409);
    _lines[i] = (_lines[i].$1, _lines[i].$2, quantity);
    return _cart(coupon);
  }

  @override
  Future<Cart> remove(int lineId, {String? coupon}) async {
    _check();
    _lines.removeWhere((l) => l.$1 == lineId);
    return _cart(coupon);
  }

  @override
  Future<Cart> clear() async {
    _check();
    _lines.clear();
    return _cart(null);
  }

  @override
  Future<Cart> applyCoupon(String code) async {
    _check();
    final subtotal = _lines.fold<double>(0, (s, l) => s + l.$2.finalPrice * l.$3);
    final (c, err) = _coupon(code, subtotal);
    if (c == null) throw ApiException(err!, statusCode: 422, errors: {'code': err});
    return _cart(c.code);
  }
}
