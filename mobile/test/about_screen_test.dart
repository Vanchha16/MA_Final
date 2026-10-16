import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/providers/theme_provider.dart';
import 'package:ecommerce_app/screens/catalog/product_list_screen.dart';
import 'package:ecommerce_app/screens/settings/about_screen.dart';
import 'package:ecommerce_app/screens/settings/legal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/shop_fakes.dart';

Future<FakeCatalogService> _pump(WidgetTester tester, {bool reduceMotion = false, bool fail = false, ThemeData? theme}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(412, 1400) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final catalog = FakeCatalogService()
    ..fail = fail
    ..failCategories = fail;
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => ShopProvider(service: FakeShopService())),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: const Size(412, 1400), disableAnimations: reduceMotion),
        child: AboutScreen(version: '1.0.0', catalogService: catalog),
      ),
    ),
  ));
  // The entrance takes about 2.5 s; the photo columns keep drifting after that.
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
  return catalog;
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('shows the version, the city, the categories and the credit', (tester) async {
    await _pump(tester);
    expect(find.text('Anime World Shop'), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(find.text('Phnom Penh'), findsOneWidget);
    expect(find.byKey(const Key('about_category_scale-figures')), findsOneWidget);
    expect(find.byKey(const Key('about_category_tcg-boosters')), findsOneWidget);
    expect(find.text('SETEC Institute'), findsOneWidget);
    expect(find.byKey(const Key('about_credit')), findsOneWidget);
    await _end(tester);
  });

  testWidgets('a category chip opens that category', (tester) async {
    final catalog = await _pump(tester);
    await tester.tap(find.byKey(const Key('about_category_tcg-boosters')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ProductListScreen), findsOneWidget);
    expect(catalog.lastQuery?.categoryId, boosters.id);
    await _end(tester);
  });

  testWidgets('privacy and terms open their own pages; licenses opens the license list', (tester) async {
    await _pump(tester, reduceMotion: true);
    await tester.tap(find.byKey(const Key('about_privacy')));
    await tester.pumpAndSettle();
    expect(find.byType(LegalScreen), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.textContaining('never see or keep your bank'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('about_terms')));
    await tester.pumpAndSettle();
    expect(find.textContaining('valid for 15 minutes'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('about_licenses')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LicensePage), findsOneWidget);
    await _end(tester);
  });

  testWidgets('with animations off nothing moves, so the page settles', (tester) async {
    await _pump(tester, reduceMotion: true);
    await tester.pumpAndSettle(); // would time out if the drift were running
    expect(find.byKey(const Key('about_credit')), findsOneWidget);
  });

  testWidgets('without the server it still shows the shop, just no category chips', (tester) async {
    await _pump(tester, fail: true, theme: AppTheme.dark);
    expect(find.text('Anime World Shop'), findsOneWidget);
    expect(find.text('WE SELL'), findsNothing);
    expect(find.byKey(const Key('about_credit')), findsOneWidget);
    await _end(tester);
  });
}
