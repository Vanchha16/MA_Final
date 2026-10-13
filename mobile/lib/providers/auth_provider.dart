import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final _service = AuthService();

  User? _user;
  bool _loading = false;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get loading => _loading;

  /// Called from the splash screen: restores the session if a saved token is still valid.
  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(ApiClient.tokenKey) == null) return;
    try {
      _user = await _service.me();
    } on ApiException {
      await prefs.remove(ApiClient.tokenKey);
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) =>
      _authenticate(() => _service.login(email, password));

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) =>
      _authenticate(() => _service.register(
            fullName: fullName,
            email: email,
            password: password,
            phone: phone,
          ));

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiClient.tokenKey);
    _user = null;
    notifyListeners();
  }

  Future<void> _authenticate(Future<(String, User)> Function() call) async {
    _loading = true;
    notifyListeners();
    try {
      final (token, user) = await call();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiClient.tokenKey, token);
      _user = user;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
