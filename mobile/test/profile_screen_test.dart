import 'dart:async';

import 'package:ecommerce_app/api/api_client.dart';
import 'package:ecommerce_app/models/profile_summary.dart';
import 'package:ecommerce_app/models/user.dart';
import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/providers/locale_provider.dart';
import 'package:ecommerce_app/providers/shop_provider.dart';
import 'package:ecommerce_app/providers/theme_provider.dart';
import 'package:ecommerce_app/screens/profile/change_password_screen.dart';
import 'package:ecommerce_app/screens/profile/edit_profile_screen.dart';
import 'package:ecommerce_app/screens/profile/profile_screen.dart';
import 'package:ecommerce_app/screens/shell/main_shell.dart';
import 'package:ecommerce_app/services/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/shop_fakes.dart';

final demo = User(id: 2, fullName: 'Demo Customer', email: 'demo@shop.com', phone: '012345678');

ProfileSummary summaryFor(User u) => ProfileSummary(
      user: u,
      orders: 3,
      wishlist: 6,
      reviews: 2,
      toPay: 0,
      toShip: 1,
      toReceive: 2,
      toReview: 0,
      points: 1250,
      tier: const Tier(name: 'Silver', nextName: 'Gold', pointsToNext: 750, progress: 0.5),
    );

class FakeProfileService extends ProfileService {
  String? updatedName;
  String? updatedPhone;
  String? changedFrom;

  @override
  Future<ProfileSummary> summary() async => summaryFor(demo);

  @override
  Future<User> update({required String fullName, String? phone}) async {
    updatedName = fullName;
    updatedPhone = phone;
    return User(id: demo.id, fullName: fullName, email: demo.email, phone: phone);
  }

  @override
  Future<void> changePassword(String current, String next) async {
    if (current != 'demo123') {
      throw ApiException('Validation failed', errors: {'current_password': 'Current password is incorrect'});
    }
    changedFrom = current;
  }
}

/// Summary only arrives when [release] completes, to see the loading state.
class SlowProfileService extends FakeProfileService {
  final release = Completer<void>();

  @override
  Future<ProfileSummary> summary() async {
    await release.future;
    return super.summary();
  }
}

