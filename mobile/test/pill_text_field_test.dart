import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/widgets/pill_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({bool reduceMotion = false}) => MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Column(
            children: [
              PillTextField(
                fieldKey: const Key('email'),
                controller: TextEditingController(),
                label: 'Email',
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 16),
              PillTextField(
                fieldKey: const Key('password'),
                controller: TextEditingController(),
                label: 'Password',
                icon: Icons.lock_outline,
              ),
            ],
          ),
        ),
      ),
    );

double _fieldScale(WidgetTester tester, String key) => tester
    .widget<AnimatedScale>(find
        .ancestor(of: find.byKey(Key(key)), matching: find.byType(AnimatedScale))
        .first)
    .scale;

Color? _iconColor(WidgetTester tester, IconData icon) => tester.widget<Icon>(find.byIcon(icon)).color;

void main() {
  testWidgets('focused field lifts and its icon turns primary, then eases back', (tester) async {
    await tester.pumpWidget(_app());
    final primary = AppTheme.light.colorScheme.primary;

    expect(_fieldScale(tester, 'email'), 1);
    expect(_iconColor(tester, Icons.email_outlined), isNot(primary));

    await tester.tap(find.byKey(const Key('email')));
    await tester.pumpAndSettle();
    expect(_fieldScale(tester, 'email'), 1.015);
    expect(_iconColor(tester, Icons.email_outlined), primary);
    expect(_fieldScale(tester, 'password'), 1);

    // Moving focus to password returns email to rest
    await tester.tap(find.byKey(const Key('password')));
    await tester.pumpAndSettle();
    expect(_fieldScale(tester, 'email'), 1);
    expect(_fieldScale(tester, 'password'), 1.015);
    expect(_iconColor(tester, Icons.lock_outline), primary);
  });

  testWidgets('reduce motion: focus change applies instantly', (tester) async {
    await tester.pumpWidget(_app(reduceMotion: true));

    await tester.tap(find.byKey(const Key('email')));
    await tester.pump(); // a single frame, no animation time
    expect(_iconColor(tester, Icons.email_outlined), AppTheme.light.colorScheme.primary);
    await tester.pump(Duration.zero); // runs flutter_animate's zero-delay start timer
  });
}
