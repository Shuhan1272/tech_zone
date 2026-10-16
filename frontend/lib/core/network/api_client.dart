import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// The single HTTP entry point for the whole app.
///
/// Responsibilities:
///  * attach `Authorization: Bearer <access>` to requests that need it
///  * transparently refresh an expired access token once, then replay
///  * translate every transport/HTTP failure into [ApiException]
///
/// CSRF is deliberately not handled: the backend authenticates with SimpleJWT
/// (`DEFAULT_AUTHENTICATION_CLASSES` is JWT-only), so requests carry a bearer
/// token rather than a session cookie and Django's CsrfViewMiddleware does not
/// apply to them. `CORS_ALLOW_ALL_ORIGINS = True` already permits the Flutter
/// Web dev origin.
class ApiClient {
  ApiClient({required TokenStorage tokens, Dio? dio})
    : _tokens = tokens,
      _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = AppConfig.apiBaseUrl
      ..connectTimeout = AppConfig.connectTimeout
      ..receiveTimeout = AppConfig.receiveTimeout
      ..headers = {'Accept': 'application/json'}
      // Let non-2xx responses through to the error interceptor rather than
      // throwing on, say, a 404 we want to feature-detect.
      ..validateStatus = (status) => status != null && status < 400;

    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  final Dio _dio;
  final TokenStorage _tokens;

  /// Invoked when a refresh attempt fails, so the app can drop to signed-out.
  void Function()? onSessionExpired;

  /// De-duplicates concurrent refreshes: if three requests 401 at once, only
  /// one refresh call is made and all three await it.
  Future<String?>? _refreshInFlight;

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokens.accessToken;
    final skipAuth = options.extra['skipAuth'] == true;
    if (!skipAuth && token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final response = error.response;
    final options = error.requestOptions;

    final canRetry =
        response?.statusCode == 401 &&
        options.extra['skipAuth'] != true &&
        options.extra['isRetry'] != true &&
        _tokens.hasSession &&
        options.path != ApiEndpoints.refreshToken;

    if (!canRetry) {
      return handler.next(error);
    }

    final newToken = await _refreshAccessToken();
    if (newToken == null) {
      onSessionExpired?.call();
      return handler.next(error);
    }

    try {
      final replayed = await _dio.fetch<dynamic>(
        options
          ..headers['Authorization'] = 'Bearer $newToken'
          ..extra['isRetry'] = true,
      );
      return handler.resolve(replayed);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }

  Future<String?> _refreshAccessToken() {
    return _refreshInFlight ??= _performRefresh().whenComplete(
      () => _refreshInFlight = null,
    );
  }

  Future<String?> _performRefresh() async {
    final refresh = _tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) return null;

    try {
      // A bare Dio instance: the interceptors must not run for this call.
      final response =
          await Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: AppConfig.connectTimeout,
              receiveTimeout: AppConfig.receiveTimeout,
              headers: const {'Accept': 'application/json'},
            ),
          ).post<Map<String, dynamic>>(
            ApiEndpoints.refreshToken,
            data: {'refresh': refresh},
          );

      final data = response.data;
      final access = data?['access'] as String?;
      if (access == null || access.isEmpty) return null;

      await _tokens.updateAccess(access, refresh: data?['refresh'] as String?);
      return access;
    } on DioException {
      await _tokens.clear();
      return null;
    }
  }

  // ------------------------------------------------------------------ verbs

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool skipAuth = false,
  }) => _send<T>(
    () => _dio.get<T>(
      path,
      queryParameters: _clean(query),
      options: Options(extra: {'skipAuth': skipAuth}),
    ),
  );

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool skipAuth = false,
  }) => _send<T>(
    () => _dio.post<T>(
      path,
      data: body,
      queryParameters: _clean(query),
      options: Options(
        extra: {'skipAuth': skipAuth},
        contentType: Headers.jsonContentType,
      ),
    ),
  );

  Future<T> patch<T>(String path, {Object? body}) => _send<T>(
    () => _dio.patch<T>(
      path,
      data: body,
      options: Options(contentType: Headers.jsonContentType),
    ),
  );

  Future<T> put<T>(String path, {Object? body}) => _send<T>(
    () => _dio.put<T>(
      path,
      data: body,
      options: Options(contentType: Headers.jsonContentType),
    ),
  );

  Future<void> delete(String path) =>
      _send<void>(() => _dio.delete<void>(path));

  Future<T> _send<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      return response.data as T;
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  /// Drops null/empty query values so we never send `?brand=&search=`.
  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      cleaned[entry.key] = value;
    }
    return cleaned.isEmpty ? null : cleaned;
  }
}
