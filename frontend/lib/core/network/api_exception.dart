import 'package:dio/dio.dart';

/// A single, UI-friendly error type for everything the API layer can fail with.
///
/// DRF reports validation failures as `{"field": ["message", ...]}` and
/// non-field failures as `{"detail": "..."}`. Both shapes are flattened here so
/// screens can show a headline message and still highlight individual fields.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
    this.isNetworkError = false,
  });

  final String message;
  final int? statusCode;

  /// Field name -> first error message, for inline form validation.
  final Map<String, String> fieldErrors;

  /// True when the request never reached the server (DNS, timeout, CORS,
  /// server down). Screens use this to offer a retry rather than a form fix.
  final bool isNetworkError;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  /// True when the endpoint itself is missing from the server's URL conf.
  /// Used to feature-detect the discounts and orders APIs.
  bool get isUnavailable => statusCode == 404 || statusCode == 501;

  @override
  String toString() => 'ApiException($statusCode): $message';

  factory ApiException.fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return ApiException(
          message:
              'The server took too long to respond. Check that Django is '
              'running, then try again.',
          isNetworkError: true,
        );
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(
          message: 'The server stopped responding mid-request. Please retry.',
          isNetworkError: true,
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return ApiException(
          message:
              'Could not reach the TechZone server. Make sure the Django '
              'development server is running and reachable.',
          isNetworkError: true,
        );
      case DioExceptionType.cancel:
        return ApiException(message: 'Request cancelled.');
      case DioExceptionType.badCertificate:
        return ApiException(
          message: 'The server certificate could not be verified.',
          isNetworkError: true,
        );
      case DioExceptionType.badResponse:
        return ApiException._fromResponse(error.response!);
    }
  }

  factory ApiException._fromResponse(Response<dynamic> response) {
    final status = response.statusCode;
    final data = response.data;
    final fields = <String, String>{};
    String? headline;

    if (data is Map) {
      for (final entry in data.entries) {
        final key = entry.key.toString();
        final flattened = _flatten(entry.value);
        if (flattened == null) continue;

        if (key == 'detail' || key == 'non_field_errors') {
          headline ??= flattened;
        } else {
          fields[key] = flattened;
        }
      }
      // No `detail` key: surface the first field error as the headline so the
      // user always sees something meaningful.
      headline ??= fields.values.isNotEmpty ? fields.values.first : null;
    } else if (data is List) {
      headline = _flatten(data);
    } else if (data is String && data.isNotEmpty && !data.contains('<html')) {
      headline = data;
    }

    return ApiException(
      message: headline ?? _defaultMessageFor(status),
      statusCode: status,
      fieldErrors: fields,
    );
  }

  /// DRF nests errors arbitrarily deep; take the first leaf string.
  static String? _flatten(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      for (final item in value) {
        final found = _flatten(item);
        if (found != null) return found;
      }
      return null;
    }
    if (value is Map) {
      for (final item in value.values) {
        final found = _flatten(item);
        if (found != null) return found;
      }
      return null;
    }
    return null;
  }

  static String _defaultMessageFor(int? status) {
    switch (status) {
      case 400:
        return 'The server rejected that request. Please check your input.';
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return 'You do not have permission to do that.';
      case 404:
        return 'That resource was not found on the server.';
      case 429:
        return 'Too many attempts. Please wait a moment and try again.';
      case 500:
      case 502:
      case 503:
        return 'The server ran into a problem. Please try again shortly.';
      default:
        return 'Request failed${status == null ? '' : ' (HTTP $status)'}.';
    }
  }
}
