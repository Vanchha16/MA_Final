import 'package:ecommerce_app/main.dart';
import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/providers/locale_provider.dart';
import 'package:ecommerce_app/providers/theme_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Splash shows, then goes to Login when not logged in', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const ShopApp(),
    ));

    expect(find.text('Anime World Shop'), findsOneWidget);

    // Login has a looping "floating logo" animation, so pump fixed time
    // instead of pumpAndSettle (which would wait forever).
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Welcome back'), findsOneWidget);
  });
}
