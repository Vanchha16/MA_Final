import 'package:ecommerce_app/core/network/api_client.dart';
import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/models/order.dart';
import 'package:ecommerce_app/models/user.dart';
import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/screens/checkout/checkout_screen.dart';
import 'package:ecommerce_app/screens/checkout/khqr_payment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes/checkout_fake.dart';
import 'fakes/shop_fakes.dart';

/// Cart: 1 Luffy figure ($169) + 2 packs ($5) = $179, so delivery is free.
/// A host page pushes the checkout and keeps what it pops with.
Future<(ShopProvider, List<Object?>)> _pump(WidgetTester tester, FakeCheckoutService service, {String? coupon, FakePaymentService? payments}) async {
  tester.view.physicalSize = const Size(412, 1500) * 2; // tall, so the whole page is built
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final shop = ShopProvider(service: FakeShopService(cart: 3))..setSignedIn(true);
  final results = <Object?>[];
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: shop),
      ChangeNotifierProvider(create: (_) => AuthProvider()..updateUser(User(id: 2, fullName: 'Demo Customer', email: 'demo@shop.com', phone: '012345678'))),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () async => results.add(await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckoutScreen(coupon: coupon, service: service, paymentService: payments ?? FakePaymentService())))),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return (shop, results);
}

/// The KHQR screen keeps a spinner and a timer running, so pump a fixed time instead of settling.
Future<void> _place(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('checkout_place')));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('places a KHQR order to the default address with the cart promo code, then pays', (tester) async {
    final service = FakeCheckoutService(addresses: [FakeCheckoutService.work, FakeCheckoutService.home]);
    final payments = FakePaymentService();
    final (shop, results) = await _pump(tester, service, coupon: 'WELCOME10', payments: payments);

    expect(find.text('Home · Demo Customer'), findsOneWidget); // the default comes first
    expect(find.text(r'-$17.90'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('checkout_total'))).data, r'$161.10');

    await _place(tester);
    expect(service.placed.single, {'address': 1, 'delivery': DeliveryMethod.standard, 'payment': PaymentMethod.khqr, 'coupon': 'WELCOME10', 'note': ''});
    expect(shop.cartCount, 0);

    // Straight to the KHQR screen
    expect(find.byKey(const Key('khqr_card')), findsOneWidget);
    expect(find.byKey(const Key('khqr_qr')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('khqr_amount'))).data, r'$161.10');
    expect(find.textContaining('Expires in 1'), findsOneWidget);

    await tester.pump(KhqrPaymentScreen.pollEvery);
    expect(payments.checks, 1); // checks by itself

    payments.state = KhqrStatus.paid; // paid in the bank app: the next check sees it
    await tester.pump(KhqrPaymentScreen.pollEvery);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('khqr_card')), findsOneWidget); // squashing into the printer
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('khqr_card')), findsNothing);
    expect(find.text('Your receipt'), findsOneWidget);
    expect(find.byKey(const Key('khqr_paid_stamp')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('khqr_receipt_total'))).data, r'$161.10');
    expect(find.textContaining('Promo WELCOME10'), findsOneWidget);
    expect(find.byKey(const Key('khqr_confirmed')), findsOneWidget);

    final checks = payments.checks;
    await tester.pump(KhqrPaymentScreen.pollEvery * 2);
    expect(payments.checks, checks); // stops checking once paid

    await tester.tap(find.byKey(const Key('khqr_done')));
    await tester.pumpAndSettle();
    expect(results, [true]); // the Cart forgets the promo code
  });

  testWidgets('closing the KHQR screen shows Order placed, which can open it again', (tester) async {
    await _pump(tester, FakeCheckoutService(addresses: [FakeCheckoutService.home]));
    await _place(tester);
    await tester.tap(find.byKey(const Key('khqr_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('placed_title')), findsOneWidget);
    expect(find.byKey(const Key('placed_pay')), findsOneWidget);
  });

  testWidgets('an expired KHQR shows that the order was cancelled', (tester) async {
    final payments = FakePaymentService();
    await _pump(tester, FakeCheckoutService(addresses: [FakeCheckoutService.home]), payments: payments);
    await _place(tester);
    payments.state = KhqrStatus.expired;
    await tester.pump(KhqrPaymentScreen.pollEvery);
    await tester.pump();
    expect(find.byKey(const Key('khqr_expired')), findsOneWidget);
    expect(find.text('Back to shop'), findsOneWidget);
  });

  testWidgets("I've paid - check now asks the server straight away", (tester) async {
    final payments = FakePaymentService();
    await _pump(tester, FakeCheckoutService(addresses: [FakeCheckoutService.home]), payments: payments);
    await _place(tester);
    expect(find.byKey(const Key('khqr_card')), findsOneWidget);
    payments.state = KhqrStatus.paid;
    await tester.tap(find.byKey(const Key('khqr_check')));
    await tester.pumpAndSettle();
    expect(payments.checks, 1);
    expect(find.byKey(const Key('khqr_paid_stamp')), findsOneWidget);
  });

  testWidgets('store pickup is free and paid at the shop', (tester) async {
    final service = FakeCheckoutService(addresses: [FakeCheckoutService.home], cart: {3: 2}); // $10, delivery would be $2
    await _pump(tester, service);
    expect(tester.widget<Text>(find.byKey(const Key('checkout_delivery_fee'))).data, r'$2');

    await tester.tap(find.byKey(const Key('delivery_pickup')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('checkout_store')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('checkout_delivery_fee'))).data, 'Free');
    expect(tester.widget<Text>(find.byKey(const Key('checkout_total'))).data, r'$10');

    await tester.tap(find.byKey(const Key('pay_cod')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('checkout_note')), 'I will come at 5pm');
    await _place(tester);
    expect(service.placed.single['delivery'], DeliveryMethod.pickup);
    expect(service.placed.single['payment'], PaymentMethod.cod);
    expect(service.placed.single['note'], 'I will come at 5pm');
    expect(find.textContaining('at the shop'), findsOneWidget);
    expect(find.byKey(const Key('placed_pay')), findsNothing);
  });

  testWidgets('without an address: asks for one, then the new one is used', (tester) async {
    final service = FakeCheckoutService();
    await _pump(tester, service);
    await _place(tester);
    expect(service.placed, isEmpty);
    expect(find.text('Add a delivery address first'), findsOneWidget);

    await tester.tap(find.byKey(const Key('checkout_add_address')));
    await tester.pumpAndSettle();
    expect(find.text('Demo Customer'), findsOneWidget); // name filled in from the profile
    await tester.enterText(find.byKey(const Key('address_phone')), '12');
    await tester.tap(find.byKey(const Key('address_save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a Cambodian number'), findsOneWidget);
    expect(find.textContaining('Street address is required'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('address_phone')), '012 345 678');
    await tester.enterText(find.byKey(const Key('address_street')), '#24 St. 271');
    await tester.enterText(find.byKey(const Key('address_city')), 'Chamkar Mon');
    await tester.tap(find.byKey(const Key('address_save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('#24 St. 271, Chamkar Mon, Phnom Penh'), findsOneWidget);

    await _place(tester);
    expect(service.placed.single['address'], 100);
    await tester.pumpWidget(const SizedBox()); // stop the KHQR timers
  });

  testWidgets('Change opens the picker; picking Work uses it', (tester) async {
    final service = FakeCheckoutService(addresses: [FakeCheckoutService.home, FakeCheckoutService.work]);
    await _pump(tester, service);
    await tester.tap(find.byKey(const Key('checkout_change_address')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('address_1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('address_2')));
    await tester.pumpAndSettle();
    expect(find.text('Work · Demo Customer'), findsOneWidget);

    await _place(tester);
    expect(service.placed.single['address'], 2);
    await tester.pumpWidget(const SizedBox()); // stop the KHQR timers
  });

  testWidgets('an expired promo code from the cart is dropped', (tester) async {
    await _pump(tester, FakeCheckoutService(addresses: [FakeCheckoutService.home]), coupon: 'OLDCODE');
    expect(find.textContaining('The promo code was removed'), findsOneWidget);
    expect(find.byKey(const Key('checkout_discount')), findsNothing);
    expect(tester.widget<Text>(find.byKey(const Key('checkout_total'))).data, r'$179');
  });

  testWidgets('a stock problem keeps the customer on checkout', (tester) async {
    final service = FakeCheckoutService(addresses: [FakeCheckoutService.home])
      ..placeError = ApiException('Some items changed. Only 1 left of Luffy.', statusCode: 409);
    await _pump(tester, service);
    await _place(tester);
    expect(find.text('Some items changed. Only 1 left of Luffy.'), findsOneWidget);
    expect(find.byKey(const Key('checkout_place')), findsOneWidget);
    expect(service.placed, isEmpty);
  });

  testWidgets('the items card opens to show every line', (tester) async {
    await _pump(tester, FakeCheckoutService(addresses: [FakeCheckoutService.home]));
    expect(find.text('3 items'), findsOneWidget);
    expect(find.text(demoProducts[0].name), findsNothing);
    await tester.tap(find.byKey(const Key('checkout_items')));
    await tester.pumpAndSettle();
    expect(find.text(demoProducts[0].name), findsOneWidget);
  });
}
