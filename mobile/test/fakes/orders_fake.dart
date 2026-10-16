import 'package:ecommerce_app/core/network/api_client.dart';
import 'package:ecommerce_app/models/order.dart';
import 'package:ecommerce_app/services/order_service.dart';

import 'shop_fakes.dart';

Order _order(int id, String status, {PaymentMethod pay = PaymentMethod.khqr, String paid = 'paid', List<OrderLine>? lines, double total = 50}) => Order(
      id: id,
      number: 'AWS-2026101$id-000$id',
      status: status,
      paymentMethod: pay,
      paymentStatus: paid,
      subtotal: total,
      total: total,
      itemCount: (lines ?? const [OrderLine(productId: 3, name: 'One Piece Booster Pack #3', unitPrice: 5, quantity: 2)]).fold(0, (s, l) => s + l.quantity),
      shippingName: 'Demo Customer',
      shippingAddress: '#24 St. 271, Chamkar Mon, Phnom Penh',
      createdAt: DateTime.utc(2026, 10, 10 + id, 3),
      lines: lines ?? const [OrderLine(productId: 3, name: 'One Piece Booster Pack #3', unitPrice: 5, quantity: 2)],
    );

/// 1 waiting for KHQR, 2 being packed, 3 on the way (cash), 4 delivered, 5 cancelled.
class FakeOrderService extends OrderService {
  final List<Order> orders;
  bool fail = false;
  final List<int> received_ = [];

  FakeOrderService({List<Order>? orders})
      : orders = orders ??
            [
              _order(1, 'pending', paid: 'unpaid', total: 161.1, lines: [
                OrderLine(productId: 1, name: demoProducts[0].name, unitPrice: 169, quantity: 1),
              ]),
              _order(2, 'confirmed'),
              _order(3, 'shipped', pay: PaymentMethod.cod, paid: 'unpaid'),
              _order(4, 'delivered', lines: const [
                OrderLine(productId: 3, name: 'One Piece Booster Pack #3', unitPrice: 5, quantity: 1),
                OrderLine(name: 'A figure we no longer sell', unitPrice: 20, quantity: 1),
              ]),
              _order(5, 'cancelled', paid: 'unpaid'),
            ];

  @override
  Future<List<Order>> list() async {
    if (fail) throw ApiException('Cannot connect to server. Check your internet connection.');
    return [...orders];
  }

  @override
  Future<Order> get(int id) async => orders.firstWhere((o) => o.id == id);

  @override
  Future<Order> received(int id) async {
    received_.add(id);
    final i = orders.indexWhere((o) => o.id == id);
    final o = orders[i];
    orders[i] = o.copyWith(status: 'delivered', paymentStatus: 'paid');
    return orders[i];
  }
}
