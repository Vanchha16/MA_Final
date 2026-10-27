import 'package:ecommerce_app/api/api_client.dart';
import 'package:ecommerce_app/models/shop_notification.dart';
import 'package:ecommerce_app/services/notification_service.dart';

ShopNotification note(int id, NotificationEvent event, {bool read = false, int? order, String? code, int minutesAgo = 10}) => ShopNotification(
      id: id,
      title: switch (event) {
        NotificationEvent.shipped => 'Your order is on the way',
        NotificationEvent.paid => 'Payment received',
        NotificationEvent.delivered => 'Delivered! Enjoy your order',
        NotificationEvent.cancelled => 'Order cancelled',
        NotificationEvent.promo => 'Weekend flash sale',
        NotificationEvent.welcome => 'Welcome to Anime World Shop',
        _ => 'New: pay with Bakong KHQR',
      },
      message: 'Message $id',
      event: event,
      isRead: read,
      orderId: order,
      orderNumber: order == null ? null : 'AWS-0000$order',
      promoCode: code,
      createdAt: DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo)),
    );

/// 1 shipped (order 3), 2 paid (order 2), 3 flash sale code, 4 news (read), 5 cancelled (order 5, read).
class FakeNotificationService extends NotificationService {
  final List<ShopNotification> items;
  bool fail = false;
  int readAllCalls = 0;
  final List<int> deleted = [];

  FakeNotificationService({List<ShopNotification>? items})
      : items = items ??
            [
              note(1, NotificationEvent.shipped, order: 3),
              note(2, NotificationEvent.paid, order: 2, minutesAgo: 60),
              note(3, NotificationEvent.promo, code: 'BIGSALE40', minutesAgo: 180),
              note(4, NotificationEvent.news, read: true, minutesAgo: 1500),
              note(5, NotificationEvent.cancelled, read: true, order: 5, minutesAgo: 3000),
            ];

  int get unread => items.where((n) => !n.isRead).length;

  @override
  Future<(List<ShopNotification>, int)> list() async {
    if (fail) throw ApiException('Cannot connect to server. Check your internet connection.');
    return ([...items], unread);
  }

  @override
  Future<int> readAll() async {
    readAllCalls++;
    for (var i = 0; i < items.length; i++) {
      items[i] = items[i].read();
    }
    return 0;
  }

  @override
  Future<int> read(int id) async {
    final i = items.indexWhere((n) => n.id == id);
    items[i] = items[i].read();
    return unread;
  }

  @override
  Future<int> delete(int id) async {
    deleted.add(id);
    items.removeWhere((n) => n.id == id);
    return unread;
  }
}
