import 'catalog.dart';
import 'order.dart';

/// Dashboard numbers (GET /api/admin/stats).
class AdminStats {
  final double revenue, weekRevenue;
  final List<double> week; // paid revenue for the last 7 days, oldest first
  final int ordersToHandle, lowStock, openMessages, products, customers, orders;

  const AdminStats({
    this.revenue = 0,
    this.weekRevenue = 0,
    this.week = const [0, 0, 0, 0, 0, 0, 0],
    this.ordersToHandle = 0,
    this.lowStock = 0,
    this.openMessages = 0,
    this.products = 0,
    this.customers = 0,
    this.orders = 0,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) => AdminStats(
        revenue: (json['revenue'] as num).toDouble(),
        weekRevenue: (json['week_revenue'] as num? ?? 0).toDouble(),
        week: [for (final d in json['week'] as List? ?? []) (d['revenue'] as num).toDouble()],
        ordersToHandle: json['orders_to_handle'] ?? 0,
        lowStock: json['low_stock'] ?? 0,
        openMessages: json['open_messages'] ?? 0,
        products: json['products'] ?? 0,
        customers: json['customers'] ?? 0,
        orders: json['orders'] ?? 0,
      );
}

enum ActivityKind { paid, order, cancelled, message, soldOut }

/// What the shop can do about an event right now.
enum ActivityAction { confirm, ship, reply, restock, refund }

/// One line of the dashboard's Live activity (GET /api/admin/activity).
class ActivityEvent {
  final String id, title, message;
  final ActivityKind kind;
  final DateTime at;
  final String? imageUrl, status, orderNumber;
  final ActivityAction? action;
  final int? orderId, messageId, productId;

  const ActivityEvent({
    required this.id,
    required this.kind,
    required this.at,
    required this.title,
    required this.message,
    this.imageUrl,
    this.status,
    this.orderNumber,
    this.action,
    this.orderId,
    this.messageId,
    this.productId,
  });

  factory ActivityEvent.fromJson(Map<String, dynamic> json) => ActivityEvent(
        id: json['id'],
        kind: switch (json['kind']) { 'paid' => ActivityKind.paid, 'message' => ActivityKind.message, 'sold_out' => ActivityKind.soldOut, 'cancelled' => ActivityKind.cancelled, _ => ActivityKind.order },
        at: DateTime.parse(json['at']),
        title: json['title'],
        message: json['message'],
        imageUrl: json['image_url'],
        status: json['status'],
        orderNumber: json['order_number'],
        action: ActivityAction.values.asNameMap()[json['action']],
        orderId: json['order_id'],
        messageId: json['message_id'],
        productId: json['product_id'],
      );
}

/// An order as the shop sees it (GET /api/admin/orders): with the customer
/// and the statuses it can move to next.
class AdminOrder {
  final Order order;
  final int customerId;
  final String customerName, customerEmail;
  final String? phone, imageUrl;
  final List<String> nextStatuses;

  const AdminOrder({required this.order, this.customerId = 0, this.customerName = '', this.customerEmail = '', this.phone, this.imageUrl, this.nextStatuses = const []});

  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    final c = json['customer'] as Map<String, dynamic>? ?? const {};
    return AdminOrder(
      order: Order.fromJson(json),
      customerId: c['id'] ?? 0,
      customerName: c['full_name'] ?? '',
      customerEmail: c['email'] ?? '',
      phone: (json['shipping'] as Map<String, dynamic>?)?['phone'] ?? c['phone'],
      imageUrl: json['image_url'],
      nextStatuses: [for (final s in json['next_statuses'] as List? ?? []) s as String],
    );
  }
}

class ProductPhoto {
  final int id;
  final String url;
  final bool isPrimary;

  const ProductPhoto({required this.id, required this.url, this.isPrimary = false});

  factory ProductPhoto.fromJson(Map<String, dynamic> json) => ProductPhoto(id: json['id'], url: json['url'], isPrimary: json['is_primary'] ?? false);
}

/// A product as the shop sees it: hidden ones too, with photo ids.
class AdminProduct {
  final Product product;
  final bool isActive;
  final List<ProductPhoto> photos;

