import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/user.dart';

class AuthService {
  final _api = ApiClient.instance;

  /// Returns (token, user).
  Future<(String, User)> login(String email, String password) async {
    final data = await _api.post(ApiConstants.login, data: {
      'email': email,
      'password': password,
    });
    return (data['token'] as String, User.fromJson(data['user']));
  }

  Future<(String, User)> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final data = await _api.post(ApiConstants.register, data: {
      'full_name': fullName,
      'email': email,
      'password': password,
      'phone': phone,
    });
    return (data['token'] as String, User.fromJson(data['user']));
  }

  Future<User> me() async => User.fromJson(await _api.get(ApiConstants.me));
}
