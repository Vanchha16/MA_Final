import 'cart.dart';

/// A saved delivery address (/api/addresses).
class Address {
  final int? id;
  final String label;
  final String recipientName;
  final String phone;
  final String street;
  final String city;
  final String? province;
  final bool isDefault;

  const Address({
    this.id,
    this.label = 'Home',
    required this.recipientName,
    required this.phone,
    required this.street,
    required this.city,
    this.province,
    this.isDefault = false,
  });

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: json['id'],
        label: json['label'] ?? 'Home',
        recipientName: json['recipient_name'],
        phone: json['phone'],
        street: json['street'],
        city: json['city'],
        province: json['province'],
        isDefault: json['is_default'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'recipient_name': recipientName,
        'phone': phone,
        'street': street,
        'city': city,
        'province': province,
        'is_default': isDefault,
      };

  /// "#24 St. 271, Chamkar Mon, Phnom Penh"
  String get oneLine => [street, city, if (province != null && province!.isNotEmpty) province].join(', ');
}

enum DeliveryMethod {
  standard('standard'),
  pickup('pickup');

  final String apiValue;
  const DeliveryMethod(this.apiValue);
}

enum PaymentMethod {
  khqr('khqr', 'Bakong KHQR'),
  cod('cod', 'Cash on delivery');

  final String apiValue;
  final String label;
  const PaymentMethod(this.apiValue, this.label);

  static PaymentMethod fromApi(String? value) => values.firstWhere((m) => m.apiValue == value, orElse: () => cod);
}

class DeliveryOption {
  final DeliveryMethod method;
  final String label, detail;
  final double fee;

  const DeliveryOption({required this.method, required this.label, required this.detail, required this.fee});

  factory DeliveryOption.fromJson(Map<String, dynamic> json) => DeliveryOption(
        method: DeliveryMethod.values.firstWhere((m) => m.apiValue == json['id']),
        label: json['label'],
        detail: json['detail'],
        fee: (json['fee'] as num).toDouble(),
      );
}

/// GET /api/checkout: the cart with totals for the chosen delivery, the
/// delivery choices, saved addresses and the pickup store.
class CheckoutPreview {
  final Cart cart;
  final List<DeliveryOption> deliveryOptions;
  final List<Address> addresses;
  final String storeName, storeAddress;

  const CheckoutPreview({required this.cart, required this.deliveryOptions, required this.addresses, required this.storeName, required this.storeAddress});

  factory CheckoutPreview.fromJson(Map<String, dynamic> json) => CheckoutPreview(
        cart: Cart.fromJson(json),
        deliveryOptions: [for (final o in json['delivery_options'] as List) DeliveryOption.fromJson(o)],
        addresses: [for (final a in json['addresses'] as List) Address.fromJson(a)],
        storeName: json['store']['name'],
        storeAddress: json['store']['address'],
      );
}

class OrderLine {
  final int? productId;
  final String name;
  final double unitPrice;
  final int quantity;

  const OrderLine({this.productId, required this.name, required this.unitPrice, required this.quantity});

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
        productId: json['product_id'],
        name: json['product_name'],
        unitPrice: (json['unit_price'] as num).toDouble(),
        quantity: json['quantity'],
      );
}

/// An order as returned by POST /api/orders and GET /api/orders/{id}.
class Order {
  final int id;
  final String number;
  final String status;
  final PaymentMethod paymentMethod;
  final String paymentStatus;
  final DeliveryMethod deliveryMethod;
  final double subtotal, discount, shippingFee, total;
  final String? couponCode;
  final int itemCount;
  final String? shippingName, shippingAddress;
  final List<OrderLine> lines;

  const Order({
    required this.id,
    required this.number,
    this.status = 'pending',
    required this.paymentMethod,
    this.paymentStatus = 'unpaid',
    this.deliveryMethod = DeliveryMethod.standard,
    required this.subtotal,
    this.discount = 0,
    this.shippingFee = 0,
    required this.total,
    this.couponCode,
    required this.itemCount,
    this.shippingName,
    this.shippingAddress,
    this.lines = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    double n(String key) => (json[key] as num? ?? 0).toDouble();
    final shipping = json['shipping'] as Map<String, dynamic>?;
    return Order(
      id: json['id'],
      number: json['order_number'],
      status: json['status'],
      paymentMethod: PaymentMethod.fromApi(json['payment_method']),
      paymentStatus: json['payment_status'],
      deliveryMethod: json['delivery_method'] == 'pickup' ? DeliveryMethod.pickup : DeliveryMethod.standard,
      subtotal: n('subtotal'),
      discount: n('discount'),
      shippingFee: n('shipping_fee'),
      total: n('total'),
      couponCode: json['coupon_code'],
      itemCount: json['item_count'] ?? 0,
      shippingName: shipping?['name'],
      shippingAddress: shipping?['address'],
      lines: [for (final l in json['items'] as List? ?? []) OrderLine.fromJson(l)],
    );
  }
}

enum KhqrStatus { pending, paid, expired }

/// A KHQR payment for an order (POST /api/orders/{id}/khqr).
class KhqrPayment {
  final String qr;
  final double amount;
  final String currency;
  final KhqrStatus status;
  final DateTime expiresAt;
  final DateTime? paidAt;

  /// Demo mode: the app may simulate the payment.
  final bool demo;

  const KhqrPayment({
    required this.qr,
    required this.amount,
    this.currency = 'USD',
    required this.status,
    required this.expiresAt,
    this.paidAt,
    this.demo = false,
  });

  factory KhqrPayment.fromJson(Map<String, dynamic> json) => KhqrPayment(
        qr: json['qr'],
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] ?? 'USD',
        status: KhqrStatus.values.byName(json['status']),
        expiresAt: DateTime.parse(json['expires_at']),
        paidAt: json['paid_at'] == null ? null : DateTime.parse(json['paid_at']),
        demo: json['demo'] ?? false,
      );
}
