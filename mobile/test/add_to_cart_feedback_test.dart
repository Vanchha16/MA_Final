import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/models/catalog.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/screens/shell/main_shell.dart';
import 'package:ecommerce_app/screens/shop/shop_actions.dart';
import 'package:ecommerce_app/widgets/cart_button.dart';
import 'package:ecommerce_app/widgets/cart_drive.dart';
import 'package:ecommerce_app/widgets/cart_tab_icon.dart';
import 'package:ecommerce_app/widgets/product_card.dart';
import 'package:ecommerce_app/widgets/product_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes/shop_fakes.dart';

/// Which cart target (if any) is on screen, in [_pump].
enum _Target { none, button, tab, both, hiddenButton }

/// A cart button at the top, one product, and optionally a Cart tab at the bottom.
Future<FakeShopService> _pump(WidgetTester tester, {bool tile = false, _Target target = _Target.button, bool reduceMotion = false}) async {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final shop = FakeShopService();
  final Product p = demoProducts.first;
  final button = target == _Target.button || target == _Target.both || target == _Target.hiddenButton;
  final tab = target == _Target.tab || target == _Target.both;
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => ShopProvider(service: shop)..setSignedIn(true),
    child: MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: const MediaQueryData(size: Size(412, 915)).copyWith(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                const SizedBox(height: 40),
                if (button)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Visibility.maintain(visible: target != _Target.hiddenButton, child: const CartButton()),
                  ),
                const SizedBox(height: 240),
                SizedBox(
                  width: tile ? 380 : 200,
                  child: tile
                      ? ProductTile(product: p, onAddToCart: () => ShopActions.addToCart(context, p))
                      : ProductCard(product: p, onAddToCart: () => ShopActions.addToCart(context, p)),
                ),
              ],
            ),
          ),
          bottomNavigationBar: tab
              ? NavigationBar(destinations: const [
                  NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
                  NavigationDestination(icon: CartTabIcon(), label: 'Cart'),
                ])
              : null,
        ),
      ),
    ),
  ));
  await tester.pump();
  CartDrive.arrivals = 0;
  return shop;
}

/// The drive starts on the frame after the add finishes, so give it a little extra.
Future<void> _arrive(WidgetTester tester) async {
  await tester.pump(CartDrive.duration);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();
}

Future<void> _add(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('add_1')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('plus shows the toast and a cart drives off with the product', (tester) async {
    final shop = await _pump(tester);
    await _add(tester);

    expect(shop.cart, 1);
    expect(find.byKey(const Key('cart_drive')), findsOneWidget);
    expect(find.byKey(const Key('added_toast')), findsNothing); // waits for the cart, so they never overlap

    await _arrive(tester);
    expect(find.byKey(const Key('cart_drive')), findsNothing);
    expect(CartDrive.arrivals, 1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('added_toast')), findsOneWidget);
    expect(find.text('Added to cart'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('added_toast')), matching: find.text(demoProducts.first.name)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('cart_badge')), matching: find.text('1')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the Cart tab is preferred, and its badge counts', (tester) async {
    await _pump(tester, target: _Target.both);
    await _add(tester);
    await _arrive(tester);
    expect(CartDrive.arrivals, 1);
    expect(find.descendant(of: find.byKey(const Key('tab_cart_badge')), matching: find.text('1')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('list rows drive too', (tester) async {
    await _pump(tester, tile: true, target: _Target.tab);
    await _add(tester);
    expect(find.byKey(const Key('cart_drive')), findsOneWidget);
    await _arrive(tester);
    expect(CartDrive.arrivals, 1);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('with no cart on screen it drives off the edge', (tester) async {
    for (final target in [_Target.none, _Target.hiddenButton]) {
      await _pump(tester, target: target);
      await _add(tester);
      expect(find.byKey(const Key('cart_drive')), findsOneWidget);
      await _arrive(tester);
      expect(find.byKey(const Key('cart_drive')), findsNothing);
      expect(CartDrive.arrivals, 0);
      await tester.pump(const Duration(seconds: 2));
    }
  });

  testWidgets('reduce motion: only the toast', (tester) async {
    await _pump(tester, reduceMotion: true);
    await _add(tester);
    expect(find.byKey(const Key('added_toast')), findsOneWidget);
    expect(find.byKey(const Key('cart_drive')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('View on the toast opens the Cart tab', (tester) async {
    addTearDown(() => MainShell.requestedTab.value = null);
    await _pump(tester);
    await _add(tester);
    await _arrive(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('added_toast_view')));
    await tester.pump();
    expect(MainShell.requestedTab.value, MainShell.cartTab);
    await tester.pump(const Duration(seconds: 2));
  });
}
