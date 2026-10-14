import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/profile_summary.dart';
import '../models/user.dart';

class ProfileService {
  final _api = ApiClient.instance;

  Future<ProfileSummary> summary() async =>
      ProfileSummary.fromJson(await _api.get(ApiConstants.profileSummary));

  Future<User> update({required String fullName, String? phone}) async =>
      User.fromJson(await _api.put(ApiConstants.profile, data: {'full_name': fullName, 'phone': phone}));

  Future<void> changePassword(String current, String next) =>
      _api.put(ApiConstants.profilePassword, data: {'current_password': current, 'new_password': next});

  /// Uploads a photo picked with image_picker (works on web and mobile).
  Future<User> uploadAvatar(XFile file) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(await file.readAsBytes(), filename: file.name),
    });
    return User.fromJson(await _api.post(ApiConstants.profileAvatar, data: form));
  }
}
