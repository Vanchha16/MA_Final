import 'dart:convert';

import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/models/user.dart';
import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/screens/admin/admin_more_screen.dart';
import 'package:ecommerce_app/screens/admin/admin_orders_screen.dart';
import 'package:ecommerce_app/screens/admin/admin_products_screen.dart';
import 'package:ecommerce_app/screens/admin/admin_staff_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/admin_fake.dart';

Future<FakeAdminService> _pump(WidgetTester tester, Widget Function(FakeAdminService) build, {String role = 'admin'}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(412, 1500) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final s = FakeAdminService();
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => AuthProvider()..updateUser(role == 'admin' ? User(id: 1, fullName: 'Admin', email: 'admin@shop.com', role: 'admin') : User(id: 4, fullName: 'Shop Staff', email: 'staff@shop.com', role: 'staff')),
    child: MaterialApp(theme: AppTheme.light, home: MediaQuery(data: const MediaQueryData(size: Size(412, 1500), disableAnimations: true), child: Scaffold(body: build(s)))),
  ));
  await tester.pumpAndSettle();
  return s;
}

/// A real 1x1 PNG, so the photo preview can decode it.
const _png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

/// Order details has a pulsing tracker, so wait fixed steps instead of settling.
/// Filter chips sit in a sideways strip; bring the chip into view before tapping it.
Future<void> _chip(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _steps(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('Orders: counts per status, search, and a one-tap next step', (tester) async {
    final s = await _pump(tester, (s) => AdminOrdersScreen(service: s));
    expect(find.text('3 to handle'), findsOneWidget);
    expect(find.text('Shipped  1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('admin_order_next_1'))); // pending cash order -> Confirm
    await tester.pumpAndSettle();
    expect(s.statuses, [(1, 'confirmed')]);
    expect(find.textContaining('marked confirmed'), findsOneWidget);

    await _chip(tester, 'admin_orders_filter_3');
    expect(find.byKey(const Key('admin_order_5')), findsOneWidget);
    expect(find.byKey(const Key('admin_order_1')), findsNothing);

    await _chip(tester, 'admin_orders_filter_0');
    await tester.enterText(find.byType(TextField), '0002');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin_order_2')), findsOneWidget);
    expect(find.byKey(const Key('admin_order_3')), findsNothing);
  });

  testWidgets('Order details: Mark shipped, and Cancel asks first', (tester) async {
    final s = await _pump(tester, (s) => AdminOrdersScreen(service: s));
    await tester.tap(find.byKey(const Key('admin_order_2')));
    await _steps(tester);
    expect(find.text('Mark shipped'), findsOneWidget);
    expect(find.text('Demo Customer'), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin_order_next')));
    await _steps(tester);
    expect(s.statuses, [(2, 'shipped')]);
    expect(find.text('Mark delivered'), findsOneWidget);
    expect(find.byKey(const Key('admin_order_cancel')), findsNothing); // shipped orders cannot be cancelled

    await tester.pageBack();
    await _steps(tester);
    await tester.tap(find.byKey(const Key('admin_order_1')));
    await _steps(tester);
    await tester.tap(find.byKey(const Key('admin_order_cancel')));
    await _steps(tester);
    expect(find.text('Cancel this order?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin_cancel_confirm')));
    await _steps(tester);
    expect(s.statuses.last, (1, 'cancelled'));
    expect(find.byKey(const Key('admin_order_next')), findsNothing); // finished
  });

  testWidgets('Products: filters and the In shop switch', (tester) async {
    final s = await _pump(tester, (s) => AdminProductsScreen(service: s));
    expect(find.text('2 in shop'), findsOneWidget);
    await _chip(tester, 'admin_products_filter_3');
    expect(find.text('Old Keychain'), findsOneWidget);
    expect(find.text('Satoru Gojo 1/7'), findsNothing);
    await tester.tap(find.byKey(const Key('admin_product_in_shop_9')));
    await tester.pumpAndSettle();
    expect(s.products_.firstWhere((p) => p.product.id == 9).isActive, isTrue);
    expect(find.text('Old Keychain is back in the shop.'), findsOneWidget);
  });

  testWidgets('Add product: shows the server errors, then saves with the picked photo', (tester) async {
    final s = await _pump(tester, (s) => AdminProductFormScreen(service: s, pickPhotos: () async => [XFile.fromData(base64Decode(_png), name: 'zoro.png')]));
    await tester.tap(find.byKey(const Key('admin_product_save')));
    await tester.pumpAndSettle();
    expect(find.text('name is required'), findsOneWidget);

    await tester.tap(find.byKey(const Key('admin_product_add_photo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('admin_product_name')), 'Zoro 1/8');
    await tester.enterText(find.byKey(const Key('admin_product_price')), '120');
    await tester.tap(find.byKey(const Key('admin_product_stock_plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('admin_product_save')));
    await tester.pumpAndSettle();
    final saved = s.savedProducts.last;
    expect(saved['name'], 'Zoro 1/8');
    expect(saved['price'], 120.0);
    expect(saved['stock'], 2);
    expect(saved['category_id'], 1); // the first category by default
    expect(s.uploads, [99]); // the photo goes up once the product exists
  });

  testWidgets('Categories: only empty ones can be deleted; add a new one', (tester) async {
    final s = await _pump(tester, (s) => AdminCategoriesScreen(service: s));
    await tester.tap(find.byKey(const Key('admin_category_delete_1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('still has 2 products'), findsOneWidget);

    await tester.tap(find.byKey(const Key('admin_category_delete_5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin_category_delete_confirm')));
    await tester.pumpAndSettle();
    expect(s.categories_.map((c) => c.id), [1]);

    ScaffoldMessenger.of(tester.element(find.byType(AdminCategoriesScreen))).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin_category_new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('admin_category_name')), 'Posters');
    await tester.tap(find.byKey(const Key('admin_category_save')));
    await tester.pumpAndSettle();
    expect(find.text('Posters'), findsOneWidget);
  });

  testWidgets('Customers: blocked filter and Block asks first', (tester) async {
    final s = await _pump(tester, (s) => AdminCustomersScreen(service: s));
    await _chip(tester, 'admin_customers_filter_2');
    expect(find.text('Spam Bot'), findsOneWidget);
    expect(find.text('Demo Customer'), findsNothing);

    await _chip(tester, 'admin_customers_filter_0');
    await tester.tap(find.byKey(const Key('admin_customer_2')));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget); // orders
    await tester.tap(find.byKey(const Key('admin_customer_block')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin_block_confirm')));
    await tester.pumpAndSettle();
    expect(s.customers_.firstWhere((c) => c.id == 2).isActive, isFalse);
    expect(find.byKey(const Key('admin_customer_unblock')), findsOneWidget);
  });

  testWidgets('Messages: reply moves the question to Answered', (tester) async {
    final s = await _pump(tester, (s) => AdminMessagesScreen(service: s));
    expect(find.text('When will my Luffy figure arrive?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin_message_reply_1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('admin_reply_text')), 'Tomorrow!');
    await tester.pump();
    await tester.tap(find.byKey(const Key('admin_reply_send')));
    await tester.pumpAndSettle();
    expect(s.replies, [(1, 'Tomorrow!')]);
    expect(find.text('No questions waiting. Nice!'), findsOneWidget);
    await _chip(tester, 'admin_messages_filter_1');
    expect(find.text('Tomorrow!'), findsOneWidget);
  });

  testWidgets('More lists the admin sections and Log out', (tester) async {
    await _pump(tester, (s) => AdminMoreScreen(service: s, onShop: () {}, openMessages: 2));
    for (final k in ['messages', 'customers', 'categories', 'shop', 'web', 'settings']) {
      expect(find.byKey(Key('admin_more_$k')), findsOneWidget);
    }
    expect(find.byKey(const Key('admin_logout')), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin_more_messages')));
    await tester.pumpAndSettle();
    expect(find.byType(AdminMessagesScreen), findsOneWidget);
  });

  testWidgets('More: the owner sees Staff; a staff account does not, and cannot block customers', (tester) async {
    await _pump(tester, (s) => AdminMoreScreen(service: s, onShop: () {}));
    expect(find.byKey(const Key('admin_more_staff')), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin_more_staff')));
    await tester.pumpAndSettle();
    expect(find.byType(AdminStaffScreen), findsOneWidget);
  });

  testWidgets('Staff role: no Staff row, and Customers has no Block button', (tester) async {
    await _pump(tester, (s) => AdminMoreScreen(service: s, onShop: () {}), role: 'staff');
    expect(find.byKey(const Key('admin_more_staff')), findsNothing);
    expect(find.textContaining('/dashboard'), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin_more_customers')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin_customer_2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin_customer_block')), findsNothing);
  });

  testWidgets('Staff: add a staff member, then promote, reset the password and disable', (tester) async {
    final s = await _pump(tester, (s) => AdminStaffScreen(service: s));
    expect(find.text('You'), findsOneWidget);
    await _chip(tester, 'admin_staff_filter_1');
    expect(find.byKey(const Key('admin_staff_4')), findsNothing);
    await _chip(tester, 'admin_staff_filter_0');

    await tester.tap(find.byKey(const Key('admin_staff_new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('admin_staff_name')), 'Sokha Chan');
    await tester.enterText(find.byKey(const Key('admin_staff_email')), 'sokha@shop.com');
    await tester.enterText(find.byKey(const Key('admin_staff_password')), 'short');
    await tester.tap(find.byKey(const Key('admin_staff_save')));
    await tester.pumpAndSettle();
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('admin_staff_password')), 'welcome123');
    await tester.tap(find.byKey(const Key('admin_staff_save')));
    await tester.pumpAndSettle();
    expect(find.text('Sokha Chan'), findsOneWidget);

    await tester.tap(find.byKey(const Key('admin_staff_4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin_staff_role_admin')));
    await tester.tap(find.byKey(const Key('admin_staff_reset')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('admin_staff_password')), 'newpass123');
    await tester.tap(find.byKey(const Key('admin_staff_save')));
    await tester.pumpAndSettle();
    expect(s.staffChanges.last.$1, 4);
    expect(s.staffChanges.last.$2, {'full_name': 'Shop Staff', 'phone': '012345678', 'role': 'admin', 'password': 'newpass123'});

    await tester.tap(find.byKey(const Key('admin_staff_4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin_staff_disable')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin_staff_disable_confirm')));
    await tester.pumpAndSettle();
    expect(s.staffChanges.last.$1, 4);
    expect(s.staffChanges.last.$2, {'is_active': false});
    expect(find.byKey(const Key('admin_staff_enable')), findsOneWidget);
  });

  testWidgets('Staff: your own page has no Disable and the role is locked', (tester) async {
    final s = await _pump(tester, (s) => AdminStaffScreen(service: s));
    await tester.tap(find.byKey(const Key('admin_staff_1')));
    await tester.pumpAndSettle();
    expect(find.text("You can't change your own role."), findsOneWidget);
    expect(find.byKey(const Key('admin_staff_disable')), findsNothing);
    await tester.tap(find.byKey(const Key('admin_staff_role_staff')));
    await tester.tap(find.byKey(const Key('admin_staff_save')));
    await tester.pumpAndSettle();
    expect(s.staffChanges.last.$1, 1);
    expect(s.staffChanges.last.$2, {'full_name': 'Admin', 'phone': null});
  });
}
