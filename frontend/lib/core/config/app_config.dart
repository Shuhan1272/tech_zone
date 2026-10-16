/// Central, environment-driven configuration for the TechZone frontend.
///
/// Nothing here is hardcoded to a production host. The base URL comes from a
/// Dart define, so the same build pipeline serves local development and
/// deployment:
///
///   flutter run -d chrome
///   flutter build web --dart-define=API_BASE_URL=https://api.example.com
library;

class AppConfig {
  const AppConfig._();

  /// Root of the Django server (scheme + host + port), no trailing slash.
  ///
  /// Defaults to the local development server the Django `runserver` command
  /// starts, which is what `Guideline/API/*` documents as the base host.
  static const String serverOrigin = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// Versioned API root. Every service builds its paths relative to this.
  static String get apiBaseUrl => '$serverOrigin/api/v1';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Page size requested from the paginated product endpoint.
  /// The backend caps `limit` at 90 (products/pagination.py).
  static const int defaultPageSize = 20;
  static const int maxPageSize = 90;

  /// Resolves a possibly-relative media path returned by Django into an
  /// absolute URL. DRF returns absolute URLs when a request context is
  /// present, but nested serializers without context emit relative paths
  /// (e.g. Category.sub_categories[].image), so both forms must be handled.
  static String? resolveMedia(String? path) {
    if (path == null || path.isEmpty) return null;
    if (_isPlaceholder(path)) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$serverOrigin${path.startsWith('/') ? '' : '/'}$path';
  }

  /// True for the `default.jpg` fallbacks the `ImageField`s point at when no
  /// picture was uploaded.
  ///
  /// Most of them 404; the one that does exist is a stock photo, not artwork
  /// for that row. Either way it is "no image", so the caller draws its own
  /// placeholder instead of a broken or unrelated picture.
  static bool _isPlaceholder(String path) {
    final name = path.split('/').last.toLowerCase();
    return name.startsWith('default.');
  }
}
