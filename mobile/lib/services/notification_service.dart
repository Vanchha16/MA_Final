import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/shop_notification.dart';

/// The Notifications screen's calls. Each change returns the new unread count.
class NotificationService {
  final _api = ApiClient.instance;

  Future<(List<ShopNotification>, int)> list() async {
    final data = await _api.get(ApiConstants.notifications);
    return ([for (final n in data['items'] as List) ShopNotification.fromJson(n)], data['unread'] as int);
  }

  Future<int> readAll() async => (await _api.post('${ApiConstants.notifications}/read-all'))['unread'] as int;

  Future<int> read(int id) async => (await _api.post('${ApiConstants.notifications}/$id/read'))['unread'] as int;

  Future<int> delete(int id) async => (await _api.delete('${ApiConstants.notifications}/$id'))['unread'] as int;
}
