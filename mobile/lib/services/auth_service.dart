import '../api/api_end_point.dart';
import '../api/api_client.dart';
import '../models/user.dart';

/// Result of asking for a password reset code.
class ResetCodeRequest {
  final int expiresIn;
  final int resendAfter;

  /// Only returned by a development server (no real email configured).
  final String? devCode;

  const ResetCodeRequest({required this.expiresIn, required this.resendAfter, this.devCode});
}

class AuthService {
  final _api = ApiClient.instance;

  /// Returns (token, user).
  Future<(String, User)> login(String email, String password) async {
    final data = await _api.post(ApiEndPoint.login, data: {
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
    final data = await _api.post(ApiEndPoint.register, data: {
      'full_name': fullName,
      'email': email,
      'password': password,
      'phone': phone,
    });
    return (data['token'] as String, User.fromJson(data['user']));
  }

  Future<User> me() async => User.fromJson(await _api.get(ApiEndPoint.me));

  /// Step 1 of "Forgot password": email a 6-digit code.
  Future<ResetCodeRequest> requestResetCode(String email) async {
    final data = await _api.post(ApiEndPoint.forgotPassword, data: {'email': email});
    return ResetCodeRequest(
      expiresIn: data['expires_in'] as int,
      resendAfter: data['resend_after'] as int,
      devCode: data['dev_code'] as String?,
    );
  }

  /// Step 2: check the code. Returns a short-lived reset token.
  Future<String> verifyResetCode(String email, String code) async {
    final data = await _api.post(ApiEndPoint.verifyOtp, data: {'email': email, 'code': code});
    return data['reset_token'] as String;
  }

  /// Step 3: set the new password.
  Future<void> resetPassword(String resetToken, String newPassword) =>
      _api.post(ApiEndPoint.resetPassword, data: {'reset_token': resetToken, 'new_password': newPassword});
}
