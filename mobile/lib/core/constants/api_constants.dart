import 'package:flutter/foundation.dart';

class ApiConstants {
  // Override with: flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5000/api
  // Defaults: web -> localhost, Android emulator -> 10.0.2.2 (your PC's localhost).
  // On a real phone, pass your PC's Wi-Fi IP with --dart-define, or change it in
  // the app (Server address, on Login and in Settings) - see ApiClient.setServer.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb ? 'http://localhost:5000/api' : 'http://10.0.2.2:5000/api',
  );

  /// What the user typed as the server -> the API's base URL, or null when it is
  /// not an address. "192.168.1.10" -> "http://192.168.1.10:5000/api"; a full URL
  /// ("https://shop.example.com") keeps its scheme and port and gets "/api".
  static String? serverUrl(String input) {
    final typed = input.trim();
    if (typed.isEmpty || typed.contains(' ')) return null;
    final hasScheme = typed.contains('://');
    final uri = Uri.tryParse(hasScheme ? typed : 'http://$typed');
    if (uri == null || uri.host.isEmpty || !(uri.scheme == 'http' || uri.scheme == 'https')) return null;
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : (hasScheme ? null : 5000),
      path: path.isEmpty ? '/api' : path,
    ).toString();
  }

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resetPassword = '/auth/reset-password';

  static const String profile = '/profile';
  static const String profileSummary = '/profile/summary';
  static const String profilePassword = '/profile/password';
  static const String profileAvatar = '/profile/avatar';

  static const String categories = '/categories';
  static const String series = '/series';
  static const String brands = '/brands';
  static const String searchSuggestions = '/search/suggestions';
  static const String products = '/products';
  static const String toReview = '/reviews/to-review';
  static const String wishlist = '/wishlist';
  static const String wishlistBatchRemove = '/wishlist/batch-remove';
  static const String wishlistBatchAdd = '/wishlist/batch-add';
  static const String wishlistMoveToCart = '/wishlist/move-to-cart';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orders = '/orders';
  static const String addresses = '/addresses';
  static const String notifications = '/notifications';
  static const String contact = '/contact';
  static const String admin = '/admin';
}
