import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/providers/locale_provider.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/providers/theme_provider.dart';
import 'package:ecommerce_app/screens/shell/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/shop_fakes.dart';

Future<FakeShopService> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(400, 860) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final shop = FakeShopService();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ChangeNotifierProvider(create: (_) => ShopProvider(service: shop)..setSignedIn(true)),
    ],
    child: MaterialApp(home: MainShell(catalogService: FakeCatalogService())),
  ));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  return shop;
}

int _tab(WidgetTester tester) => tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

void main() {
  testWidgets('saving a product: burst + flying heart, the tab counts it, and the toast opens the wishlist', (tester) async {
    final shop = await _pump(tester);
    expect(find.descendant(of: find.byKey(const Key('tab_wishlist_badge')), matching: find.text('1')), findsNothing);

    final heart = find.byKey(const Key('heart_1')).first;
    await tester.ensureVisible(heart);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(heart);
    // Let the burst and the flying heart finish
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(shop.wishlist, {1});
    expect(find.byKey(const Key('saved_toast')), findsOneWidget);
    expect(find.text('Saved to your wishlist'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('tab_wishlist_badge')), matching: find.text('1')), findsOneWidget);

    expect(_tab(tester), 0);
    await tester.tap(find.byKey(const Key('saved_toast_view')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_tab(tester), MainShell.wishlistTab);
    await tester.pump(const Duration(seconds: 4));
  });
}
