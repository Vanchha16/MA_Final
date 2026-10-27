import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_end_point.dart';
import '../api/api_client.dart';
import '../models/profile_summary.dart';
import '../models/user.dart';

class ProfileService {
  final _api = ApiClient.instance;

  Future<ProfileSummary> summary() async =>
      ProfileSummary.fromJson(await _api.get(ApiEndPoint.profileSummary));

  Future<User> update({required String fullName, String? phone}) async =>
      User.fromJson(await _api.put(ApiEndPoint.profile, data: {'full_name': fullName, 'phone': phone}));

  /// Other devices are signed out; this one keeps working with the new token the server returns.
  Future<void> changePassword(String current, String next) async {
    final data = await _api.put(ApiEndPoint.profilePassword, data: {'current_password': current, 'new_password': next});
    final token = data is Map ? data['token'] : null;
    if (token is String) await (await SharedPreferences.getInstance()).setString(ApiClient.tokenKey, token);
  }

  /// Uploads a photo picked with image_picker (works on web and mobile).
  Future<User> uploadAvatar(XFile file) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(await file.readAsBytes(), filename: file.name),
    });
    return User.fromJson(await _api.post(ApiEndPoint.profileAvatar, data: form));
  }
}
