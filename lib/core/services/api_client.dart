import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

/// Singleton Dio client pre-configured with:
///   • baseUrl from AppConfig
///   • AuthInterceptor — attaches Bearer token and auto-refreshes on 401
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _storage = FlutterSecureStorage();
  late final Dio dio = _buildDio();

  Dio _buildDio() {
    final d = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60), // longer for audio uploads
        contentType: 'application/json',
      ),
    );
    d.interceptors.add(_AuthInterceptor(d, _storage));
    return d;
  }

  // ── Convenience wrappers ──────────────────────────────────────────────────

  Future<dynamic> get(String path, {Map<String, dynamic>? params}) =>
      dio.get(path, queryParameters: params).then((r) => r.data);

  Future<dynamic> post(String path, {dynamic data}) =>
      dio.post(path, data: data).then((r) => r.data);

  Future<dynamic> patch(String path, {dynamic data}) =>
      dio.patch(path, data: data).then((r) => r.data);

  Future<dynamic> postMultipart(String path, FormData formData,
      {void Function(int, int)? onSendProgress}) =>
      dio
          .post(path,
              data: formData,
              onSendProgress: onSendProgress,
              options: Options(contentType: 'multipart/form-data'))
          .then((r) => r.data);

  // ── Token helpers ─────────────────────────────────────────────────────────

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  static Future<void> clearTokens() async {
    await _storage.deleteAll();
  }

  static Future<String?> getAccessToken() =>
      _storage.read(key: 'access_token');

  static Future<String?> getRefreshToken() =>
      _storage.read(key: 'refresh_token');
}

// ─────────────────────────────────────────────────────────────────────────────
// Auth Interceptor
// ─────────────────────────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  bool _isRefreshing = false;

  _AuthInterceptor(this._dio, this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only attempt refresh on 401s from non-auth endpoints, once
    if (err.response?.statusCode == 401 &&
        !_isRefreshing &&
        !(err.requestOptions.path.contains('/auth/'))) {
      _isRefreshing = true;
      try {
        final refreshToken = await _storage.read(key: 'refresh_token');
        if (refreshToken == null) {
          _isRefreshing = false;
          return handler.next(err);
        }

        // Hit the refresh endpoint directly (bypass interceptor)
        final refreshDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
        final resp = await refreshDio.post(
          '/auth/refresh',
          data: {'refresh_token': refreshToken},
        );
        final newToken = resp.data['access_token'] as String;
        await _storage.write(key: 'access_token', value: newToken);

        // Retry original request with new token
        final retryOptions = err.requestOptions;
        retryOptions.headers['Authorization'] = 'Bearer $newToken';
        final retryResp = await _dio.fetch(retryOptions);
        _isRefreshing = false;
        return handler.resolve(retryResp);
      } catch (_) {
        _isRefreshing = false;
        // Refresh failed — clear tokens and let 401 propagate (user logs out)
        await _storage.deleteAll();
      }
    }
    handler.next(err);
  }
}
