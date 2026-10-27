import 'package:ecommerce_app/core/constants/shop_info.dart';
import 'package:ecommerce_app/api/api_client.dart';
import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/providers/theme_provider.dart';
import 'package:ecommerce_app/screens/settings/contact_screen.dart';
import 'package:ecommerce_app/services/contact_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/orders_fake.dart';
import 'fakes/shop_fakes.dart';

class FakeContactService extends ContactService {
  final List<(ContactTopic, String, int?)> sent = [];
  bool fail = false;

  @override
  Future<void> send({required ContactTopic topic, required String message, int? orderId}) async {
    if (fail) throw ApiException('Cannot connect to server. Check your internet connection.');
    sent.add((topic, message, orderId));
  }
}

class _Setup {
  final contact = FakeContactService();
  final orders = FakeOrderService();
  final opened = <Uri>[];
  bool canOpen = true;
}

Future<_Setup> _pump(WidgetTester tester, {bool signedIn = true, int hour = 10, bool reduceMotion = true}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(412, 1400) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final s = _Setup();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => ShopProvider(service: FakeShopService())..setSignedIn(signedIn)),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: const Size(412, 1400), disableAnimations: reduceMotion),
        child: ContactScreen(
          service: s.contact,
          orderService: s.orders,
          now: () => DateTime(2026, 10, 16, hour),
          launcher: (uri) async {
            s.opened.add(uri);
            return s.canOpen;
          },
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return s;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows Online during opening hours and Closed after', (tester) async {
    await _pump(tester, hour: 10);
    expect(find.text('Online · usually replies in 10 min'), findsOneWidget);
    await _pump(tester, hour: 21);
    expect(find.text('Closed now · we reply from 9:00'), findsOneWidget);
  });

  testWidgets('Telegram, call, email and visit open the right apps', (tester) async {
    final s = await _pump(tester);
    for (final key in ['contact_telegram', 'contact_call', 'contact_email', 'contact_visit', 'contact_shop']) {
      await _tap(tester, find.byKey(Key(key)));
    }
    expect(s.opened, [ShopInfo.telegramUri, ShopInfo.phoneUri, ShopInfo.emailUri, ShopInfo.mapsUri, ShopInfo.mapsUri]);
    expect(s.opened[0].toString(), 'https://t.me/animeworldshop_kh');
    expect(s.opened[1].toString(), 'tel:+85512345678');
  });

  testWidgets('when there is no app for it, the value is copied instead', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final s = await _pump(tester);
    s.canOpen = false;
    await _tap(tester, find.byKey(const Key('contact_call')));
    expect(copied, ShopInfo.phone);
    expect(find.text('Could not open it, so we copied ${ShopInfo.phone}.'), findsOneWidget);
  });

  testWidgets('a question about an order names the newest order and shows the thank-you', (tester) async {
    final s = await _pump(tester);
    expect(find.byKey(const Key('contact_order')), findsNothing);
    final send = find.byKey(const Key('contact_send'));
    await tester.tap(send, warnIfMissed: false); // nothing written yet
    expect(s.contact.sent, isEmpty);

    await _tap(tester, find.byKey(const Key('contact_topic_order')));
    expect(find.byKey(const Key('contact_order')), findsOneWidget);
    expect(find.text('Order ${s.orders.orders.first.number}'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('contact_message')), '  When will my Luffy figure arrive?  ');
    await tester.pump();
    await _tap(tester, send);
    expect(s.contact.sent.single, (ContactTopic.order, 'When will my Luffy figure arrive?', s.orders.orders.first.id));
    expect(find.byKey(const Key('contact_sent')), findsOneWidget);
    expect(find.textContaining('About order ${s.orders.orders.first.number}'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('contact_send_another')));
    expect(find.byKey(const Key('contact_form')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('contact_message'))).controller!.text, isEmpty);
  });

  testWidgets('a product question has no order, and a failed send keeps the message', (tester) async {
    final s = await _pump(tester);
    await _tap(tester, find.byKey(const Key('contact_topic_product')));
    expect(find.byKey(const Key('contact_order')), findsNothing);
    await tester.enterText(find.byKey(const Key('contact_message')), 'Will Gojo be restocked?');
    await tester.pump();

    s.contact.fail = true;
    await _tap(tester, find.byKey(const Key('contact_send')));
    expect(find.textContaining('Cannot connect'), findsOneWidget);
    expect(find.text('Will Gojo be restocked?'), findsOneWidget);

    s.contact.fail = false;
    await _tap(tester, find.byKey(const Key('contact_send')));
    expect(s.contact.sent.single, (ContactTopic.product, 'Will Gojo be restocked?', null));
    expect(find.text("We'll answer in Notifications, usually the same day."), findsOneWidget);
  });

  testWidgets('guests can still call or chat, but are asked to log in to send a message', (tester) async {
    await _pump(tester, signedIn: false);
    expect(find.byKey(const Key('contact_login')), findsOneWidget);
    expect(find.byKey(const Key('contact_form')), findsNothing);
    expect(find.byKey(const Key('contact_telegram')), findsOneWidget);
  });

  testWidgets('with animations on, the online dot keeps pulsing until the page closes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(412, 1400) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ShopProvider(service: FakeShopService())..setSignedIn(true))],
      child: MaterialApp(theme: AppTheme.dark, home: ContactScreen(service: FakeContactService(), now: () => DateTime(2026, 10, 16, 12))),
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('contact_form')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
