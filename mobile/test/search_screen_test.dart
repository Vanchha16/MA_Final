import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/providers/theme_provider.dart';
import 'package:ecommerce_app/screens/catalog/product_details_screen.dart';
import 'package:ecommerce_app/screens/catalog/product_list_screen.dart';
import 'package:ecommerce_app/screens/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/shop_fakes.dart';

Future<void> _pump(WidgetTester tester, FakeCatalogService catalog, {List<String> recent = const []}) async {
  SharedPreferences.setMockInitialValues({'recent_searches': recent});
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => ShopProvider(service: FakeShopService())),
    ],
    child: MaterialApp(theme: AppTheme.light, home: SearchScreen(catalogService: catalog)),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('search_field')), text);
  await tester.pump(const Duration(milliseconds: 350)); // debounce
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('before typing: recent, popular and trending', (tester) async {
    await _pump(tester, FakeCatalogService(), recent: ['luffy', 'booster box']);

    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.byKey(const Key('recent_luffy')), findsOneWidget);
    expect(find.byKey(const Key('popular_One Piece')), findsOneWidget); // top series first
    expect(find.byKey(const Key('popular_Nendoroid')), findsOneWidget);
    expect(find.text('Trending now'), findsOneWidget);
    expect(find.byKey(const Key('trending_1')), findsOneWidget); // the featured Luffy
  });

  testWidgets('typing shows product and phrase suggestions after a short pause', (tester) async {
    final catalog = FakeCatalogService();
    await _pump(tester, catalog);

    await tester.enterText(find.byKey(const Key('search_field')), 'l');
    await tester.pump(const Duration(milliseconds: 100));
    await _type(tester, 'luf');
    expect(catalog.suggestionQueries, ['luf']); // one request, not one per letter

    expect(find.text('PRODUCTS'), findsOneWidget);
    expect(find.byKey(const Key('suggest_product_1')), findsOneWidget);
    expect(find.byKey(const Key('suggest_keyword_luffy')), findsOneWidget);
    expect(find.text('See all 1 result for "luf"'), findsOneWidget);
  });

  testWidgets('See all opens the results and remembers the search', (tester) async {
    final catalog = FakeCatalogService();
    await _pump(tester, catalog);
    await _type(tester, 'booster');

    await _tap(tester, find.byKey(const Key('search_see_all')));
    expect(find.byType(ProductListScreen), findsOneWidget);
    expect(find.text('Results for "booster"'), findsOneWidget);
    expect(catalog.lastQuery!.q, 'booster');
    expect((await SharedPreferences.getInstance()).getStringList('recent_searches'), ['booster']);
  });

  testWidgets('a product suggestion opens its details', (tester) async {
    await _pump(tester, FakeCatalogService());
    await _type(tester, 'luf');
    await _tap(tester, find.byKey(const Key('suggest_product_1')));
    expect(find.byType(ProductDetailsScreen), findsOneWidget);
  });

  testWidgets('no matches shows a friendly message', (tester) async {
    await _pump(tester, FakeCatalogService());
    await _type(tester, 'zzz');
    expect(find.text('No matches for "zzz"'), findsOneWidget);
    expect(find.byKey(const Key('search_see_all')), findsNothing);
  });

  testWidgets('recent searches can be removed one by one or all at once', (tester) async {
    await _pump(tester, FakeCatalogService(), recent: ['luffy', 'gundam', 'plush']);

    await _tap(tester, find.byTooltip('Remove gundam'));
    expect(find.byKey(const Key('recent_gundam')), findsNothing);
    expect((await SharedPreferences.getInstance()).getStringList('recent_searches'), ['luffy', 'plush']);

    await _tap(tester, find.byKey(const Key('recent_clear')));
    expect(find.text('Recent searches'), findsNothing);
  });

  testWidgets('clearing the field goes back to recent and popular', (tester) async {
    await _pump(tester, FakeCatalogService());
    await _type(tester, 'luf');
    expect(find.byKey(const Key('search_typing')), findsOneWidget);
    await _tap(tester, find.byKey(const Key('search_clear')));
    expect(find.byKey(const Key('search_idle')), findsOneWidget);
  });
}