Future<AuthProvider> _pump(WidgetTester tester, Widget home, {bool signedIn = true}) async {
  SharedPreferences.setMockInitialValues({});
  final auth = AuthProvider();
  if (signedIn) auth.updateUser(demo);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ChangeNotifierProvider(create: (_) => ShopProvider(service: FakeShopService())),
    ],
    child: MaterialApp(home: home),
  ));
  await tester.pump(const Duration(seconds: 1));
  return auth;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  // Lists build lazily: scroll until an off-screen widget exists
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('signed-in profile shows collector card, order statuses and menu', (tester) async {
    await _pump(tester, ProfileScreen(service: FakeProfileService()));

    expect(find.text('Demo Customer'), findsOneWidget);
    expect(find.text('Silver Collector'), findsOneWidget);
    expect(find.text('1,250'), findsOneWidget);
    expect(find.text('750 pts to Gold'), findsOneWidget);
    for (final label in ['To Pay', 'To Ship', 'To Receive', 'To Review', 'My Wishlist', 'Addresses', 'Help & contact', 'About App']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // Badges only where there is something to do
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('DC'), findsOneWidget); // initials avatar
  });

  testWidgets('shows a shimmer skeleton until the summary loads', (tester) async {
    final service = SlowProfileService();
    await _pump(tester, ProfileScreen(service: service));
    expect(find.byKey(const Key('collector_skeleton')), findsOneWidget);
    expect(find.text('Silver Collector'), findsNothing);

    service.release.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('collector_skeleton')), findsNothing);
    expect(find.text('Silver Collector'), findsOneWidget);
  });

  testWidgets('log out asks first, Cancel keeps you signed in, confirm logs out', (tester) async {
    final auth = await _pump(tester, ProfileScreen(service: FakeProfileService()));

    await _tap(tester, find.byKey(const Key('profile_logout')));
    expect(find.text('Log out?'), findsOneWidget);
    await _tap(tester, find.text('Cancel'));
    expect(find.text('Log out?'), findsNothing);
    expect(auth.isLoggedIn, isTrue);

    await _tap(tester, find.byKey(const Key('profile_logout')));
    await _tap(tester, find.byKey(const Key('logout_confirm')));
    await tester.pump(const Duration(seconds: 1));
    expect(auth.isLoggedIn, isFalse);
    expect(find.textContaining('Welcome back'), findsOneWidget); // login screen
  });

  testWidgets('guests see the join card with Login and Sign up', (tester) async {
    await _pump(tester, const ProfileScreen(), signedIn: false);

    expect(find.text('Join the collectors club'), findsOneWidget);
    expect(find.byKey(const Key('guest_login')), findsOneWidget);
    expect(find.byKey(const Key('guest_signup')), findsOneWidget);
    expect(find.byKey(const Key('profile_logout')), findsNothing);
  });

  testWidgets('the gear opens Settings, where Dark switches the theme', (tester) async {
    await _pump(tester, ProfileScreen(service: FakeProfileService()));
    await _tap(tester, find.byTooltip('Settings'));
    expect(find.text('APPEARANCE'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('theme_dark')));
    final theme = Provider.of<ThemeProvider>(tester.element(find.byKey(const Key('theme_dark'))), listen: false);
    expect(theme.mode, ThemeMode.dark);
  });

  testWidgets('edit profile validates and saves normalized phone', (tester) async {
    final service = FakeProfileService();
    final auth = await _pump(tester, EditProfileScreen(service: service));

    await tester.enterText(find.byKey(const Key('edit_name')), 'D');
    await tester.enterText(find.byKey(const Key('edit_phone')), '123');
    await _tap(tester, find.byKey(const Key('edit_save')));
    expect(find.text('Name is too short'), findsOneWidget);
    expect(find.text('Enter a valid phone, e.g. 012 345 678'), findsOneWidget);
    expect(service.updatedName, isNull);

    await tester.enterText(find.byKey(const Key('edit_name')), 'Dara Sok');
    await tester.enterText(find.byKey(const Key('edit_phone')), '096 123 4567');
    await _tap(tester, find.byKey(const Key('edit_save')));
    expect(service.updatedName, 'Dara Sok');
    expect(service.updatedPhone, '0961234567');
    expect(auth.user!.fullName, 'Dara Sok');
  });

  testWidgets('change password shows server error and validates confirm', (tester) async {
    final service = FakeProfileService();
    await _pump(tester, ChangePasswordScreen(service: service));

    await tester.enterText(find.byKey(const Key('cp_current')), 'wrong1');
    await tester.enterText(find.byKey(const Key('cp_new')), 'newpass1');
    await tester.enterText(find.byKey(const Key('cp_confirm')), 'newpass2');
    await _tap(tester, find.byKey(const Key('cp_submit')));
    expect(find.text("Passwords don't match"), findsOneWidget);

    await tester.enterText(find.byKey(const Key('cp_confirm')), 'newpass1');
    await _tap(tester, find.byKey(const Key('cp_submit')));
    expect(find.text('Current password is incorrect'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('cp_current')), 'demo123');
    await _tap(tester, find.byKey(const Key('cp_submit')));
    expect(service.changedFrom, 'demo123');
  });

  testWidgets('bottom navigation switches tabs', (tester) async {
    await _pump(tester, MainShell(catalogService: FakeCatalogService()), signedIn: false);
    expect(find.text('Hi there, welcome'), findsOneWidget);

    await tester.tap(find.text('Cart'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Log in to see your cart'), findsOneWidget); // signed out

    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Join the collectors club'), findsOneWidget);
  });
}
