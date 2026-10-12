import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

/// Singleton Dio client pre-configured with:
///   • baseUrl from AppConfig
///   • AuthInterceptor — attaches Bearer token and single-flight auto-refreshes on 401
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _storage = FlutterSecureStorage();
  late final Dio dio = _buildDio();

  Dio _buildDio() {
    final d = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 60), // longer for audio uploads
        contentType: 'application/json',
      ),
    );
    d.interceptors.add(_AuthInterceptor(d, _storage));
    if (kDebugMode) d.interceptors.add(_SafeNetworkLogger());
    return d;
  }

  void updateBaseUrl(String newUrl) {
    dio.options.baseUrl = newUrl;
  }

  // ── Convenience wrappers ──────────────────────────────────────────────────

  Future<dynamic> get(String path, {Map<String, dynamic>? params}) =>
      dio.get(path, queryParameters: params).then((r) => r.data);

  Future<dynamic> post(String path, {dynamic data}) =>
      dio.post(path, data: data).then((r) => r.data);

  Future<dynamic> patch(String path, {dynamic data}) =>
      dio.patch(path, data: data).then((r) => r.data);

  Future<dynamic> postMultipart(
    String path,
    FormData formData, {
    void Function(int, int)? onSendProgress,
  }) => dio
      .post(
        path,
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(contentType: 'multipart/form-data'),
      )
      .then((r) => r.data);

  // ── Token helpers ─────────────────────────────────────────────────────────

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  /// Deletes ONLY authentication tokens so that user theme preferences and
  /// device settings are preserved across logout.
  static Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  static Future<String?> getAccessToken() => _storage.read(key: 'access_token');

  static Future<String?> getRefreshToken() =>
      _storage.read(key: 'refresh_token');
}

/// Development diagnostics deliberately exclude request bodies and headers.
class _SafeNetworkLogger extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      'API ${err.requestOptions.method} ${err.requestOptions.path} '
      'failed with HTTP ${err.response?.statusCode ?? 'network'}',
    );
    handler.next(err);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auth Interceptor (Single-Flight Refresh)
// ─────────────────────────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  Future<bool>? _refreshFuture;

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

  Future<bool> _refreshToken() {
    // If a refresh is already in-flight, return the existing future to deduplicate
    return _refreshFuture ??= (() async {
      try {
        final refreshToken = await _storage.read(key: 'refresh_token');
        if (refreshToken == null) return false;

        final refreshDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
        final resp = await refreshDio.post(
          '/auth/refresh',
          data: {'refresh_token': refreshToken},
        );
        final newToken = resp.data['access_token'] as String;
        await _storage.write(key: 'access_token', value: newToken);
        return true;
      } catch (_) {
        await ApiClient.clearTokens();
        return false;
      } finally {
        _refreshFuture = null;
      }
    })();
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Attempt single-flight refresh on 401s from non-auth endpoints
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.contains('/auth/')) {
      final success = await _refreshToken();
      if (success) {
        final newToken = await _storage.read(key: 'access_token');
        final retryOptions = err.requestOptions;
        retryOptions.headers['Authorization'] = 'Bearer $newToken';
        try {
          final retryResp = await _dio.fetch(retryOptions);
          return handler.resolve(retryResp);
        } on DioException catch (retryErr) {
          return handler.next(retryErr);
        } catch (_) {
          return handler.next(err);
        }
      }
    }
    handler.next(err);
  }
}
