import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/screens/auth/forgot_password_screen.dart';
import 'package:ecommerce_app/screens/auth/login_screen.dart';
import 'package:ecommerce_app/screens/auth/reset_password_screen.dart';
import 'package:ecommerce_app/screens/auth/reset_success_screen.dart';
import 'package:ecommerce_app/screens/auth/verify_code_screen.dart';
import 'package:ecommerce_app/services/auth_service.dart';
import 'package:ecommerce_app/widgets/otp_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home) => ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(home: home),
    );

Future<void> _pump(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(_app(home));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pump();
  await tester.tap(find.byKey(key));
  await tester.pump();
}

const _request = ResetCodeRequest(expiresIn: 600, resendAfter: 60);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('OtpInput', () {
    testWidgets('shows typed digits, ignores letters, completes at 6', (tester) async {
      final controller = TextEditingController();
      String? completed;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: OtpInput(controller: controller, onCompleted: (v) => completed = v, fieldKey: const Key('otp'))),
      ));

      await tester.enterText(find.byKey(const Key('otp')), '4a8');
      await tester.pump();
      expect(controller.text, '48');
      expect(find.text('4'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(completed, isNull);

      // Pasting a whole code (with spaces) fills every box and completes
      await tester.enterText(find.byKey(const Key('otp')), '12 34 56');
      await tester.pump();
      expect(controller.text, '123456');
      expect(completed, '123456');
    });
  });

  testWidgets('Login "Forgot password?" opens step 1 with the typed email', (tester) async {
    await _pump(tester, const LoginScreen());
    await tester.enterText(find.byKey(const Key('login_email')), 'dara@example.com');
    await _tap(tester, const Key('login_to_forgot'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Forgot password?'), findsWidgets);
    expect(find.byIcon(Icons.lock_reset_rounded), findsOneWidget);
    expect(find.text('dara@example.com'), findsOneWidget);
  });

  testWidgets('step 1 validates the email', (tester) async {
    await _pump(tester, const ForgotPasswordScreen());
    await _tap(tester, const Key('forgot_submit'));
    expect(find.text('Please enter your email'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('forgot_email')), 'nope');
    await _tap(tester, const Key('forgot_submit'));
    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('step 2 shows the email, a countdown, then a resend button', (tester) async {
    await _pump(tester, const VerifyCodeScreen(email: 'demo@shop.com', request: _request));

    expect(find.textContaining('demo@shop.com', findRichText: true), findsOneWidget);
    expect(find.text('Resend code in 00:59'), findsOneWidget); // 1s already passed
    expect(find.byKey(const Key('resend_code')), findsNothing);

    // Verify stays disabled until 6 digits are entered
    final verify = find.byKey(const Key('verify_submit'));
    await tester.tap(verify);
    await tester.pump();
    expect(find.byType(ResetPasswordScreen), findsNothing);

    await tester.pump(const Duration(seconds: 60));
    expect(find.byKey(const Key('resend_code')), findsOneWidget);
    expect(find.textContaining('Resend code in'), findsNothing);
  });

  testWidgets('step 3 validates the new password', (tester) async {
    await _pump(tester, const ResetPasswordScreen(resetToken: 't'));
    await _tap(tester, const Key('reset_submit'));
    expect(find.text('Please enter a new password'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('reset_password')), 'abc');
    await tester.enterText(find.byKey(const Key('reset_confirm')), 'xyz');
    await _tap(tester, const Key('reset_submit'));
    expect(find.text('Use at least 6 characters'), findsOneWidget);
    expect(find.text("Passwords don't match"), findsOneWidget);

    await tester.enterText(find.byKey(const Key('reset_password')), 'Abcdef12!long');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Strong password'), findsOneWidget);
  });

  testWidgets('success screen returns to the first screen', (tester) async {
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ResetSuccessScreen())),
            child: const Text('Start'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Password updated!'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await _tap(tester, const Key('back_to_login'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Password updated!'), findsNothing);
  });
}
