import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/models/user.dart';
import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/providers/theme_provider.dart';
import 'package:ecommerce_app/screens/home/home_screen.dart';
import 'package:ecommerce_app/screens/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/shop_fakes.dart';

final _demo = User(id: 2, fullName: 'Demo Customer', email: 'demo@shop.com');

Future<void> _pump(WidgetTester tester, FakeCatalogService catalog, {FakeShopService? shop, bool signedIn = false}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final auth = AuthProvider();
  if (signedIn) auth.updateUser(_demo);
  final shopProvider = ShopProvider(service: shop ?? FakeShopService())..setSignedIn(signedIn);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider.value(value: shopProvider),
    ],
    child: MaterialApp(theme: AppTheme.light, home: HomeScreen(catalogService: catalog)),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  // Long lists (e.g. the filter sheet) only build what is on screen: scroll to it first
  if (f.evaluate().isEmpty) {
    final sheet = find.descendant(of: find.byKey(const Key('filter_scroll')), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(f, 200, scrollable: sheet.evaluate().isNotEmpty ? sheet.first : find.byType(Scrollable).first);
  }
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('guest home shows brand bar, series tabs, banner and products', (tester) async {
    await _pump(tester, FakeCatalogService());

    expect(find.text('Anime World'), findsOneWidget);
    expect(find.text('Hi there, welcome'), findsOneWidget);
    expect(find.byKey(const Key('series_all')), findsOneWidget);
    expect(find.byKey(const Key('series_2')), findsOneWidget);
    expect(find.text('New scale figures'), findsOneWidget); // promo banner slider
    expect(find.text('Popular now'), findsOneWidget);
    expect(find.text('-11%'), findsOneWidget); // sale badge on the card
    expect(find.text(r'$169'), findsWidgets);
    expect(find.text('Sold out'), findsOneWidget);
  });

  testWidgets('add-to-cart button sits at the right edge of every card', (tester) async {
    await _pump(tester, FakeCatalogService());
    for (final id in [1, 2]) {
      final card = tester.getRect(find.byKey(Key('product_$id')));
      final add = tester.getRect(find.byKey(Key('add_$id')));
      // card padding 8 + info padding 4
      expect(card.right - add.right, closeTo(12, 0.5), reason: 'product $id');
    }
  });

  testWidgets('series tab filters the grid and hides the banner', (tester) async {
    final catalog = FakeCatalogService();
    await _pump(tester, catalog);

    await _tap(tester, find.byKey(const Key('series_2')));
    expect(catalog.lastQuery!.seriesId, 2);
    expect(find.text('New scale figures'), findsNothing);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.byKey(const Key('product_2')), findsOneWidget);
    expect(find.byKey(const Key('product_1')), findsNothing);

    await _tap(tester, find.byKey(const Key('series_all')));
    expect(catalog.lastQuery!.seriesId, isNull);
    expect(find.text('Popular now'), findsOneWidget);
  });

  testWidgets('tapping the search bar opens the Search screen', (tester) async {
    await _pump(tester, FakeCatalogService());
    await _tap(tester, find.byKey(const Key('home_search')));
    expect(find.byType(SearchScreen), findsOneWidget);
  });

  testWidgets('tapping a banner slide opens its category', (tester) async {
    final catalog = FakeCatalogService();
    await _pump(tester, catalog);

    await _tap(tester, find.byKey(const Key('promo_banner_figures')));
    expect(catalog.lastQuery!.categoryId, figures.id);
    expect(find.text('Scale Figures'), findsOneWidget); // title is the category name
    expect(find.byKey(const Key('product_1')), findsOneWidget);
    expect(find.byKey(const Key('product_3')), findsNothing);
  });

  testWidgets('guests are asked to log in for the heart and the plus', (tester) async {
    final shop = FakeShopService();
    await _pump(tester, FakeCatalogService(), shop: shop);

    await _tap(tester, find.byKey(const Key('heart_1')));
    expect(find.text('Log in to save items to your wishlist'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('add_1')));
    expect(find.text('Log in to add items to your cart'), findsOneWidget);
    expect(shop.wishlist, isEmpty);
    expect(shop.cart, 0);
  });

  testWidgets('signed in: heart toggles the wishlist and plus updates the cart badge', (tester) async {
    final shop = FakeShopService(cart: 2);
    await _pump(tester, FakeCatalogService(), shop: shop, signedIn: true);
    expect(find.text('Hi Demo, welcome back'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('cart_badge')), matching: find.text('2')), findsOneWidget);

    await _tap(tester, find.byKey(const Key('heart_1')));
    expect(shop.wishlist, {1});
    expect(find.text('Saved to your wishlist'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('heart_1')), matching: find.byIcon(Icons.favorite_rounded)), findsOneWidget);

    await _tap(tester, find.byKey(const Key('add_1')));
    expect(shop.cart, 3);
    expect(find.descendant(of: find.byKey(const Key('add_1')), matching: find.byIcon(Icons.check_rounded)), findsOneWidget);
    // The grid may have scrolled the header away; bring it back to read the badge
    await tester.scrollUntilVisible(find.byKey(const Key('cart_badge')), -300, scrollable: find.byType(Scrollable).first);
    expect(find.descendant(of: find.byKey(const Key('cart_badge')), matching: find.text('3')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2)); // check mark goes back to plus

    // Sold out: the plus does nothing
    await _tap(tester, find.byKey(const Key('add_2')));
    expect(shop.cart, 3);
  });

  testWidgets('filter sheet applies category and in-stock, and shows a count on the button', (tester) async {
    final catalog = FakeCatalogService();
    await _pump(tester, catalog);

    await _tap(tester, find.byKey(const Key('home_filter')));
    expect(find.text('Filters'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('filter_cat_6')));
    await _tap(tester, find.byKey(const Key('filter_in_stock')));
    await _tap(tester, find.byKey(const Key('filter_apply')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(catalog.lastQuery!.categoryId, 6);
    expect(catalog.lastQuery!.inStockOnly, isTrue);
    expect(find.text('Filtered results'), findsOneWidget);
    expect(find.text('10 items'), findsOneWidget); // the sold-out box is hidden
    expect(find.descendant(of: find.byType(Badge), matching: find.text('2')), findsOneWidget);
  });

  testWidgets('sort menu re-requests with the chosen order', (tester) async {
    final catalog = FakeCatalogService();
    await _pump(tester, catalog);
    await _tap(tester, find.byKey(const Key('home_sort')));
    await _tap(tester, find.text('Price: low to high').last);
    expect(catalog.lastQuery!.sort.apiValue, 'price_asc');
  });

  testWidgets('scrolling to the end loads the next page', (tester) async {
    final catalog = FakeCatalogService();
    await _pump(tester, catalog);
    expect(catalog.pages, [1]);

    await tester.scrollUntilVisible(find.byKey(const Key('product_12')), 400, scrollable: find.byType(Scrollable).first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(catalog.pages, [1, 2]);
    expect(find.byKey(const Key('product_12')), findsOneWidget);
  });

  testWidgets('a failed load shows the error and Try again', (tester) async {
    final catalog = FakeCatalogService()..fail = true;
    await _pump(tester, catalog);
    expect(find.text('Cannot connect to server. Check your internet connection.'), findsOneWidget);

    catalog.fail = false;
    await _tap(tester, find.byKey(const Key('feed_retry')));
    expect(find.byKey(const Key('product_1')), findsOneWidget);
  });
}
