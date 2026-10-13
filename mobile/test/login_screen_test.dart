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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows validation errors when fields are empty', (tester) async {
    await tester.pumpWidget(_app());

    await tester.ensureVisible(find.byKey(const Key('login_submit')));
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();

    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
  });

  testWidgets('rejects an invalid email', (tester) async {
    await tester.pumpWidget(_app());

    await tester.enterText(find.byKey(const Key('login_email')), 'not-an-email');
    await tester.enterText(find.byKey(const Key('login_password')), 'secret');
    await tester.ensureVisible(find.byKey(const Key('login_submit')));
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('password visibility toggles', (tester) async {
    await tester.pumpWidget(_app());

    EditableText field() => tester.widget<EditableText>(
          find.descendant(of: find.byKey(const Key('login_password')), matching: find.byType(EditableText)),
        );

    expect(field().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(field().obscureText, isFalse);
  });

  testWidgets('demo account button fills the form (debug builds)', (tester) async {
    await tester.pumpWidget(_app());

    await tester.ensureVisible(find.text('Use demo account'));
    await tester.tap(find.text('Use demo account'));
    await tester.pump();

    expect(find.text('demo@shop.com'), findsOneWidget);
  });
}
