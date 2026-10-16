import 'package:ecommerce_app/core/network/api_client.dart';
import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/models/order.dart';
import 'package:ecommerce_app/models/user.dart';
import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/screens/checkout/checkout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes/checkout_fake.dart';
import 'fakes/shop_fakes.dart';

/// Cart: 1 Luffy figure ($169) + 2 packs ($5) = $179, so delivery is free.
/// A host page pushes the checkout and keeps what it pops with.
Future<(ShopProvider, List<Object?>)> _pump(WidgetTester tester, FakeCheckoutService service, {String? coupon}) async {
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
              onPressed: () async => results.add(await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckoutScreen(coupon: coupon, service: service)))),
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

Future<void> _place(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('checkout_place')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('places a KHQR order to the default address with the cart promo code', (tester) async {
    final service = FakeCheckoutService(addresses: [FakeCheckoutService.work, FakeCheckoutService.home]);
    final (shop, results) = await _pump(tester, service, coupon: 'WELCOME10');

    expect(find.text('Home · Demo Customer'), findsOneWidget); // the default comes first
    expect(find.text(r'-$17.90'), findsOneWidget);
    expect(find.byKey(const Key('checkout_total')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('checkout_total'))).data, r'$161.10');

    await _place(tester);
    expect(service.placed.single, {'address': 1, 'delivery': DeliveryMethod.standard, 'payment': PaymentMethod.khqr, 'coupon': 'WELCOME10', 'note': ''});
    expect(find.byKey(const Key('placed_title')), findsOneWidget);
    expect(find.text('AWS-20261016-0007'), findsOneWidget);
    expect(find.byKey(const Key('placed_pay')), findsOneWidget);
    expect(shop.cartCount, 0);

    await tester.tap(find.byKey(const Key('placed_shop')));
    await tester.pumpAndSettle();
    expect(results, [true]); // the Cart forgets the promo code
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
