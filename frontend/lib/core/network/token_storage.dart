import 'package:shared_preferences/shared_preferences.dart';

/// Persists the SimpleJWT access/refresh pair.
///
/// On Flutter Web this is backed by `localStorage`, so a reload keeps the user
/// signed in. Reads are tolerant of storage being unavailable or cleared
/// (private windows, blocked site data) and simply report "no session".
class TokenStorage {
  static const _accessKey = 'techzone.access_token';
  static const _refreshKey = 'techzone.refresh_token';

  String? _access;
  String? _refresh;
  bool _loaded = false;

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  bool get hasSession => (_refresh ?? '').isNotEmpty;

  /// Reads the persisted pair into memory. Safe to call more than once.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _access = prefs.getString(_accessKey);
      _refresh = prefs.getString(_refreshKey);
    } catch (_) {
      // Storage unavailable: behave as a signed-out session.
      _access = null;
      _refresh = null;
    }
    _loaded = true;
  }

  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessKey, access);
      await prefs.setString(_refreshKey, refresh);
    } catch (_) {
      // In-memory session still works for this page view.
    }
  }

  /// SIMPLE_JWT has ROTATE_REFRESH_TOKENS enabled, so a refresh call returns a
  /// new refresh token too. When it does, both are replaced.
  Future<void> updateAccess(String access, {String? refresh}) async {
    _access = access;
    if (refresh != null && refresh.isNotEmpty) _refresh = refresh;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessKey, access);
      if (refresh != null && refresh.isNotEmpty) {
        await prefs.setString(_refreshKey, refresh);
      }
    } catch (_) {
      /* best effort */
    }
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessKey);
      await prefs.remove(_refreshKey);
    } catch (_) {
      /* best effort */
    }
  }
}