  const AdminProduct({required this.product, this.isActive = true, this.photos = const []});

  factory AdminProduct.fromJson(Map<String, dynamic> json) => AdminProduct(
        product: Product.fromJson(json),
        isActive: json['is_active'] ?? true,
        photos: [for (final p in json['photos'] as List? ?? []) ProductPhoto.fromJson(p)],
      );
}

class AdminCategory {
  final int id;
  final String name, slug;
  final String? description;
  final int productCount;

  const AdminCategory({required this.id, required this.name, this.slug = '', this.description, this.productCount = 0});

  factory AdminCategory.fromJson(Map<String, dynamic> json) =>
      AdminCategory(id: json['id'], name: json['name'], slug: json['slug'] ?? '', description: json['description'], productCount: json['product_count'] ?? 0);
}

class Customer {
  final int id;
  final String fullName, email;
  final String? phone;
  final bool isActive;
  final int orderCount;
  final double totalSpent;
  final DateTime? createdAt;
  final List<Address> addresses;
  final List<Order> orders;

  const Customer({required this.id, required this.fullName, required this.email, this.phone, this.isActive = true, this.orderCount = 0, this.totalSpent = 0, this.createdAt, this.addresses = const [], this.orders = const []});

  String get initials => fullName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'],
        fullName: json['full_name'],
        email: json['email'],
        phone: json['phone'],
        isActive: json['is_active'] ?? true,
        orderCount: json['order_count'] ?? 0,
        totalSpent: (json['total_spent'] as num? ?? 0).toDouble(),
        createdAt: json['created_at'] == null ? null : DateTime.tryParse(json['created_at']),
        addresses: [for (final a in json['addresses'] as List? ?? []) Address.fromJson(a)],
        orders: [for (final o in json['orders'] as List? ?? []) Order.fromJson(o)],
      );
}

/// A staff or admin account (GET /api/admin/staff, owner only).
class StaffMember {
  final int id;
  final String fullName, email, role;
  final String? phone;
  final bool isActive;
  final DateTime? lastLoginAt;

  const StaffMember({required this.id, required this.fullName, required this.email, this.role = 'staff', this.phone, this.isActive = true, this.lastLoginAt});

  bool get isAdmin => role == 'admin';
  String get initials => fullName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        id: json['id'],
        fullName: json['full_name'],
        email: json['email'],
        role: json['role'] ?? 'staff',
        phone: json['phone'],
        isActive: json['is_active'] ?? true,
        lastLoginAt: json['last_login_at'] == null ? null : DateTime.tryParse(json['last_login_at']),
      );
}

/// A way to pay and whether customers see it at checkout (GET /api/admin/payment-methods, owner only).
class PaymentMethodSetting {
  final PaymentMethod method;
  final bool enabled;

  /// The server has this bank's keys (always true for cash).
  final bool setUp;

  const PaymentMethodSetting({required this.method, this.enabled = true, this.setUp = true});

  PaymentMethodSetting copyWith({bool? enabled}) => PaymentMethodSetting(method: method, enabled: enabled ?? this.enabled, setUp: setUp);

  factory PaymentMethodSetting.fromJson(Map<String, dynamic> json) =>
      PaymentMethodSetting(method: PaymentMethod.fromApi(json['id']), enabled: json['enabled'] ?? true, setUp: json['set_up'] ?? true);
}

/// A Contact message (GET /api/admin/contact-messages).
class AdminMessage {
  final int id;
  final String topic, message, status, customerName;
  final String? reply, orderNumber;
  final DateTime createdAt;

  const AdminMessage({required this.id, required this.topic, required this.message, required this.status, required this.customerName, required this.createdAt, this.reply, this.orderNumber});

  bool get open => status == 'open';

  factory AdminMessage.fromJson(Map<String, dynamic> json) => AdminMessage(
        id: json['id'],
        topic: json['topic'] ?? 'other',
        message: json['message'],
        status: json['status'],
        reply: json['reply'],
        orderNumber: (json['order'] as Map<String, dynamic>?)?['number'],
        customerName: (json['customer'] as Map<String, dynamic>?)?['full_name'] ?? '',
        createdAt: DateTime.parse(json['created_at']),
      );
}
