import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/models/user.dart';
import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/providers/theme_provider.dart';
import 'package:ecommerce_app/screens/catalog/product_details_screen.dart';
import 'package:ecommerce_app/screens/catalog/product_list_screen.dart';
import 'package:ecommerce_app/screens/home/home_screen.dart';
import 'package:ecommerce_app/screens/shell/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/review_fake.dart';
import 'fakes/shop_fakes.dart';

Future<void> _pump(WidgetTester tester, Widget home, {FakeShopService? shop, bool signedIn = true}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final auth = AuthProvider();
  if (signedIn) auth.updateUser(User(id: 2, fullName: 'Demo Customer', email: 'demo@shop.com'));
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => ShopProvider(service: shop ?? FakeShopService())..setSignedIn(signedIn)),
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

Widget _details(FakeCatalogService catalog, int index, {FakeReviewService? reviews}) =>
    ProductDetailsScreen(product: catalog.products_[index], catalogService: catalog, reviewService: reviews ?? FakeReviewService());

void main() {
  testWidgets('shows price, sale, stock, chips, reviews and related products', (tester) async {
    final catalog = FakeCatalogService();
    await _pump(tester, _details(catalog, 0));

    expect(find.text('Monkey D. Luffy Gear 5 1/7 Scale Figure'), findsOneWidget);
    expect(find.text(r'$169'), findsOneWidget);
    expect(find.text(r'$189'), findsOneWidget);
    expect(find.text('-11%'), findsOneWidget);
    expect(find.text('Only 5 left'), findsOneWidget);
    expect(find.text('Good Smile Company'), findsOneWidget);
    expect(find.text('Reviews (2)'), findsOneWidget);
    expect(find.text('Great quality, fast delivery!'), findsOneWidget);
    expect(find.text('14 days ago'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('More from One Piece'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.descendant(of: find.byKey(const Key('details_related')), matching: find.byKey(const Key('product_3'))), findsOneWidget);

    // See all opens the Reviews page
    await _tap(tester, find.byKey(const Key('reviews_see_all')));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Box arrived perfect.'), findsOneWidget);
    expect(find.byKey(const Key('reviews_filter_all')), findsOneWidget);
  });

  testWidgets('quantity stepper changes the total and adds that many to the cart', (tester) async {
    final shop = FakeShopService();
    await _pump(tester, _details(FakeCatalogService(), 0), shop: shop);

    expect(find.text(r'Add to cart  ·  $169'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('qty_plus')));
    expect(tester.widget<Text>(find.byKey(const Key('qty_value'))).data, '2');
    expect(find.text(r'Add to cart  ·  $338'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('details_add')));
    expect(shop.cart, 2);
    expect(find.byKey(const Key('added_sheet')), findsOneWidget);
    expect(find.byKey(const Key('added_toast')), findsNothing); // the sheet replaces the toast here
  });

  testWidgets('the Added sheet shows the cart, free delivery and closes with Keep shopping', (tester) async {
    final shop = FakeShopService();
    await _pump(tester, _details(FakeCatalogService(), 0), shop: shop);
    await _tap(tester, find.byKey(const Key('qty_plus')));
    await _tap(tester, find.byKey(const Key('details_add')));

    expect(find.text('Added to your cart'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('added_sheet_summary'))).data, r'2 items · $338 in your cart');
    expect(find.descendant(of: find.byKey(const Key('added_sheet')), matching: find.text('Monkey D. Luffy Gear 5 1/7 Scale Figure')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('added_sheet_delivery'))).data, 'You get FREE delivery');

    await _tap(tester, find.byKey(const Key('added_sheet_keep')));
    expect(find.byKey(const Key('added_sheet')), findsNothing);
    expect(find.byType(ProductDetailsScreen), findsOneWidget);
    expect(MainShell.requestedTab.value, isNull);
  });

  testWidgets('a small cart shows how much more is needed; View cart opens the Cart tab', (tester) async {
    addTearDown(() => MainShell.requestedTab.value = null);
    await _pump(tester, _details(FakeCatalogService(), 2)); // a $5 pack
    await _tap(tester, find.byKey(const Key('details_add')));

    expect(tester.widget<Text>(find.byKey(const Key('added_sheet_summary'))).data, r'1 item · $5 in your cart');
    expect(tester.widget<Text>(find.byKey(const Key('added_sheet_delivery'))).data, r'Add $45 more for free delivery');

    await _tap(tester, find.byKey(const Key('added_sheet_view')));
    expect(find.byKey(const Key('added_sheet')), findsNothing);
    expect(MainShell.requestedTab.value, MainShell.cartTab);
  });

  testWidgets('the stepper stops at the stock', (tester) async {
    await _pump(tester, _details(FakeCatalogService(), 0));
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byKey(const Key('qty_plus')), warnIfMissed: false);
      await tester.pump();
    }
    expect(tester.widget<Text>(find.byKey(const Key('qty_value'))).data, '5'); // only 5 in stock
  });

  testWidgets('sold out: no stepper and the button is off', (tester) async {
    await _pump(tester, _details(FakeCatalogService(), 1));
    expect(find.text('Sold out'), findsWidgets);
    expect(find.byKey(const Key('qty_plus')), findsNothing);
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('details_add'))).onPressed, isNull);
  });

  testWidgets('guests are asked to log in to add to cart', (tester) async {
    final shop = FakeShopService();
    await _pump(tester, _details(FakeCatalogService(), 0), shop: shop, signedIn: false);
    await _tap(tester, find.byKey(const Key('details_add')));
    expect(find.text('Log in to add items to your cart.'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('login_required_later')));
    expect(find.byKey(const Key('login_required')), findsNothing);
    expect(shop.cart, 0);
  });

  testWidgets('heart saves to the wishlist; series chip opens that series', (tester) async {
    final shop = FakeShopService();
    final catalog = FakeCatalogService();
    await _pump(tester, _details(catalog, 0), shop: shop);

    await _tap(tester, find.byKey(const Key('details_wishlist')));
    expect(shop.wishlist, {1});

    await _tap(tester, find.byKey(const Key('chip_series')));
    expect(find.byType(ProductListScreen), findsOneWidget);
    expect(catalog.lastQuery!.seriesId, 1);
  });

  testWidgets('tapping a product on Home opens its details', (tester) async {
    await _pump(tester, HomeScreen(catalogService: FakeCatalogService()));
    await _tap(tester, find.byKey(const Key('product_1')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ProductDetailsScreen), findsOneWidget);
  });

  testWidgets('if details fail to load, the product still shows with Try again', (tester) async {
    final catalog = FakeCatalogService()..detailFails = true;
    await _pump(tester, _details(catalog, 0));
    expect(find.text(r'$169'), findsOneWidget);
    expect(find.text('Cannot connect to server. Check your internet connection.'), findsOneWidget);

    catalog.detailFails = false;
    await _tap(tester, find.byKey(const Key('details_retry')));
    expect(find.text('Reviews (2)'), findsOneWidget);
  });
}
