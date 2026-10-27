import '../api/api_end_point.dart';
import '../api/api_client.dart';
import '../models/order.dart';

/// The customer's orders: the list (newest first, with items), one order, "Got it".
class OrderService {
  final _api = ApiClient.instance;

  Future<List<Order>> list() async => [for (final o in await _api.get(ApiEndPoint.orders) as List) Order.fromJson(o)];

  Future<Order> get(int id) async => Order.fromJson(await _api.get('${ApiEndPoint.orders}/$id'));

  /// Only for orders on the way; returns the delivered order.
  Future<Order> received(int id) async => Order.fromJson(await _api.post('${ApiEndPoint.orders}/$id/received'));

  /// Cancels an order that has not shipped. A paid online one becomes refund_pending.
  Future<Order> cancel(int id, {String? reason}) async =>
      Order.fromJson(await _api.post('${ApiEndPoint.orders}/$id/cancel', data: {'reason': ?reason}));
}
