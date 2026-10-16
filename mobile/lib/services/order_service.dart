import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/order.dart';

/// The customer's orders: the list (newest first, with items), one order, "Got it".
class OrderService {
  final _api = ApiClient.instance;

  Future<List<Order>> list() async => [for (final o in await _api.get(ApiConstants.orders) as List) Order.fromJson(o)];

  Future<Order> get(int id) async => Order.fromJson(await _api.get('${ApiConstants.orders}/$id'));

  /// Only for orders on the way; returns the delivered order.
  Future<Order> received(int id) async => Order.fromJson(await _api.post('${ApiConstants.orders}/$id/received'));
}
