import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF0EA5E9); // sky blue (theme seed)
  static const Color primaryDark = Color(0xFF0284C7); // darker sky - use behind white text
  static const Color accent = Color(0xFF06B6D4); // aqua
  static const Color coral = Color(0xFFF43F5E); // sale badges, wishlist heart, sold out
  static const Color amber = Color(0xFFF59E0B); // friendly accents (waving hand), warnings

  static ThemeData light = _build(Brightness.light);
  static ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    // fromSeed alone turns #0EA5E9 into a muted steel blue (#256489), so pin the
    // brand blue: darker sky in light mode (white text stays readable), light sky in dark mode.
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(
      primary: dark ? const Color(0xFF38BDF8) : primaryDark,
      onPrimary: dark ? const Color(0xFF082F49) : Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
    );
    final radius = BorderRadius.circular(12);
    const buttonSize = Size.fromHeight(52);
    final buttonShape = RoundedRectangleBorder(borderRadius: radius);
    const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(centerTitle: true),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonText,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}
