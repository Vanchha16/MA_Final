import 'package:ecommerce_app/core/network/api_client.dart';
import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/l10n/l10n.dart';
import 'package:ecommerce_app/models/user.dart';
import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/providers/locale_provider.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/providers/theme_provider.dart';
import 'package:ecommerce_app/screens/settings/contact_screen.dart';
import 'package:ecommerce_app/screens/settings/settings_screen.dart';
import 'package:ecommerce_app/services/preferences_service.dart';
import 'package:ecommerce_app/widgets/theme_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/checkout_fake.dart';
import 'fakes/shop_fakes.dart';

class FakePreferencesService extends PreferencesService {
  NotifyPrefs prefs = const NotifyPrefs(news: false);
  bool fail = false;
  final List<NotifyPrefs> saved = [];

  @override
  Future<NotifyPrefs> get() async => prefs;

  @override
  Future<NotifyPrefs> save(NotifyPrefs next) async {
    if (fail) throw ApiException('Cannot connect to server. Check your internet connection.');
    saved.add(next);
    return prefs = next;
  }
}

Future<(FakePreferencesService, LocaleProvider, ThemeProvider)> _pump(WidgetTester tester, {bool signedIn = true, FakePreferencesService? prefs}) async {
  SharedPreferences.setMockInitialValues({});
  PackageInfo.setMockInitialValues(appName: 'Anime World Shop', packageName: 'com.setec.ecommerce_app', version: '1.0.0', buildNumber: '1', buildSignature: '');
  tester.view.physicalSize = const Size(412, 1400) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final service = prefs ?? FakePreferencesService();
  final locale = LocaleProvider();
  final theme = ThemeProvider();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()..updateUser(User(id: 2, fullName: 'Demo Customer', email: 'demo@shop.com'))),
      ChangeNotifierProvider.value(value: locale),
      ChangeNotifierProvider.value(value: theme),
      ChangeNotifierProvider(create: (_) => ShopProvider(service: FakeShopService())..setSignedIn(signedIn)),
    ],
    child: Builder(
      builder: (context) => MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: context.watch<ThemeProvider>().mode,
        locale: context.watch<LocaleProvider>().locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SettingsScreen(
          preferences: service,
          addresses: FakeCheckoutService(addresses: [FakeCheckoutService.work, FakeCheckoutService.home]),
          catalog: FakeCatalogService(),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return (service, locale, theme);
}

void main() {
  testWidgets('the switches show the saved choices and save changes', (tester) async {
    final (prefs, _, _) = await _pump(tester);
    expect(tester.widget<Switch>(find.byKey(const Key('notify_orders'))).value, isTrue);
    expect(tester.widget<Switch>(find.byKey(const Key('notify_news'))).value, isFalse);
    expect(find.text('2 saved'), findsOneWidget); // addresses
    expect(find.text('Version 1.0.0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notify_news')));
    await tester.pumpAndSettle();
    expect(prefs.saved.single.news, isTrue);
    expect(tester.widget<Switch>(find.byKey(const Key('notify_news'))).value, isTrue);

    prefs.fail = true;
    await tester.tap(find.byKey(const Key('notify_offers')));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byKey(const Key('notify_offers'))).value, isTrue); // back, it failed
    expect(find.textContaining('Cannot connect'), findsOneWidget);
  });

  testWidgets('Khmer changes the words and is remembered; Dark changes the theme', (tester) async {
    final (_, locale, theme) = await _pump(tester);
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.byKey(const Key('language_km')));
    await tester.pumpAndSettle();
    expect(locale.isKhmer, isTrue);
    expect(find.text('ការកំណត់'), findsOneWidget);
    expect(find.text('ជូនដំណឹងខ្ញុំអំពី'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('locale'), 'km');

    await tester.tap(find.byKey(const Key('theme_dark')));
    await tester.pumpAndSettle();
    expect(theme.mode, ThemeMode.dark);
  });

  testWidgets('guests see a log in row instead of the switches and no addresses', (tester) async {
    await _pump(tester, signedIn: false);
    expect(find.byKey(const Key('settings_notify_login')), findsOneWidget);
    expect(find.byKey(const Key('notify_orders')), findsNothing);
    expect(find.byKey(const Key('settings_addresses')), findsNothing);
    expect(find.byKey(const Key('settings_help')), findsOneWidget);
  });

  testWidgets('My addresses lists the default first and can add one', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('settings_addresses')));
    await tester.pumpAndSettle();
    expect(find.text('My addresses'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    final home = tester.getTopLeft(find.byKey(const Key('address_row_1'))).dy;
    final work = tester.getTopLeft(find.byKey(const Key('address_row_2'))).dy;
    expect(home, lessThan(work));

    await tester.tap(find.byKey(const Key('addresses_add')));
    await tester.pumpAndSettle();
    expect(find.text('New address'), findsOneWidget);
  });

  testWidgets('Help opens Contact us and the questions; About shows the credit', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('settings_help')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('faq_0')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Delivery is free from \$50'), findsOneWidget);
    await tester.tap(find.byKey(const Key('help_contact')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ContactScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_about')));
    await tester.pump(const Duration(milliseconds: 400)); // the page slides in
    await tester.pump(const Duration(seconds: 3)); // About's photo columns never stop drifting
    await tester.pump(const Duration(seconds: 3)); // the category chips pop in after they load
    expect(find.byKey(const Key('about_credit')), findsOneWidget);
    expect(find.byKey(const Key('about_version')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('the circle wipe changes the theme and then goes away', (tester) async {
    var dark = false;
    final key = GlobalKey<ThemeRevealState>();
    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setState) => MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => ThemeReveal(key: key, child: child!),
        home: Scaffold(body: Center(child: TextButton(onPressed: () {}, child: const Text('Hi')))),
      ),
    ));
    await tester.runAsync(() async {
      // toImage needs real time; the change runs once the picture is taken
      final run = key.currentState!.run(const Offset(100, 100), () => dark = true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      unawaited(run);
    });
    expect(dark, isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(RawImage), findsOneWidget); // the old screen on top, with a growing hole
    await tester.pump(ThemeReveal.duration);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.byType(RawImage), findsNothing); // and then it is gone
  });
}

void unawaited(Future<void> _) {}
