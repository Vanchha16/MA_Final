import 'dart:async';

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

Future<FakeShopService> _pump(WidgetTester tester, {FakeShopService? service}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(400, 860) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final shop = service ?? FakeShopService();
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

  test('a second heart tap while the first is still saving is ignored', () async {
    final service = _SlowShopService();
    final shop = ShopProvider(service: service)..setSignedIn(true);
    await Future<void>.delayed(Duration.zero);

    final first = shop.toggleWishlist(1);
    expect(shop.isWishlisted(1), isTrue); // the heart fills at once
    expect(await shop.toggleWishlist(1), isNull); // quick second tap: ignored
    expect(shop.isWishlisted(1), isTrue);
    service.finish();
    expect(await first, isTrue);
    expect(service.calls, ['add 1']);

    final second = shop.toggleWishlist(1); // once saved, a tap removes it again
    service.finish();
    expect(await second, isFalse);
    expect(service.calls, ['add 1', 'remove 1']);
  });

  testWidgets('double-tapping a heart saves it once with one toast', (tester) async {
    final shop = _SlowShopService();
    await _pump(tester, service: shop);
    final heart = find.byKey(const Key('heart_1')).first;
    await tester.ensureVisible(heart);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(heart);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(heart); // while the first save is still on its way
    shop.finish();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(shop.wishlist, {1});
    expect(shop.calls, ['add 1']);
    expect(find.byKey(const Key('saved_toast')), findsOneWidget);
    expect(find.text('Removed from your wishlist'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });
}

/// Each wishlist call waits until the test says the server answered.
class _SlowShopService extends FakeShopService {
  final calls = <String>[];
  Completer<void>? _pending;

  void finish() => _pending?.complete();

  Future<void> _wait() => (_pending = Completer<void>()).future;

  @override
  Future<void> addToWishlist(int productId) async {
    calls.add('add $productId');
    await _wait();
    wishlist.add(productId);
  }

  @override
  Future<void> removeFromWishlist(int productId) async {
    calls.add('remove $productId');
    await _wait();
    wishlist.remove(productId);
  }
}
