import 'package:ecommerce_app/api/api_client.dart';
import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/models/catalog.dart';
import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/providers/theme_provider.dart';
import 'package:ecommerce_app/screens/catalog/categories_screen.dart';
import 'package:ecommerce_app/screens/catalog/product_list_screen.dart';
import 'package:ecommerce_app/screens/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/shop_fakes.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  SharedPreferences.setMockInitialValues({});
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
  // Long lists (e.g. the filter sheet) only build what is on screen: scroll to it first
  if (f.evaluate().isEmpty) {
    final sheet = find.descendant(of: find.byKey(const Key('filter_scroll')), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(f, 200, scrollable: sheet.evaluate().isNotEmpty ? sheet.first : find.byType(Scrollable).first);
  }
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

class _FailingCatalog extends FakeCatalogService {
  bool down = true;

  @override
  Future<List<Category>> categories() async {
    if (down) throw ApiException('Cannot connect to server. Check your internet connection.');
    return super.categories();
  }
}

void main() {
  testWidgets('shows category tiles with counts and series circles', (tester) async {
    await _pump(tester, CategoriesScreen(catalogService: FakeCatalogService()));

    expect(find.text('2 categories · 12 products'), findsOneWidget);
    expect(find.text('Scale Figures'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('11 items'), findsOneWidget);
    expect(find.text('Shop by anime'), findsOneWidget);
    expect(find.byKey(const Key('series_tile_1')), findsOneWidget);
    expect(find.text('OP'), findsOneWidget); // initials when there is no cover photo
  });

  testWidgets('a category opens its product list, filtered by that category', (tester) async {
    final catalog = FakeCatalogService();
    await _pump(tester, CategoriesScreen(catalogService: catalog));

    await _tap(tester, find.byKey(const Key('category_tcg-boosters')));
    expect(find.byType(ProductListScreen), findsOneWidget);
    expect(catalog.lastQuery!.categoryId, 6);
    expect(find.descendant(of: find.byType(ProductListScreen), matching: find.text('TCG Boosters')), findsOneWidget); // title
    expect(find.text('11 products'), findsOneWidget);
    expect(find.byKey(const Key('product_2')), findsOneWidget);
    expect(find.byKey(const Key('product_1')), findsNothing);
  });

  testWidgets('a series circle opens its list and the search bar opens Search', (tester) async {
    final catalog = FakeCatalogService();
    await _pump(tester, CategoriesScreen(catalogService: catalog));

    await _tap(tester, find.byKey(const Key('series_tile_2')));
    expect(catalog.lastQuery!.seriesId, 2);
    expect(find.text('1 product'), findsOneWidget);
    await _tap(tester, find.byTooltip('Back'));

    await tester.pump(const Duration(milliseconds: 400)); // let the back animation finish
    await _tap(tester, find.byKey(const Key('categories_search')));
    expect(find.byType(SearchScreen), findsOneWidget);
  });

  testWidgets('product list filters stack on top of the category and can be cleared', (tester) async {
    final catalog = FakeCatalogService();
    await _pump(tester, ProductListScreen(title: 'TCG Boosters', query: const ProductQuery(categoryId: 6), catalogService: catalog));
    expect(find.text('11 products'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('list_filter')));
    await _tap(tester, find.byKey(const Key('filter_in_stock')));
    await _tap(tester, find.byKey(const Key('filter_apply')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(catalog.lastQuery!.categoryId, 6);
    expect(catalog.lastQuery!.inStockOnly, isTrue);
    expect(find.text('10 products'), findsOneWidget);
    expect(find.descendant(of: find.byType(Badge), matching: find.text('1')), findsOneWidget);
  });

  testWidgets('a failed load shows Try again', (tester) async {
    final catalog = _FailingCatalog();
    await _pump(tester, CategoriesScreen(catalogService: catalog));
    expect(find.text('Cannot connect to server. Check your internet connection.'), findsOneWidget);

    catalog.down = false;
    await _tap(tester, find.byKey(const Key('categories_retry')));
    expect(find.text('Scale Figures'), findsOneWidget);
  });
}
