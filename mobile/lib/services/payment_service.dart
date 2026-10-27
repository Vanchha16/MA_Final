import '../api/api_end_point.dart';
import '../api/api_client.dart';
import '../models/order.dart';

/// Online payment for an order (Bakong KHQR or ABA PayWay): make it once, then check it.
class PaymentService {
  final _api = ApiClient.instance;

  static (KhqrPayment, Order) _read(dynamic data) => (KhqrPayment.fromJson(data['payment']), Order.fromJson(data['order']));

  /// Returns the same code every time for the same order.
  Future<(KhqrPayment, Order)> start(Order order) async =>
      _read(await _api.post('${ApiEndPoint.orders}/${order.id}/${order.paymentMethod == PaymentMethod.aba ? 'payway' : 'khqr'}'));

  /// pending, paid or expired (an expired order is cancelled).
  Future<(KhqrPayment, Order)> status(int orderId) async => _read(await _api.get('${ApiEndPoint.orders}/$orderId/payment'));
}
