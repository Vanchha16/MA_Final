import 'package:flutter/foundation.dart';

class ApiConstants {
  // Override with: flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5000/api
  // Defaults: web -> localhost, Android emulator -> 10.0.2.2 (your PC's localhost).
  // On a real phone, pass your PC's Wi-Fi IP with --dart-define.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb ? 'http://localhost:5000/api' : 'http://10.0.2.2:5000/api',
  );

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resetPassword = '/auth/reset-password';
}
