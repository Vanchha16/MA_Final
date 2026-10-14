import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/models/catalog.dart';
import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/providers/theme_provider.dart';
import 'package:ecommerce_app/screens/catalog/product_list_screen.dart';
import 'package:ecommerce_app/screens/home/home_screen.dart';
import 'package:ecommerce_app/widgets/product_card.dart';
import 'package:ecommerce_app/widgets/product_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/shop_fakes.dart';

Future<void> _pump(WidgetTester tester, Widget home, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => ShopProvider(service: FakeShopService())),
    ],
    child: MaterialApp(theme: AppTheme.light, home: home),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Widget _list(FakeCatalogService catalog, {ProductQuery query = const ProductQuery()}) =>
    ProductListScreen(title: 'All products', query: query, catalogService: catalog);

void main() {
  testWidgets('grid / list toggle switches the layout and is remembered', (tester) async {
    await _pump(tester, _list(FakeCatalogService()));
    expect(find.byType(ProductCard), findsWidgets);
    expect(find.byType(ProductTile), findsNothing);

    await _tap(tester, find.byKey(const Key('list_view_toggle')));
    expect(find.byType(ProductTile), findsWidgets);
    expect(find.byType(ProductCard), findsNothing);
    expect((await SharedPreferences.getInstance()).getBool(ProductListScreen.viewPrefKey), isTrue);
  });

  testWidgets('opens in list view when that was the last choice', (tester) async {
    await _pump(tester, _list(FakeCatalogService()), prefs: {ProductListScreen.viewPrefKey: true});
    expect(find.byType(ProductTile), findsWidgets);
  });

  testWidgets('brand filter, active filter chips and removing them', (tester) async {
    final catalog = FakeCatalogService();
    await _pump(tester, _list(catalog));

    await _tap(tester, find.byKey(const Key('list_filter')));
    await _tap(tester, find.byKey(const Key('filter_brand_Bandai')));
    await _tap(tester, find.byKey(const Key('filter_in_stock')));
    await _tap(tester, find.byKey(const Key('filter_apply')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(catalog.lastQuery!.brand, 'Bandai');
    expect(catalog.lastQuery!.inStockOnly, isTrue);
    expect(find.byKey(const Key('active_brand')), findsOneWidget);
    expect(find.byKey(const Key('active_stock')), findsOneWidget);
    expect(find.descendant(of: find.byType(Badge), matching: find.text('2')), findsOneWidget);

    // Remove just the brand
    await _tap(tester, find.byTooltip('Remove Bandai'));
    expect(catalog.lastQuery!.brand, isNull);
    expect(catalog.lastQuery!.inStockOnly, isTrue);
    expect(find.byKey(const Key('active_brand')), findsNothing);
  });

  testWidgets('Clear all keeps the screen\'s own category', (tester) async {
    final catalog = FakeCatalogService();
    await _pump(tester, _list(catalog, query: const ProductQuery(categoryId: 6)));

    await _tap(tester, find.byKey(const Key('list_filter')));
    await _tap(tester, find.byKey(const Key('filter_brand_Bandai')));
    await _tap(tester, find.byKey(const Key('filter_in_stock')));
    await _tap(tester, find.byKey(const Key('filter_apply')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('active_category')), findsNothing); // the base category is not a chip

    await _tap(tester, find.byKey(const Key('active_clear_all')));
    expect(catalog.lastQuery!.categoryId, 6);
    expect(catalog.lastQuery!.brand, isNull);
    expect(catalog.lastQuery!.inStockOnly, isFalse);
  });

  testWidgets('See all on Home opens All products', (tester) async {
    final catalog = FakeCatalogService();
    await _pump(tester, HomeScreen(catalogService: catalog));
    await _tap(tester, find.byKey(const Key('home_see_all')));
    expect(find.byType(ProductListScreen), findsOneWidget);
    expect(find.text('All products'), findsOneWidget);
    expect(find.text('12 products'), findsOneWidget);
  });
}
