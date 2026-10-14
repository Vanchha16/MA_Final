import 'catalog.dart';

class CartLine {
  final int id;
  final int quantity;
  final double subtotal;
  final Product product;

  const CartLine({required this.id, required this.quantity, required this.subtotal, required this.product});

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
        id: json['id'],
        quantity: json['quantity'],
        subtotal: (json['subtotal'] as num).toDouble(),
        product: Product.fromJson(json['product']),
      );

  /// The most of this item that can be in the cart (stock, max 20 - same rule as the API).
  int get maxQuantity => product.stock.clamp(0, 20);

  /// Sold out, or more in the cart than in stock: has to change before checkout.
  bool get needsAttention => product.soldOut || quantity > product.stock;
}

/// A promo code the server accepted for this cart.
class AppliedCoupon {
  final String code;
  final String description;
  final double discount;

  const AppliedCoupon({required this.code, required this.description, required this.discount});

  factory AppliedCoupon.fromJson(Map<String, dynamic> json) => AppliedCoupon(
        code: json['code'],
        description: json['description'],
        discount: (json['discount'] as num).toDouble(),
      );
}

/// GET /api/cart: lines and totals (delivery is free from [freeShippingMin]).
class Cart {
  final List<CartLine> lines;
  final int count;
  final double subtotal;
  final double discount;
  final double shippingFee;
  final double freeShippingMin;
  final double total;

  /// Sale prices plus the promo code.
  final double savings;
  final AppliedCoupon? coupon;

  /// Why a remembered promo code no longer applies (e.g. the cart got smaller).
  final String? couponError;

  const Cart({
    this.lines = const [],
    this.count = 0,
    this.subtotal = 0,
    this.discount = 0,
    this.shippingFee = 0,
    this.freeShippingMin = 50,
    this.total = 0,
    this.savings = 0,
    this.coupon,
    this.couponError,
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    double n(String key) => (json[key] as num? ?? 0).toDouble();
    return Cart(
      lines: [for (final l in json['items'] as List? ?? []) CartLine.fromJson(l)],
      count: json['count'] ?? 0,
      subtotal: n('subtotal'),
      discount: n('discount'),
      shippingFee: n('shipping_fee'),
      freeShippingMin: json['free_shipping_min'] == null ? 50 : n('free_shipping_min'),
      total: n('total'),
      savings: n('savings'),
      coupon: json['coupon'] == null ? null : AppliedCoupon.fromJson(json['coupon']),
      couponError: json['coupon_error'],
    );
  }

  bool get isEmpty => lines.isEmpty;

  /// How much more to spend for free delivery (0 when it is already free).
  double get toFreeShipping => shippingFee > 0 ? (freeShippingMin - subtotal).clamp(0, freeShippingMin) : 0;

  bool get canCheckout => lines.isNotEmpty && !lines.any((l) => l.needsAttention);
}
