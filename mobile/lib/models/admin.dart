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

enum ActivityKind { paid, order, message, soldOut }

/// What the shop can do about an event right now.
enum ActivityAction { confirm, ship, reply, restock }

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
        kind: switch (json['kind']) { 'paid' => ActivityKind.paid, 'message' => ActivityKind.message, 'sold_out' => ActivityKind.soldOut, _ => ActivityKind.order },
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
