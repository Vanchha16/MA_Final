import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/screens/auth/login_screen.dart';
import 'package:ecommerce_app/screens/auth/register_screen.dart';
import 'package:ecommerce_app/widgets/password_strength_meter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home) => ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(home: home),
    );

/// Pumps a screen and lets its entrance animation finish (the backdrop/mascot
/// loop forever, so pumpAndSettle can't be used).
Future<void> _pump(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(_app(home));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('register_submit')));
  await tester.tap(find.byKey(const Key('register_submit')));
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('passwordStrength', () {
    test('scores passwords from weak to strong', () {
      expect(passwordStrength(''), 0);
      expect(passwordStrength('abc'), 1);
      expect(passwordStrength('abcdef'), 1);
      expect(passwordStrength('abcdef12'), 2);
      expect(passwordStrength('Abcdef12'), 3);
      expect(passwordStrength('Abcdef12!long'), 4);
    });
  });

  testWidgets('shows friendly header and all fields', (tester) async {
    await _pump(tester, const RegisterScreen());

    expect(find.text('Nice to meet you!'), findsOneWidget);
    expect(find.byIcon(Icons.celebration_rounded), findsOneWidget);
    expect(find.text('Create account'), findsWidgets); // title + button
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    for (final label in ['Full name', 'Email', 'Phone (optional)', 'Password', 'Confirm password']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('empty form shows required errors and terms error', (tester) async {
    await _pump(tester, const RegisterScreen());
    await _tapSubmit(tester);

    expect(find.text('Please enter your name'), findsOneWidget);
    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please create a password'), findsOneWidget);
    expect(find.text('Please confirm your password'), findsOneWidget);
    expect(find.text('Please accept the Terms to continue'), findsOneWidget);
    // Phone is optional
    expect(find.textContaining('Enter a valid phone'), findsNothing);
  });

  testWidgets('validates phone, short password and mismatch', (tester) async {
    await _pump(tester, const RegisterScreen());

    await tester.enterText(find.byKey(const Key('register_name')), 'Dara');
    await tester.enterText(find.byKey(const Key('register_email')), 'dara@example.com');
    await tester.enterText(find.byKey(const Key('register_phone')), '123');
    await tester.enterText(find.byKey(const Key('register_password')), 'abc');
    await tester.enterText(find.byKey(const Key('register_confirm')), 'abd');
    await _tapSubmit(tester);

    expect(find.text('Enter a valid phone, e.g. 012 345 678'), findsOneWidget);
    expect(find.text('Use at least 6 characters'), findsOneWidget);
    expect(find.text("Passwords don't match"), findsOneWidget);
  });

  testWidgets('accepts Cambodian phone formats', (tester) async {
    await _pump(tester, const RegisterScreen());

    for (final phone in ['012 345 678', '+855 12 345 678', '096-123-4567']) {
      await tester.enterText(find.byKey(const Key('register_phone')), phone);
      await _tapSubmit(tester);
      expect(find.textContaining('Enter a valid phone'), findsNothing, reason: phone);
    }
  });

  testWidgets('strength meter appears and updates while typing', (tester) async {
    await _pump(tester, const RegisterScreen());
    // Meter is hidden while the password is empty
    for (final label in ['Weak password', 'Fair password', 'Good password', 'Strong password']) {
      expect(find.text(label), findsNothing);
    }

    await tester.enterText(find.byKey(const Key('register_password')), 'abcdef');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Weak password'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('register_password')), 'Abcdef12!long');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Strong password'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
  });

  testWidgets('checking terms clears the terms error', (tester) async {
    await _pump(tester, const RegisterScreen());
    await _tapSubmit(tester);
    expect(find.text('Please accept the Terms to continue'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('register_terms')));
    await tester.tap(find.byKey(const Key('register_terms')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Please accept the Terms to continue'), findsNothing);
  });

  testWidgets('login "Create an account" opens Register, and Login goes back', (tester) async {
    await _pump(tester, const LoginScreen());

    await tester.ensureVisible(find.byKey(const Key('login_to_register')));
    await tester.tap(find.byKey(const Key('login_to_register')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.celebration_rounded), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('register_to_login')));
    await tester.tap(find.byKey(const Key('register_to_login')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.byIcon(Icons.celebration_rounded), findsNothing);
  });
}
