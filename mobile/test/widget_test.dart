import 'package:ecommerce_app/main.dart';
import 'package:ecommerce_app/providers/auth_provider.dart';
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
      ],
      child: const ShopApp(),
    ));

    expect(find.text('Anime World Shop'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });
}
