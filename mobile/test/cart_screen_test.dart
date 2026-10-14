import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/models/user.dart';
import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/providers/theme_provider.dart';
import 'package:ecommerce_app/screens/cart/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/cart_fake.dart';
import 'fakes/shop_fakes.dart';

late ShopProvider _shop;

Future<void> _pump(WidgetTester tester, FakeCartService cart, {bool signedIn = true, Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final auth = AuthProvider();
  if (signedIn) auth.updateUser(User(id: 2, fullName: 'Demo Customer', email: 'demo@shop.com'));
  _shop = ShopProvider(service: FakeShopService(cart: cart.count))..setSignedIn(signedIn);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider.value(value: _shop),
    ],
    child: MaterialApp(theme: AppTheme.light, home: CartScreen(cartService: cart, catalogService: FakeCatalogService())),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

String _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  // Luffy $169 (was $189) x1, One Piece pack #3 $5 x2
  final items = {1: 1, 3: 2};

  testWidgets('shows lines, receipt with free delivery and savings', (tester) async {
    await _pump(tester, FakeCartService(items: items));

    expect(find.text('2 products · 3 items'), findsOneWidget);
    expect(find.text(r'$169  ×  1'), findsOneWidget);
    expect(find.text('Only 5 left'), findsOneWidget);
    expect(_text(tester, 'sum_subtotal'), r'$179');
    expect(_text(tester, 'sum_delivery'), 'Free');
    expect(_text(tester, 'sum_total'), r'$179');
    expect(_text(tester, 'sum_savings'), r'You save $20 on this order');
  });

  testWidgets('small orders pay delivery and see how much more is needed', (tester) async {
    await _pump(tester, FakeCartService(items: {3: 2}));
    expect(_text(tester, 'sum_delivery'), r'$2');
    expect(_text(tester, 'sum_free_hint'), r'Add $40 more for free delivery');
    expect(_text(tester, 'sum_total'), r'$12');
  });

  testWidgets('the stepper changes the amount and the cart badge', (tester) async {
    await _pump(tester, FakeCartService(items: items));
    await _tap(tester, find.byKey(const Key('line_2_plus'))); // pack #3 -> 3
    expect(_text(tester, 'line_2_value'), '3');
    expect(_text(tester, 'sum_subtotal'), r'$184');
    expect(_shop.cartCount, 4);
  });

  testWidgets('swipe left removes an item and Undo brings it back', (tester) async {
    final cart = FakeCartService(items: items);
    await _pump(tester, cart);

    await tester.drag(find.byKey(const ValueKey('dismiss_1')), const Offset(-500, 0));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('line_1')), findsNothing);
    expect(find.textContaining('Removed'), findsOneWidget);
    expect(_shop.cartCount, 2);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(r'$169  ×  1'), findsOneWidget);
    expect(_shop.cartCount, 3);
  });

  testWidgets('a promo code is applied, shown and remembered', (tester) async {
    await _pump(tester, FakeCartService(items: items));

    await tester.enterText(find.byKey(const Key('promo_field')), 'welcome10');
    await _tap(tester, find.byKey(const Key('promo_apply')));
    expect(find.byKey(const Key('promo_applied')), findsOneWidget);
    expect(_text(tester, 'sum_discount'), r'-$17.90');
    expect(_text(tester, 'sum_total'), r'$161.10');
    expect((await SharedPreferences.getInstance()).getString(CartScreen.couponPrefKey), 'WELCOME10');

    await _tap(tester, find.byKey(const Key('promo_remove')));
    expect(find.byKey(const Key('sum_discount')), findsNothing);
    expect((await SharedPreferences.getInstance()).getString(CartScreen.couponPrefKey), isNull);
  });

  testWidgets('a bad promo code shows why', (tester) async {
    await _pump(tester, FakeCartService(items: {3: 2}));
    await tester.enterText(find.byKey(const Key('promo_field')), 'ANIME5');
    await _tap(tester, find.byKey(const Key('promo_apply')));
    expect(find.text(r'Spend $30 or more to use ANIME5'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('promo_field')), 'OLDCODE');
    await _tap(tester, find.byKey(const Key('promo_apply')));
    expect(find.text('This promo code has expired'), findsOneWidget);
  });

  testWidgets('a sold-out item blocks checkout until it is removed', (tester) async {
    await _pump(tester, FakeCartService(items: {2: 1, 3: 1})); // product 2 is sold out
    expect(find.text('Sold out - remove it to check out'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('cart_checkout'))).onPressed, isNull);
  });

  testWidgets('Clear asks first, then shows the empty cart', (tester) async {
    await _pump(tester, FakeCartService(items: items));
    await _tap(tester, find.byKey(const Key('cart_clear')));
    expect(find.text('Empty your cart?'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('cart_clear_confirm')));
    expect(find.byKey(const Key('cart_empty')), findsOneWidget);
    expect(find.byKey(const Key('cart_checkout')), findsNothing);
    expect(_shop.cartCount, 0);
  });

  testWidgets('guests are asked to log in', (tester) async {
    await _pump(tester, FakeCartService(), signedIn: false);
    expect(find.text('Log in to see your cart'), findsOneWidget);
    expect(find.byKey(const Key('cart_login')), findsOneWidget);
  });

  testWidgets('a failed load shows Try again', (tester) async {
    final cart = FakeCartService(items: items)..fail = true;
    await _pump(tester, cart);
    expect(find.text('Cannot connect to server. Check your internet connection.'), findsOneWidget);
    cart.fail = false;
    await _tap(tester, find.byKey(const Key('cart_retry')));
    expect(find.text('2 products · 3 items'), findsOneWidget);
  });
}
