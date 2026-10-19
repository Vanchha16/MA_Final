import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/order.dart';

/// KHQR payment for an order: make the code once, then check it.
class PaymentService {
  final _api = ApiClient.instance;

  static (KhqrPayment, Order) _read(dynamic data) => (KhqrPayment.fromJson(data['payment']), Order.fromJson(data['order']));

  /// Returns the same code every time for the same order.
  Future<(KhqrPayment, Order)> start(int orderId) async => _read(await _api.post('${ApiConstants.orders}/$orderId/khqr'));

  /// pending, paid or expired (an expired order is cancelled).
  Future<(KhqrPayment, Order)> status(int orderId) async => _read(await _api.get('${ApiConstants.orders}/$orderId/payment'));
}
