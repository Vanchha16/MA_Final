import 'package:ecommerce_app/models/order.dart';
import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/screens/orders/orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes/checkout_fake.dart';
import 'fakes/orders_fake.dart';
import 'fakes/shop_fakes.dart';

/// The current tracker step pulses forever, so these tests pump fixed times instead of settling.
Future<(FakeOrderService, FakeShopService)> _pump(WidgetTester tester, {FakeOrderService? service}) async {
  tester.view.physicalSize = const Size(412, 1600) * 2; // tall, so every card is built
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final orders = service ?? FakeOrderService();
  final shop = FakeShopService();
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => ShopProvider(service: shop)..setSignedIn(true),
    child: MaterialApp(theme: AppTheme.light, home: OrdersScreen(service: orders, paymentService: FakePaymentService())),
  ));
  // Cards come in and the trackers fill (step by step, so the animations run)
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  return (orders, shop);
}

Finder _inOrder(int id, Finder f) => find.descendant(of: find.byKey(Key('order_$id')), matching: f);

Future<void> _end(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5)); // let snack bars go
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 50)); // zero-length animation timers
}

void main() {
  testWidgets('in progress first with trackers, then past orders', (tester) async {
    await _pump(tester);
    expect(find.text('In progress · 3'), findsOneWidget);
    expect(find.text('Past orders'), findsOneWidget);

    expect(_inOrder(1, find.text('Waiting for your KHQR payment')), findsOneWidget);
    expect(find.byKey(const Key('order_pay_1')), findsOneWidget);
    expect(_inOrder(2, find.textContaining('Packing your order')), findsOneWidget);
    expect(_inOrder(3, find.textContaining('On the way')), findsOneWidget);
    expect(_inOrder(3, find.text('Paid')), findsOneWidget);

    // Filled up to where each order is
    expect(_inOrder(1, find.byKey(const Key('step_done_0'))), findsOneWidget);
    expect(_inOrder(1, find.byKey(const Key('step_done_1'))), findsNothing);
    expect(_inOrder(3, find.byKey(const Key('step_done_2'))), findsOneWidget);
    expect(_inOrder(3, find.byKey(const Key('step_done_3'))), findsNothing);

    expect(_inOrder(4, find.text('Delivered')), findsOneWidget);
    expect(_inOrder(5, find.text('Cancelled')), findsOneWidget);
    await _end(tester);
  });

  testWidgets('Got it finishes the tracker, then the order moves to Past orders', (tester) async {
    final (service, _) = await _pump(tester);
    await tester.tap(find.byKey(const Key('order_received_3')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(service.received_, [3]);
    expect(_inOrder(3, find.byKey(const Key('step_done_3'))), findsOneWidget);
    expect(_inOrder(3, find.text('Delivered · enjoy your order!')), findsOneWidget);
    expect(find.text('In progress · 3'), findsOneWidget); // still here for a moment

    await tester.pump(OrdersScreen.moveAfter);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('In progress · 2'), findsOneWidget);
    expect(find.byKey(const Key('order_pill_3')), findsOneWidget);
    expect(find.byKey(const Key('order_received_3')), findsNothing);
    await _end(tester);
  });

  testWidgets('Buy again puts what is still sold back in the cart', (tester) async {
    final (_, shop) = await _pump(tester);
    await tester.tap(find.byKey(const Key('order_again_4')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(shop.cart, 1);
    expect(find.text('Added 1 item to your cart. 1 no longer available.'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('cash and pickup orders have no Got it: the shop finishes them', (tester) async {
    await _pump(tester, service: FakeOrderService(orders: [
      fakeOrder(6, 'shipped', pay: PaymentMethod.cod, paid: 'unpaid'),
      fakeOrder(7, 'shipped', delivery: DeliveryMethod.pickup),
    ]));
    expect(_inOrder(6, find.text('Confirmed')), findsOneWidget);
    expect(find.byKey(const Key('order_received_6')), findsNothing);
    expect(find.byKey(const Key('order_received_7')), findsNothing);
    expect(_inOrder(7, find.text('Ready to pick up at our Toul Kork shop')), findsOneWidget);
    await _end(tester);
  });

  testWidgets('a finished pickup order says Picked up', (tester) async {
    await _pump(tester, service: FakeOrderService(orders: [fakeOrder(8, 'delivered', delivery: DeliveryMethod.pickup)]));
    expect(_inOrder(8, find.text('Picked up')), findsOneWidget);
    expect(_inOrder(8, find.text('Delivered')), findsNothing);
    await _end(tester);
  });

  testWidgets('an unpaid ABA order talks about ABA PayWay, not KHQR', (tester) async {
    await _pump(tester, service: FakeOrderService(orders: [fakeOrder(9, 'pending', pay: PaymentMethod.aba, paid: 'unpaid')]));
    expect(_inOrder(9, find.text('Waiting for your ABA PayWay payment')), findsOneWidget);
    await tester.tap(find.byKey(const Key('order_9')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('with ABA PayWay'), findsOneWidget);
    expect(find.textContaining('KHQR'), findsNothing);
    await _end(tester);
  });

  testWidgets('order details: tracker, items, totals, and Got it', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('order_3')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Order details'), findsOneWidget);
    expect(find.byKey(const Key('details_number')), findsOneWidget);

    await tester.tap(find.byKey(const Key('details_received')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Delivered · enjoy your order!'), findsOneWidget);
    expect(find.byKey(const Key('details_again')), findsOneWidget);
    expect(find.text('Paid'), findsNWidgets(2)); // the tracker and the payment card
    await _end(tester);
  });

  testWidgets('Pay now opens the KHQR screen', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('order_pay_1')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('khqr_card')), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // stop the payment timers
  });

  testWidgets('empty, and an error with Try again', (tester) async {
    await _pump(tester, service: FakeOrderService(orders: []));
    expect(find.byKey(const Key('orders_empty')), findsOneWidget);

    final failing = FakeOrderService()..fail = true;
    await tester.pumpWidget(const SizedBox()); // a fresh screen
    await _pump(tester, service: failing);
    expect(find.byKey(const Key('orders_retry')), findsOneWidget);
    failing.fail = false;
    await tester.tap(find.byKey(const Key('orders_retry')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('In progress · 3'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('cancel a paid order: pick a reason, then the refund shows as pending', (tester) async {
    final (service, _) = await _pump(tester);
    await tester.tap(find.byKey(const Key('order_2')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.ensureVisible(find.byKey(const Key('details_cancel')));
    await tester.tap(find.byKey(const Key('details_cancel')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Cancel this order?'), findsOneWidget);
    expect(find.textContaining(r'send $50 back to you within 3 working days'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancel_reason_0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cancel_order_primary')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(service.cancelled, [(2, 'Changed my mind')]);
    expect(find.byKey(const Key('details_refund')), findsOneWidget);
    expect(find.text('Refund pending'), findsOneWidget);
    expect(find.text('You cancelled this order · Changed my mind'), findsOneWidget);
    expect(find.text('Paid · refund on its way'), findsOneWidget);
    expect(find.byKey(const Key('details_cancel')), findsNothing);
    await _end(tester);
  });

  testWidgets('Keep my order closes the pop-up; shipped orders have no Cancel', (tester) async {
    final (service, _) = await _pump(tester);
    await tester.tap(find.byKey(const Key('order_1')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.ensureVisible(find.byKey(const Key('details_cancel')));
    await tester.tap(find.byKey(const Key('details_cancel')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining("This can't be undone"), findsOneWidget); // not paid yet: no refund
    await tester.tap(find.byKey(const Key('cancel_order_later')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Cancel this order?'), findsNothing);
    expect(service.cancelled, isEmpty);

    Navigator.of(tester.element(find.text('Order details'))).pop();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('order_3'))); // on the way
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('details_cancel')), findsNothing);
    await _end(tester);
  });

  testWidgets('past orders show Refund pending and Refunded', (tester) async {
    await _pump(tester, service: FakeOrderService(orders: [
      fakeOrder(6, 'cancelled', paid: 'refund_pending', cancelledBy: 'customer'),
      fakeOrder(7, 'cancelled', paid: 'refunded', cancelledBy: 'shop'),
    ]));
    expect(_inOrder(6, find.text('Refund pending')), findsOneWidget);
    expect(_inOrder(7, find.text('Refunded')), findsOneWidget);
    await _end(tester);
  });
}
