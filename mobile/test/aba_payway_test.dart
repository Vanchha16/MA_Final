import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/screens/checkout/khqr_payment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes/checkout_fake.dart';
import 'fakes/shop_fakes.dart';

Future<List<Uri>> _pump(WidgetTester tester, {required bool installed}) async {
  tester.view.physicalSize = const Size(412, 1500) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final opened = <Uri>[];
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => ShopProvider(service: FakeShopService())..setSignedIn(true),
    child: MaterialApp(
      theme: AppTheme.light,
      home: KhqrPaymentScreen(
        order: FakePaymentService.abaOrder,
        service: FakePaymentService(payway: true),
        openLink: (link) async {
          opened.add(link);
          return installed || link.scheme != 'abamobilebank';
        },
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
  return opened;
}

void main() {
  testWidgets('Open ABA Mobile opens the PayWay deeplink', (tester) async {
    final opened = await _pump(tester, installed: true);
    await tester.tap(find.byKey(const Key('aba_open')));
    await tester.pump();
    expect(opened.single.toString(), startsWith('abamobilebank://ababank.com?type=payway'));
    expect(find.byKey(const Key('aba_missing')), findsNothing);
    await tester.pumpWidget(const SizedBox()); // stop the timers
  });

  testWidgets('without ABA Mobile it says so and offers the app store', (tester) async {
    final opened = await _pump(tester, installed: false);
    await tester.tap(find.byKey(const Key('aba_open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('aba_missing')), findsOneWidget);
    await tester.tap(find.text('Get ABA'));
    await tester.pump();
    expect(opened.last.host, 'play.google.com');
    await tester.pumpWidget(const SizedBox());
  });
}
