import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/models/shop_notification.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/screens/notifications/notifications_screen.dart';
import 'package:ecommerce_app/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes/checkout_fake.dart';
import 'fakes/notifications_fake.dart';
import 'fakes/orders_fake.dart';
import 'fakes/shop_fakes.dart';

Future<(FakeNotificationService, ShopProvider)> _pump(WidgetTester tester, {FakeNotificationService? service}) async {
  tester.view.physicalSize = const Size(412, 1500) * 2; // tall, so every card is built
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final notes = service ?? FakeNotificationService();
  final shop = ShopProvider(service: FakeShopService()..unread = notes.unread)..setSignedIn(true);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: shop,
    child: MaterialApp(
      theme: AppTheme.light,
      home: NotificationsScreen(service: notes, orderService: FakeOrderService(), paymentService: FakePaymentService()),
    ),
  ));
  await tester.pumpAndSettle();
  return (notes, shop);
}

Future<void> _end(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5)); // snack bars
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('rich cards: photo, button, unread dot; offers have a coupon', (tester) async {
    await _pump(tester);
    expect(find.text('3 new'), findsOneWidget);
    expect(find.text('Your order is on the way'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('notification_action_1')), matching: find.text('Track')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('notification_action_2')), matching: find.text('View order')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('notification_action_5')), matching: find.text('Buy again')), findsOneWidget);
    expect(find.text('BIGSALE40'), findsOneWidget);
    expect(find.byKey(const Key('notification_action_4')), findsNothing); // news has no button
    await _end(tester);
  });

  testWidgets('Mark all read fades every card and clears the badge', (tester) async {
    final (notes, shop) = await _pump(tester);
    expect(shop.unreadNotifications, 3);
    await tester.tap(find.byKey(const Key('notifications_read_all')));
    await tester.pumpAndSettle();
    expect(notes.readAllCalls, 1);
    expect(find.text('All caught up'), findsOneWidget);
    expect(shop.unreadNotifications, 0);
    expect(tester.widget<AnimatedScale>(find.ancestor(of: find.byKey(const Key('notification_dot_1')), matching: find.byType(AnimatedScale))).scale, 0);
    await _end(tester);
  });

  testWidgets('Copy puts the code on the clipboard and says Copied', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await _pump(tester);
    await tester.tap(find.byKey(const Key('notification_copy_3')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(copied, 'BIGSALE40');
    expect(find.text('Copied'), findsOneWidget);
    expect(find.text('BIGSALE40 copied - use it at checkout'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400)); // the switch back to Copy
    expect(find.text('Copied'), findsNothing);
    await _end(tester);
  });

  testWidgets('swipe left deletes a message', (tester) async {
    final (notes, _) = await _pump(tester);
    await tester.drag(find.byKey(const ValueKey('notification_4')), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(notes.deleted, [4]);
    expect(find.byKey(const ValueKey('notification_4')), findsNothing);
    await _end(tester);
  });

  testWidgets('a new message drops in while the screen is open', (tester) async {
    final (notes, shop) = await _pump(tester);
    notes.items.insert(0, note(9, NotificationEvent.delivered, order: 4, minutesAgo: 0));
    await tester.pump(NotificationsScreen.checkEvery);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byKey(const ValueKey('notification_9')), findsOneWidget);
    expect(find.text('4 new'), findsOneWidget);
    expect(shop.unreadNotifications, 4);
    await _end(tester);
  });

  testWidgets('tapping an order message opens the order and marks it read', (tester) async {
    final (notes, _) = await _pump(tester);
    await tester.tap(find.byKey(const Key('notification_action_1')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Order details'), findsOneWidget);
    expect(notes.items.firstWhere((n) => n.id == 1).isRead, isTrue);
    await _end(tester);
  });

  testWidgets('empty, and an error with Try again', (tester) async {
    await _pump(tester, service: FakeNotificationService(items: []));
    expect(find.byKey(const Key('notifications_empty')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    final failing = FakeNotificationService()..fail = true;
    await _pump(tester, service: failing);
    failing.fail = false;
    await tester.tap(find.byKey(const Key('notifications_retry')));
    await tester.pumpAndSettle();
    expect(find.text('3 new'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('the bell shows the unread count', (tester) async {
    final shop = ShopProvider(service: FakeShopService()..unread = 4)..setSignedIn(true);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: shop,
      child: const MaterialApp(home: Scaffold(body: Center(child: NotificationBell()))),
    ));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('notification_badge')), matching: find.text('4')), findsOneWidget);
    shop.setUnreadNotifications(0);
    await tester.pump();
    expect(find.byKey(const Key('notification_badge')), findsNothing);
  });
}
