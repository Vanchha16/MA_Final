import 'package:ecommerce_app/core/network/api_client.dart';
import 'package:ecommerce_app/models/cart.dart';
import 'package:ecommerce_app/models/order.dart';
import 'package:ecommerce_app/services/checkout_service.dart';

import 'shop_fakes.dart';

/// In-memory checkout with the API's money rules: WELCOME10 = 10% (max $20),
/// delivery free from $50 (else $2), store pickup always free.
class FakeCheckoutService extends CheckoutService {
  final List<Address> saved;
  final List<CartLine> lines;
  final List<Map<String, Object?>> placed = [];

  /// Thrown by the next placeOrder, if set.
  ApiException? placeError;
  int _nextId = 100;

  FakeCheckoutService({List<Address>? addresses, Map<int, int> cart = const {1: 1, 3: 2}})
      : saved = addresses ?? [],
        lines = [
          for (final MapEntry(key: id, value: qty) in cart.entries)
            CartLine(id: id, quantity: qty, subtotal: demoProducts.firstWhere((p) => p.id == id).finalPrice * qty, product: demoProducts.firstWhere((p) => p.id == id)),
        ];

  static const home = Address(id: 1, label: 'Home', recipientName: 'Demo Customer', phone: '012345678', street: '#24 St. 271', city: 'Chamkar Mon', province: 'Phnom Penh', isDefault: true);
  static const work = Address(id: 2, label: 'Work', recipientName: 'Demo Customer', phone: '098765432', street: '#5 Norodom Blvd', city: 'Daun Penh', province: 'Phnom Penh');

  Cart _cart(String? coupon, DeliveryMethod delivery) {
    final subtotal = lines.fold<double>(0, (s, l) => s + l.subtotal);
    final valid = coupon?.toUpperCase() == 'WELCOME10';
    final discount = valid ? (subtotal * 0.1).clamp(0, 20).toDouble() : 0.0;
    final shipping = delivery == DeliveryMethod.pickup || subtotal >= 50 ? 0.0 : 2.0;
    return Cart(
      lines: lines,
      count: lines.fold(0, (s, l) => s + l.quantity),
      subtotal: subtotal,
      discount: discount,
      shippingFee: shipping,
      total: subtotal - discount + shipping,
      coupon: valid ? AppliedCoupon(code: 'WELCOME10', description: '10% off', discount: discount) : null,
      couponError: coupon != null && !valid ? 'This promo code does not exist' : null,
    );
  }

  @override
  Future<CheckoutPreview> preview({String? coupon, DeliveryMethod delivery = DeliveryMethod.standard}) async {
    final subtotal = lines.fold<double>(0, (s, l) => s + l.subtotal);
    return CheckoutPreview(
      cart: _cart(coupon, delivery),
      deliveryOptions: [
        DeliveryOption(method: DeliveryMethod.standard, label: 'Standard', detail: 'Tomorrow, 9:00 - 18:00', fee: subtotal >= 50 ? 0 : 2),
        const DeliveryOption(method: DeliveryMethod.pickup, label: 'Store pickup', detail: 'Today at Toul Kork', fee: 0),
      ],
      addresses: [...saved.where((a) => a.isDefault), ...saved.where((a) => !a.isDefault)],
      storeName: 'Anime World Shop',
      storeAddress: '#88 St. 315, Toul Kork, Phnom Penh',
    );
  }

  @override
  Future<Order> placeOrder({int? addressId, required DeliveryMethod delivery, required PaymentMethod payment, String? coupon, String? note}) async {
    if (placeError != null) {
      final e = placeError!;
      placeError = null;
      throw e;
    }
    placed.add({'address': addressId, 'delivery': delivery, 'payment': payment, 'coupon': coupon, 'note': note});
    final cart = _cart(coupon, delivery);
    lines.clear();
    return Order(
      id: 7,
      number: 'AWS-20261016-0007',
      paymentMethod: payment,
      deliveryMethod: delivery,
      subtotal: cart.subtotal,
      discount: cart.discount,
      shippingFee: cart.shippingFee,
      total: cart.total,
      itemCount: cart.count,
      shippingAddress: saved.where((a) => a.id == addressId).firstOrNull?.oneLine,
    );
  }

  @override
  Future<List<Address>> addresses() async => [...saved];

  @override
  Future<Address> saveAddress(Address address) async {
    final id = address.id ?? _nextId++;
    final isDefault = address.isDefault || saved.isEmpty;
    final stored = Address(
      id: id,
      label: address.label,
      recipientName: address.recipientName,
      phone: address.phone,
      street: address.street,
      city: address.city,
      province: address.province,
      isDefault: isDefault,
    );
    if (isDefault) {
      for (var i = 0; i < saved.length; i++) {
        final a = saved[i];
        saved[i] = Address(id: a.id, label: a.label, recipientName: a.recipientName, phone: a.phone, street: a.street, city: a.city, province: a.province);
      }
    }
    final at = saved.indexWhere((a) => a.id == id);
    at >= 0 ? saved[at] = stored : saved.add(stored);
    return stored;
  }

  @override
  Future<List<Address>> deleteAddress(int id) async => [...saved..removeWhere((a) => a.id == id)];
}
