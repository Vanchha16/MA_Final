import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/admin.dart';

/// The shop owner's calls (/api/admin). Every one needs an admin login.
class AdminService {
  final _api = ApiClient.instance;
  static const _base = ApiConstants.admin;

  Future<AdminStats> stats() async => AdminStats.fromJson(await _api.get('$_base/stats'));

  Future<List<ActivityEvent>> activity({int limit = 20}) async =>
      [for (final e in await _api.get('$_base/activity', query: {'limit': limit}) as List) ActivityEvent.fromJson(e)];

  /// confirmed, shipped, delivered or cancelled. The customer gets a notification.
  Future<void> setOrderStatus(int orderId, String status) => _api.put('$_base/orders/$orderId/status', data: {'status': status});

  Future<void> reply(int messageId, String text) => _api.post('$_base/contact-messages/$messageId/reply', data: {'reply': text});

  Future<void> setStock(int productId, int stock) => _api.put('$_base/products/$productId', data: {'stock': stock});
}
