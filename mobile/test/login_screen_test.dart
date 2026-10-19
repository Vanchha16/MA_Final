import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app() => ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const MaterialApp(home: LoginScreen()),
    );

/// Pumps the login screen and lets its 0.9s entrance animation finish.
Future<void> _pumpLogin(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows validation errors when fields are empty', (tester) async {
    await _pumpLogin(tester);

    await tester.ensureVisible(find.byKey(const Key('login_submit')));
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();

    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
  });

  testWidgets('rejects an invalid email', (tester) async {
    await _pumpLogin(tester);

    await tester.enterText(find.byKey(const Key('login_email')), 'not-an-email');
    await tester.enterText(find.byKey(const Key('login_password')), 'secret');
    await tester.ensureVisible(find.byKey(const Key('login_submit')));
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('password visibility toggles', (tester) async {
    await _pumpLogin(tester);

    EditableText field() => tester.widget<EditableText>(
          find.descendant(of: find.byKey(const Key('login_password')), matching: find.byType(EditableText)),
        );

    expect(field().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(field().obscureText, isFalse);
  });

  testWidgets('shows the friendly playful layout', (tester) async {
    await _pumpLogin(tester);

    expect(find.text('Hi again!'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.byIcon(Icons.waving_hand_rounded), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Just browsing'), findsOneWidget);
    expect(find.bySemanticsLabel('Login'), findsOneWidget);
  });

  testWidgets('there is no demo account shortcut', (tester) async {
    await _pumpLogin(tester);
    expect(find.text('Use demo account'), findsNothing);
  });
}
