import 'cart.dart';
import 'catalog.dart';

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
  khqr('khqr', 'Bakong KHQR', 'KHQR'),
  aba('aba', 'ABA PayWay', 'ABA PayWay'),
  cod('cod', 'Cash on delivery', 'Cash');

  final String apiValue;
  final String label;

  /// For tight spots: "KHQR paid", "Paid by ABA PayWay".
  final String shortName;
  const PaymentMethod(this.apiValue, this.label, this.shortName);

  /// Paid in the app (a QR or ABA Mobile) before the shop packs it.
  bool get online => this != cod;

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

  /// Today's photo of the product (the name and price are what was paid).
  final String? imageUrl;
  final Category? category;

  /// Stars the customer gave this product (delivered orders only), or null.
  final int? myRating;

  const OrderLine({this.productId, required this.name, required this.unitPrice, required this.quantity, this.imageUrl, this.category, this.myRating});

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
        productId: json['product_id'],
        name: json['product_name'],
        unitPrice: (json['unit_price'] as num).toDouble(),
        quantity: json['quantity'],
        imageUrl: json['image_url'],
        category: json['category'] == null ? null : Category.fromJson(json['category']),
        myRating: json['my_rating'],
      );

  OrderLine withRating(int? rating) =>
      OrderLine(productId: productId, name: name, unitPrice: unitPrice, quantity: quantity, imageUrl: imageUrl, category: category, myRating: rating);

  /// For the photo placeholder when there is no photo.
  ProductKind get kind => category?.kind ?? ProductKind.figure;
}

/// Where an order is, as the customer sees it.
enum OrderStage {
  toPay,
  waitingConfirm,
  packing,
  onTheWay,
  delivered,
  cancelled;

  bool get active => this != delivered && this != cancelled;
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
  final String? shippingName, shippingAddress, note;
  final DateTime? createdAt;
  final List<OrderLine> lines;

  /// The customer can cancel until it ships.
  final bool canCancel;

  /// customer | shop | system (not paid in time).
  final String? cancelledBy, cancelReason;
  final DateTime? refundedAt;

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
    this.note,
    this.createdAt,
    this.lines = const [],
    this.canCancel = false,
    this.cancelledBy,
    this.cancelReason,
    this.refundedAt,
  });

  /// A paid online order was cancelled: the shop still has to send the money back.
  bool get refundPending => paymentStatus == 'refund_pending';
  bool get refunded => paymentStatus == 'refunded';

  OrderStage get stage => switch (status) {
        'cancelled' => OrderStage.cancelled,
        'delivered' => OrderStage.delivered,
        'shipped' => OrderStage.onTheWay,
        'confirmed' => OrderStage.packing,
        _ when paymentMethod.online && paymentStatus != 'paid' => OrderStage.toPay,
        _ when paymentMethod == PaymentMethod.cod => OrderStage.waitingConfirm,
        _ => OrderStage.packing, // pending but already paid
      };

  /// How many of Placed / Paid (or Confirmed) / Shipped / Delivered are done.
  int get stepsDone => switch (stage) {
        OrderStage.toPay || OrderStage.waitingConfirm => 1,
        OrderStage.packing => 2,
        OrderStage.onTheWay => 3,
        OrderStage.delivered => 4,
        OrderStage.cancelled => 1,
      };

  Order copyWith({String? status, String? paymentStatus, List<OrderLine>? lines}) => Order(
        id: id,
        number: number,
        status: status ?? this.status,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        deliveryMethod: deliveryMethod,
        subtotal: subtotal,
        discount: discount,
        shippingFee: shippingFee,
        total: total,
        couponCode: couponCode,
        itemCount: itemCount,
        shippingName: shippingName,
        shippingAddress: shippingAddress,
        note: note,
        createdAt: createdAt,
        lines: lines ?? this.lines,
        canCancel: canCancel,
        cancelledBy: cancelledBy,
        cancelReason: cancelReason,
        refundedAt: refundedAt,
      );

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
      note: json['note'],
      createdAt: json['created_at'] == null ? null : DateTime.tryParse(json['created_at']),
      lines: [for (final l in json['items'] as List? ?? []) OrderLine.fromJson(l)],
      canCancel: json['can_cancel'] ?? false,
      cancelledBy: json['cancelled_by'],
      cancelReason: json['cancel_reason'],
      refundedAt: json['refunded_at'] == null ? null : DateTime.tryParse(json['refunded_at']),
    );
  }
}

enum KhqrStatus { pending, paid, expired }

/// An online payment for an order: Bakong KHQR (POST /api/orders/{id}/khqr) or
/// ABA PayWay (POST /api/orders/{id}/payway), which also has a link that opens ABA Mobile.
class KhqrPayment {
  final String qr;
  final double amount;
  final String currency;
  final KhqrStatus status;
  final DateTime expiresAt;
  final DateTime? paidAt;

  /// ABA PayWay (else Bakong).
  final bool payway;

  /// ABA PayWay only: opens ABA Mobile with the payment filled in.
  final String? deeplink;

  const KhqrPayment({
    required this.qr,
    required this.amount,
    this.currency = 'USD',
    required this.status,
    required this.expiresAt,
    this.paidAt,
    this.payway = false,
    this.deeplink,
  });

  factory KhqrPayment.fromJson(Map<String, dynamic> json) => KhqrPayment(
        qr: json['qr'],
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] ?? 'USD',
        status: KhqrStatus.values.byName(json['status']),
        expiresAt: DateTime.parse(json['expires_at']),
        paidAt: json['paid_at'] == null ? null : DateTime.parse(json['paid_at']),
        payway: json['provider'] == 'payway',
        deeplink: json['deeplink'],
      );
}
