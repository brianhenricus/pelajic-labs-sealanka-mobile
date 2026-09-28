import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:sea_lanka/core/network/api_endpoints.dart';

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(_AuthInterceptor(_storage, _dio));
    // Debug-only: logs headers/bodies including Authorization tokens, OTP
    // codes, and passwords -- never in a release build (adb logcat is
    // readable by any app with log-read access, or via USB debugging).
    if (kDebugMode) {
      _dio.interceptors.add(PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        compact: false,
      ));
    }
  }

  Dio get dio => _dio;
}

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  final Dio _dio;
  Future<String?>? _refreshFuture;

  _AuthInterceptor(this._storage, this._dio);

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  // Concurrent 401s -- e.g. a page firing several parallel requests right
  // when the access token expires -- must share ONE refresh call. The
  // backend rotates+revokes the refresh token on every use, so if each 401
  // independently reads the (same, now-stale) refresh token and POSTs it,
  // only the first call succeeds; the rest get rejected and their retry
  // never happens, silently stranding that one request/page in an error
  // state while everything else on screen loads fine. Every 401 handler
  // awaits this same in-flight future instead of starting its own.
  Future<String?> _refreshAccessToken() {
    return _refreshFuture ??= _performRefresh().whenComplete(() {
      _refreshFuture = null;
    });
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) return null;
    final response = await _dio.post(ApiEndpoints.refreshToken,
        data: {'refresh_token': refreshToken});
    final newToken = response.data['access_token'] as String;
    final newRefreshToken = response.data['refresh_token'] as String;
    await _storage.write(key: 'access_token', value: newToken);
    await _storage.write(key: 'refresh_token', value: newRefreshToken);
    return newToken;
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        final newToken = await _refreshAccessToken();
        if (newToken != null) {
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          final retryResponse = await _dio.fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        }
      } catch (_) {}
    }
    handler.next(err);
  }
}
