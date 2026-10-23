import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';

/// Thrown for any failed API call. [errors] holds per-field validation messages.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  ApiException(this.message, {this.statusCode, this.errors});

  @override
  String toString() => message;
}

/// Single Dio instance shared by all services. Attaches the JWT automatically
/// and unwraps the backend's {success, message, data} envelope.
class ApiClient {
  static const tokenKey = 'auth_token';

  ApiClient._() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(tokenKey);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
    ));
  }

  static final ApiClient instance = ApiClient._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Accept': 'application/json'},
  ));

  static const serverKey = 'server_url';

  /// The server the app talks to: the one saved in Server address, else the build's default.
  String get baseUrl => _dio.options.baseUrl;

  bool get usesDefaultServer => baseUrl == ApiConstants.baseUrl;

  /// Called once at start-up, before the first request.
  Future<void> loadServer() async {
    final saved = (await SharedPreferences.getInstance()).getString(serverKey);
    if (saved != null) _dio.options.baseUrl = saved;
  }

  /// Saves [url] (from [ApiConstants.serverUrl]); null goes back to the default.
  Future<void> setServer(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url == ApiConstants.baseUrl) {
      await prefs.remove(serverKey);
    } else {
      await prefs.setString(serverKey, url);
    }
    _dio.options.baseUrl = url ?? ApiConstants.baseUrl;
  }

  /// True when the backend at [url] answers its health check.
  static Future<bool> ping(String url) async {
    try {
      final res = await Dio(BaseOptions(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)))
          .get('$url/health');
      return res.data is Map && res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? data}) =>
      _send(() => _dio.post(path, data: data));

  Future<dynamic> put(String path, {Object? data}) =>
      _send(() => _dio.put(path, data: data));

  Future<dynamic> delete(String path) => _send(() => _dio.delete(path));

  Future<dynamic> _send(Future<Response> Function() request) async {
    try {
      final res = await request();
      return res.data['data'];
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map<String, dynamic>) {
        throw ApiException(
          body['message'] ?? 'Request failed',
          statusCode: e.response?.statusCode,
          errors: body['errors'] as Map<String, dynamic>?,
        );
      }
      throw ApiException('Cannot connect to server. Check your internet connection.');
    }
  }
}
