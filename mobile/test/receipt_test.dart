import 'dart:typed_data';

import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/models/order.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/screens/checkout/khqr_payment_screen.dart';
import 'package:ecommerce_app/screens/orders/order_details_screen.dart';
import 'package:ecommerce_app/screens/orders/receipt_screen.dart';
import 'package:ecommerce_app/services/receipt_export.dart';
import 'package:ecommerce_app/widgets/order_receipt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes/checkout_fake.dart';
import 'fakes/orders_fake.dart';
import 'fakes/shop_fakes.dart';

class FakeExport extends ReceiptExport {
  final saved = <String>[];
  final shared = <String>[];
  bool fail = false;

  @override
  Future<Uint8List> image(BuildContext context, Order order, {DateTime? paidAt}) async {
    if (fail) throw Exception('no canvas');
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<void> save(Uint8List png, Order order) async => saved.add(order.number);

  @override
  Future<void> share(Uint8List png, Order order) async => shared.add(order.number);
}

const cashOrder = Order(
  id: 9,
  number: 'AWS-20261010-0009',
  status: 'delivered',
  paymentMethod: PaymentMethod.cod,
  paymentStatus: 'paid',
  subtotal: 40,
  shippingFee: 2,
  total: 42,
  itemCount: 2,
  lines: [OrderLine(productId: 3, name: 'One Piece Booster Pack #3', unitPrice: 20, quantity: 2)],
);

Future<void> _pump(WidgetTester tester, Widget home, {bool settle = true}) async {
  tester.view.physicalSize = const Size(412, 1500) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => ShopProvider(service: FakeShopService())..setSignedIn(true),
    child: MaterialApp(theme: AppTheme.light, home: home),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('the receipt lists the order and says how it was paid', (tester) async {
    await _pump(tester, const Scaffold(body: Center(child: OrderReceipt(order: FakePaymentService.order))));
    expect(find.text('ANIME WORLD SHOP'), findsOneWidget);
    expect(find.textContaining('Monkey D. Luffy'), findsOneWidget);
    expect(find.text('Promo WELCOME10'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('khqr_receipt_total'))).data, r'$161.10');
    expect(find.text('Paid by KHQR'), findsOneWidget);
    expect(find.byKey(const Key('khqr_paid_stamp')), findsOneWidget);

    await _pump(tester, const Scaffold(body: Center(child: OrderReceipt(order: cashOrder))));
    expect(find.text('Paid in cash on delivery'), findsOneWidget);
    expect(find.text(r'$2'), findsOneWidget); // delivery
  });

  testWidgets('the Receipt page saves and shares the image', (tester) async {
    final export = FakeExport();
    await _pump(tester, ReceiptScreen(order: cashOrder, export: export));
    await tester.tap(find.byKey(const Key('receipt_save')));
    await tester.pump();
    expect(export.saved, ['AWS-20261010-0009']);
    expect(find.text('Receipt saved as receipt-AWS-20261010-0009.png'), findsOneWidget);
    await tester.tap(find.byKey(const Key('receipt_share')));
    await tester.pump();
    expect(export.shared, ['AWS-20261010-0009']);

    export.fail = true;
    await tester.tap(find.byKey(const Key('receipt_save')));
    await tester.pump();
    expect(find.text('Could not save the receipt. Please try again.'), findsOneWidget);
  });

  testWidgets('Order details offers View receipt only for paid orders', (tester) async {
    final orders = FakeOrderService();
    final unpaid = orders.orders.firstWhere((o) => o.paymentStatus != 'paid' && o.status != 'cancelled');
    await _pump(tester, OrderDetailsScreen(order: unpaid, service: orders, paymentService: FakePaymentService()));
    expect(find.byKey(const Key('details_view_receipt')), findsNothing);
    await _end(tester);

    await _pump(tester, OrderDetailsScreen(order: cashOrder, service: orders, paymentService: FakePaymentService()));
    await tester.tap(find.byKey(const Key('details_view_receipt')));
    await tester.pumpAndSettle();
    expect(find.byType(ReceiptScreen), findsOneWidget);
    expect(find.text('Paid in cash on delivery'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('after paying, the actions sit under the receipt: Save receipt and View order work', (tester) async {
    final export = FakeExport();
    final payments = FakePaymentService();
    await _pump(tester, KhqrPaymentScreen(order: FakePaymentService.order, service: payments, export: export), settle: false);
    payments.state = KhqrStatus.paid;
    await tester.pump(KhqrPaymentScreen.pollEvery); // the automatic check finds it
    await tester.pump(KhqrPaymentScreen.printDuration);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining("I've paid"), findsNothing); // no button pinned to the bottom
    final receiptBottom = tester.getBottomLeft(find.byType(OrderReceipt)).dy;
    expect(tester.getTopLeft(find.byKey(const Key('khqr_confirmed'))).dy, greaterThan(receiptBottom));

    await tester.tap(find.byKey(const Key('khqr_save_receipt')));
    await tester.pump();
    expect(export.saved, ['AWS-20261016-0007']);

    await tester.tap(find.byKey(const Key('khqr_view_order')));
    await tester.pump(const Duration(milliseconds: 500)); // the tracker keeps pulsing, so no settle
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(OrderDetailsScreen), findsOneWidget);
    await _end(tester);
  });
}
