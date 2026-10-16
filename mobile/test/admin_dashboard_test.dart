import 'package:ecommerce_app/core/network/api_client.dart';
import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/models/admin.dart';
import 'package:ecommerce_app/models/user.dart';
import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/screens/admin/admin_dashboard_screen.dart';
import 'package:ecommerce_app/screens/admin/admin_shell.dart';
import 'package:ecommerce_app/services/admin_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAdminService extends AdminService {
  AdminStats stats_ = const AdminStats(revenue: 1053, weekRevenue: 127, week: [20, 40, 0, 60, 30, 40, 70], ordersToHandle: 4, lowStock: 5, openMessages: 2);
  List<ActivityEvent> events = [
    ActivityEvent(id: 'paid-3', kind: ActivityKind.paid, at: DateTime.now().toUtc(), title: 'Payment received', message: 'Chan paid \$27.00 by KHQR',
        action: ActivityAction.ship, orderId: 3, status: 'confirmed'),
    ActivityEvent(id: 'message-1', kind: ActivityKind.message, at: DateTime.now().toUtc(), title: 'New message', message: '"Posters?"',
        action: ActivityAction.reply, messageId: 1, status: 'open'),
    ActivityEvent(id: 'order-1', kind: ActivityKind.order, at: DateTime.now().toUtc(), title: 'New order AWS-1', message: 'Demo · \$87.00 · cash',
        action: ActivityAction.confirm, orderId: 1, status: 'pending'),
    ActivityEvent(id: 'stock-7', kind: ActivityKind.soldOut, at: DateTime.now().toUtc(), title: 'Sold out', message: 'Makima has 0 left',
        action: ActivityAction.restock, productId: 7),
    ActivityEvent(id: 'order-9', kind: ActivityKind.order, at: DateTime.now().toUtc(), title: 'New order AWS-9', message: 'Demo · \$12.00 · KHQR', status: 'delivered'),
  ];
  bool fail = false;
  final statuses = <(int, String)>[];
  final replies = <(int, String)>[];
  final stock = <(int, int)>[];
  int loads = 0;

  @override
  Future<AdminStats> stats() async {
    loads++;
    if (fail) throw ApiException('Cannot connect to server. Check your internet connection.');
    return stats_;
  }

  @override
  Future<List<ActivityEvent>> activity({int limit = 20}) async {
    if (fail) throw ApiException('Cannot connect to server. Check your internet connection.');
    return [...events];
  }

  @override
  Future<void> setOrderStatus(int orderId, String status) async => statuses.add((orderId, status));

  @override
  Future<void> reply(int messageId, String text) async => replies.add((messageId, text));

  @override
  Future<void> setStock(int productId, int stock) async => this.stock.add((productId, stock));
}

Future<FakeAdminService> _pump(WidgetTester tester, {FakeAdminService? service, bool shell = false, int hour = 14}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(412, 1500) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final s = service ?? FakeAdminService();
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => AuthProvider()..updateUser(User(id: 1, fullName: 'Lynn Admin', email: 'admin@shop.com', role: 'admin')),
    child: MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: const MediaQueryData(size: Size(412, 1500), disableAnimations: true),
        child: shell
            ? AdminShell(service: s)
            : Scaffold(body: AdminDashboardScreen(service: s, onShop: () {}, now: () => DateTime(2026, 10, 16, hour))),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return s;
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('shows the greeting, revenue, counts and live activity', (tester) async {
    await _pump(tester);
    expect(find.text('Good afternoon, Lynn'), findsOneWidget);
    expect(find.text('\$1,053.00'), findsOneWidget);
    expect(find.text('+ \$127.00 this week'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Payment received'), findsOneWidget);
    expect(find.text('On the way'), findsNothing);
    expect(find.text('Delivered'), findsOneWidget); // handled orders show their status, no button
    await _end(tester);
  });

  testWidgets('the greeting follows the time of day', (tester) async {
    await _pump(tester, hour: 8);
    expect(find.text('Good morning, Lynn'), findsOneWidget);
    await _end(tester);
    await _pump(tester, hour: 20);
    expect(find.text('Good evening, Lynn'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('Ship it and Confirm move the order and say the customer was told', (tester) async {
    final s = await _pump(tester);
    await tester.tap(find.byKey(const Key('admin_action_paid-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin_action_order-1')));
    await tester.pumpAndSettle();
    expect(s.statuses, [(3, 'shipped'), (1, 'confirmed')]);
    expect(find.text('Shipped · customer told'), findsOneWidget);
    expect(find.text('Confirmed · customer told'), findsOneWidget);
    expect(s.loads, 3); // refreshed after each action
    await _end(tester);
  });

  testWidgets('Reply sends the answer and Restock saves the stock', (tester) async {
    final s = await _pump(tester);
    await tester.tap(find.byKey(const Key('admin_action_message-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('admin_reply_text')), 'Next month!');
    await tester.pump();
    await tester.tap(find.byKey(const Key('admin_reply_send')));
    await tester.pumpAndSettle();
    expect(s.replies, [(1, 'Next month!')]);
    expect(find.text('Replied'), findsOneWidget);

    await tester.tap(find.byKey(const Key('admin_action_stock-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin_stock_plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('admin_stock_save')));
    await tester.pumpAndSettle();
    expect(s.stock, [(7, 11)]);
    expect(find.text('11 in stock'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('new events show up on the next check', (tester) async {
    final s = await _pump(tester);
    s.events.insert(0, ActivityEvent(id: 'paid-8', kind: ActivityKind.paid, at: DateTime.now().toUtc(), title: 'Payment received',
        message: 'Sok paid \$13.00 by KHQR', action: ActivityAction.ship, orderId: 8, status: 'confirmed'));
    await tester.pump(AdminDashboardScreen.checkEvery);
    await tester.pumpAndSettle();
    expect(find.text('Sok paid \$13.00 by KHQR'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('a failed load shows the error and Try again', (tester) async {
    final s = await _pump(tester, service: FakeAdminService()..fail = true);
    expect(find.textContaining('Cannot connect'), findsOneWidget);
    s.fail = false;
    await tester.tap(find.byKey(const Key('admin_retry')));
    await tester.pumpAndSettle();
    expect(find.text('\$1,053.00'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('the admin bar shows the to-handle and message badges; counts open their tab', (tester) async {
    await _pump(tester, shell: true);
    expect(find.descendant(of: find.byKey(const Key('admin_tab_orders')), matching: find.text('4')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('admin_tab_more')), matching: find.text('2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin_count_low_stock')));
    await tester.pumpAndSettle();
    expect(find.text('This part of the admin comes next.'), findsOneWidget);
    await _end(tester);
  });
}
