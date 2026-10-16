import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'l10n/l10n.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'widgets/theme_reveal.dart';

void main() {
  runApp(
    // Device preview: on the web the app is shown inside a real phone frame
    // (Pixel, iPhone, Samsung...). It is turned off on real phones.
    DevicePreview(
      enabled: kIsWeb,
      defaultDevice: Devices.android.googlePixel9,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()..load()),
          // Wishlist hearts + cart badge follow the signed-in user
          ChangeNotifierProxyProvider<AuthProvider, ShopProvider>(
            create: (_) => ShopProvider(),
            update: (_, auth, shop) => shop!..setSignedIn(auth.isLoggedIn),
          ),
        ],
        child: const ShopApp(),
      ),
    ),
  );
}

class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anime World Shop',
      debugShowCheckedModeBanner: false,
      // English or Khmer, picked in Settings
      locale: context.watch<LocaleProvider>().locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // The circle wipe when the theme changes in Settings
      builder: (context, child) => DevicePreview.appBuilder(context, ThemeReveal(child: child!)),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: context.watch<ThemeProvider>().mode,
      home: const SplashScreen(),
    );
  }
}
