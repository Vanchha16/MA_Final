import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/models/catalog.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/screens/shell/main_shell.dart';
import 'package:ecommerce_app/screens/shop/shop_actions.dart';
import 'package:ecommerce_app/widgets/cart_button.dart';
import 'package:ecommerce_app/widgets/cart_fly.dart';
import 'package:ecommerce_app/widgets/product_card.dart';
import 'package:ecommerce_app/widgets/product_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes/shop_fakes.dart';

/// A cart button at the top and one product below it, like the Home screen.
Future<FakeShopService> _pump(WidgetTester tester, {bool tile = false, bool cartVisible = true, bool reduceMotion = false}) async {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final shop = FakeShopService();
  final Product p = demoProducts.first;
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
                Align(alignment: Alignment.centerRight, child: Visibility.maintain(visible: cartVisible, child: const CartButton())),
                const SizedBox(height: 300),
                SizedBox(
                  width: tile ? 380 : 200,
                  child: tile
                      ? ProductTile(product: p, onAddToCart: () => ShopActions.addToCart(context, p))
                      : ProductCard(product: p, onAddToCart: () => ShopActions.addToCart(context, p)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
  CartFly.landings = 0;
  return shop;
}

/// The flight starts on the frame after the add finishes, so give it a little extra.
Future<void> _land(WidgetTester tester) async {
  await tester.pump(CartFly.duration);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();
}

Future<void> _add(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('add_1')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('plus shows the toast and the photo flies into the cart button', (tester) async {
    final shop = await _pump(tester);
    await _add(tester);

    expect(shop.cart, 1);
    expect(find.byKey(const Key('added_toast')), findsOneWidget);
    expect(find.text('Added to cart'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('added_toast')), matching: find.text(demoProducts.first.name)), findsOneWidget);
    expect(find.byKey(const Key('cart_fly')), findsOneWidget);

    await _land(tester);
    expect(find.byKey(const Key('cart_fly')), findsNothing);
    expect(CartFly.landings, 1);
    expect(find.descendant(of: find.byKey(const Key('cart_badge')), matching: find.text('1')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('list rows fly too', (tester) async {
    await _pump(tester, tile: true);
    await _add(tester);
    expect(find.byKey(const Key('cart_fly')), findsOneWidget);
    await _land(tester);
    expect(CartFly.landings, 1);
  });

  testWidgets('no flight when the cart button is hidden or motion is reduced', (tester) async {
    await _pump(tester, cartVisible: false);
    await _add(tester);
    expect(find.byKey(const Key('added_toast')), findsOneWidget);
    expect(find.byKey(const Key('cart_fly')), findsNothing);
    await tester.pump(const Duration(seconds: 2));

    await _pump(tester, reduceMotion: true);
    await _add(tester);
    expect(find.byKey(const Key('added_toast')), findsOneWidget);
    expect(find.byKey(const Key('cart_fly')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('View on the toast opens the Cart tab', (tester) async {
    addTearDown(() => MainShell.requestedTab.value = null);
    await _pump(tester);
    await _add(tester);
    await tester.tap(find.byKey(const Key('added_toast_view')));
    await tester.pump();
    expect(MainShell.requestedTab.value, MainShell.cartTab);
    await tester.pump(const Duration(seconds: 2));
  });
}
