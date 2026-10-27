import '../api/api_end_point.dart';
import '../api/api_client.dart';
import '../models/shop_notification.dart';

/// The Notifications screen's calls. Each change returns the new unread count.
class NotificationService {
  final _api = ApiClient.instance;

  Future<(List<ShopNotification>, int)> list() async {
    final data = await _api.get(ApiEndPoint.notifications);
    return ([for (final n in data['items'] as List) ShopNotification.fromJson(n)], data['unread'] as int);
  }

  Future<int> readAll() async => (await _api.post('${ApiEndPoint.notifications}/read-all'))['unread'] as int;

  Future<int> read(int id) async => (await _api.post('${ApiEndPoint.notifications}/$id/read'))['unread'] as int;

  Future<int> delete(int id) async => (await _api.delete('${ApiEndPoint.notifications}/$id'))['unread'] as int;
}
