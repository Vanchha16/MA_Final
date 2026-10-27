import 'package:flutter/foundation.dart';

/// Where the Flask server is. Every request goes to [baseUrl] + an [ApiEndPoint] path.
class ApiDomain {
  // Override with: flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5000/api
  // Defaults: web -> localhost, Android emulator -> 10.0.2.2 (your PC's localhost).
  // On a real phone, pass your PC's Wi-Fi IP with --dart-define.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb ? 'http://localhost:5000/api' : 'http://10.0.2.2:5000/api',
  );
}
