import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/widgets/otp_input.dart';
import 'package:ecommerce_app/widgets/pill_text_field.dart';
import 'package:ecommerce_app/widgets/shake.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _formKey = GlobalKey<FormState>();

Widget _form({String? errorText, bool reduceMotion = false}) => MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Form(
            key: _formKey,
            child: Column(
              children: [
                PillTextField(
                  fieldKey: const Key('email'),
                  controller: TextEditingController(),
                  label: 'Email',
                  icon: Icons.email_outlined,
                  errorText: errorText,
                  validator: (v) => (v ?? '').isEmpty ? 'Email is required' : null,
                ),
                PillTextField(
                  fieldKey: const Key('note'),
                  controller: TextEditingController(text: 'ok'),
                  label: 'Note',
                  icon: Icons.notes,
                  validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );

/// Horizontal offset of the Shake around the field with [key].
double _dx(WidgetTester tester, String key) {
  final t = tester.widget<Transform>(find
      .descendant(
        of: find.ancestor(of: find.byKey(Key(key)), matching: find.byType(Shake)),
        matching: find.byType(Transform),
      )
      .first);
  return t.transform.getTranslation().x;
}

/// The shake is scheduled after the current frame and its ticker starts on
/// the one after; 40 ms later the first swing is near its widest point.
Future<void> _midShake(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
}

void main() {
  testWidgets('empty required field shakes on submit, valid field stays still', (tester) async {
    await tester.pumpWidget(_form());
    expect(_formKey.currentState!.validate(), isFalse);
    await _midShake(tester);

    expect(find.text('Email is required'), findsOneWidget);
    expect(_dx(tester, 'email').abs(), greaterThan(1));
    expect(_dx(tester, 'note'), 0);

    await tester.pumpAndSettle();
    expect(_dx(tester, 'email'), closeTo(0, 0.001)); // back in place
  });

  testWidgets('a server error appearing shakes the field', (tester) async {
    await tester.pumpWidget(_form());
    await tester.pumpWidget(_form(errorText: 'Email already registered'));
    await _midShake(tester);
    expect(_dx(tester, 'email').abs(), greaterThan(1));
    await tester.pumpAndSettle();
  });

  testWidgets('reduce motion: error shows without shaking', (tester) async {
    await tester.pumpWidget(_form(reduceMotion: true));
    _formKey.currentState!.validate();
    await _midShake(tester);
    expect(find.text('Email is required'), findsOneWidget);
    expect(_dx(tester, 'email'), 0);
  });

  testWidgets('OTP boxes shake when an error appears', (tester) async {
    final controller = TextEditingController();
    Widget otp(bool error) => MaterialApp(
          home: Scaffold(body: OtpInput(fieldKey: const Key('otp'), controller: controller, hasError: error, autofocus: false)),
        );
    await tester.pumpWidget(otp(false));
    await tester.pumpWidget(otp(true));
    await _midShake(tester);
    expect(_dx(tester, 'otp').abs(), greaterThan(1));
    await tester.pumpAndSettle();
  });
}
