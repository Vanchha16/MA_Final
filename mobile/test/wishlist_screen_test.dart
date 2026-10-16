import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/screens/wishlist/wishlist_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/shop_fakes.dart';

/// Demo products: 1 = Luffy figure on sale ($169), 2 = sold-out Pokemon box ($145), 3+ = $5 packs.
Future<(FakeShopService, ShopProvider)> _pump(
  WidgetTester tester, {
  Set<int>? saved,
  bool signedIn = true,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final shop = FakeShopService(wishlist: saved ?? {1, 2, 3});
  final provider = ShopProvider(service: shop)..setSignedIn(signedIn);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(theme: AppTheme.light, home: const WishlistScreen()),
  ));
  await tester.pumpAndSettle();
  return (shop, provider);
}

Finder _text(String s) => find.text(s);

Future<void> _settleSnack(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  group('Swipe (default)', () {
    testWidgets('Move to cart takes the card off the wishlist', (tester) async {
      final (shop, provider) = await _pump(tester);
      expect(find.byKey(const Key('swipe_card_1')), findsWidgets);
      expect(find.textContaining('1 of 3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('swipe_move')));
      await tester.pumpAndSettle();
      expect(shop.moves, [
        [1]
      ]);
      expect(provider.cartCount, 1);
      expect(find.textContaining('Moved ${demoProducts[0].name} to your cart'), findsOneWidget);
      expect(find.textContaining('2 of 3'), findsOneWidget);
      expect(_text('2 saved items'), findsOneWidget);
      await _settleSnack(tester);
    });

    testWidgets('a sold-out card cannot go to the cart', (tester) async {
      final (shop, _) = await _pump(tester, saved: {2, 3});
      expect(_text('Sold out'), findsWidgets);
      await tester.tap(find.byKey(const Key('swipe_move')));
      await tester.pumpAndSettle();
      expect(shop.moves, isEmpty); // button is off

      await tester.drag(find.byKey(const Key('swipe_card_2')).first, const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(shop.moves, isEmpty);
      expect(_text('Sold out - it stays in your wishlist'), findsOneWidget);
      expect(find.textContaining('1 of 2'), findsOneWidget);
      await _settleSnack(tester);
    });

    testWidgets('Remove has Undo that brings the card back', (tester) async {
      final (shop, _) = await _pump(tester);
      await tester.tap(find.byKey(const Key('swipe_remove')));
      await tester.pumpAndSettle();
      expect(shop.wishlist, {2, 3});
      expect(find.textContaining('2 of 3'), findsOneWidget);

      await tester.tap(_text('Undo'));
      await tester.pumpAndSettle();
      expect(shop.wishlist, contains(1));
      expect(find.textContaining('1 of 3'), findsOneWidget);
      await _settleSnack(tester);
    });

    testWidgets('after the last card: a summary and Go through again', (tester) async {
      final (shop, _) = await _pump(tester, saved: {1, 3});
      await tester.tap(find.byKey(const Key('swipe_later')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('swipe_remove')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('swipe_done')), findsOneWidget);
      expect(_text('1 removed · 1 kept for later'), findsOneWidget);

      await tester.tap(find.byKey(const Key('swipe_again')));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 of 1'), findsOneWidget);
      expect(shop.wishlist, {1});
      await _settleSnack(tester);
    });
  });

  testWidgets('Board view: totals, tabs, heart removes; the choice is remembered', (tester) async {
    final (shop, _) = await _pump(tester);
    await tester.tap(find.byKey(const Key('view_board')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('board_summary')), findsOneWidget);
    expect(_text(r'$319'), findsOneWidget); // 169 + 145 + 5
    expect((await SharedPreferences.getInstance()).getString(WishlistScreen.viewPrefKey), 'board');

    await tester.tap(find.byKey(const Key('board_tab_sale')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('board_tile_1')), findsOneWidget);
    expect(find.byKey(const Key('board_tile_2')), findsNothing);
    await tester.tap(find.byKey(const Key('board_tab_soldOut')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('board_tile_2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('board_tab_all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('board_heart_3')));
    await tester.pumpAndSettle();
    expect(shop.wishlist, {1, 2});
    expect(find.byKey(const Key('board_tile_3')), findsNothing);
    await _settleSnack(tester);
  });

  testWidgets('Select view: select all skips sold out, then move and remove', (tester) async {
    final (shop, _) = await _pump(tester, prefs: {WishlistScreen.viewPrefKey: 'select'});
    expect(find.byKey(const Key('select_list')), findsOneWidget);

    await tester.tap(find.byKey(const Key('select_all')));
    await tester.pump();
    expect(_text('2 selected'), findsOneWidget);
    expect(_text(r'Move 2 · $174'), findsOneWidget);

    await tester.tap(find.byKey(const Key('select_move')));
    await tester.pumpAndSettle();
    expect(shop.moves, [
      [1, 3]
    ]);
    expect(find.byKey(const Key('select_row_1')), findsNothing);
    expect(find.byKey(const Key('select_row_2')), findsOneWidget);
    await _settleSnack(tester);

    // Sold-out items can still be ticked to remove them
    await tester.tap(find.byKey(const Key('select_row_2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('select_remove')));
    await tester.pumpAndSettle();
    expect(shop.wishlist, isEmpty);
    expect(find.byKey(const Key('wishlist_empty')), findsOneWidget);
    await _settleSnack(tester);
  });

  testWidgets('a heart tapped elsewhere refreshes the list', (tester) async {
    final (_, provider) = await _pump(tester);
    expect(_text('3 saved items'), findsOneWidget);
    await provider.toggleWishlist(5);
    await tester.pumpAndSettle();
    expect(_text('4 saved items'), findsOneWidget);
  });

  testWidgets('empty and guest states', (tester) async {
    await _pump(tester, saved: {});
    expect(find.byKey(const Key('wishlist_empty')), findsOneWidget);
    expect(find.byKey(const Key('view_swipe')), findsNothing);

    await _pump(tester, signedIn: false);
    expect(find.byKey(const Key('wishlist_login')), findsOneWidget);
  });

  testWidgets('load error offers Try again', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final shop = FakeShopService(wishlist: {1})..failWishlist = true;
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => ShopProvider(service: shop)..setSignedIn(true),
      child: MaterialApp(theme: AppTheme.light, home: const WishlistScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wishlist_retry')), findsOneWidget);
    shop.failWishlist = false;
    await tester.tap(find.byKey(const Key('wishlist_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('swipe_card_1')), findsWidgets);
  });
}
