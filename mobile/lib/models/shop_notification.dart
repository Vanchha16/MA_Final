/// What a notification is about; picks its icon and button.
enum NotificationEvent { placed, paid, confirmed, shipped, delivered, cancelled, welcome, promo, news }

/// A message on the Notifications screen (GET /api/notifications).
class ShopNotification {
  final int id;
  final String title, message;
  final NotificationEvent event;
  final bool isRead;
  final int? orderId;
  final String? orderNumber, imageUrl, promoCode;
  final DateTime createdAt;

  const ShopNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.event,
    this.isRead = false,
    this.orderId,
    this.orderNumber,
    this.imageUrl,
    this.promoCode,
    required this.createdAt,
  });

  factory ShopNotification.fromJson(Map<String, dynamic> json) {
    final order = json['order'] as Map<String, dynamic>?;
    return ShopNotification(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      event: NotificationEvent.values.asNameMap()[json['event']] ?? NotificationEvent.news,
      isRead: json['is_read'] ?? false,
      orderId: order?['id'],
      orderNumber: order?['number'],
      imageUrl: json['image_url'],
      promoCode: json['promo_code'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  ShopNotification read() => ShopNotification(
        id: id,
        title: title,
        message: message,
        event: event,
        isRead: true,
        orderId: orderId,
        orderNumber: orderNumber,
        imageUrl: imageUrl,
        promoCode: promoCode,
        createdAt: createdAt,
      );

  /// Promo codes show as a coupon card.
  bool get isOffer => promoCode != null;
}
