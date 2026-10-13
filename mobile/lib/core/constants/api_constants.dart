class ApiConstants {
  // Android emulator reaches your PC's localhost through 10.0.2.2.
  // On a real phone, use your PC's Wi-Fi IP instead, e.g. http://192.168.1.10:5000/api
  static const String baseUrl = 'http://10.0.2.2:5000/api';

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
}
