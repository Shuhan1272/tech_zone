import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../core/network/token_storage.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Owns the signed-in session for the whole app.
///
/// Screens never call [AuthService] directly for state-changing operations —
/// they go through here so that [status] and [user] stay the single source of
/// truth that the router and header read.
class AuthProvider extends ChangeNotifier {
  AuthProvider({required AuthService service, required TokenStorage tokens})
    : _service = service,
      _tokens = tokens;

  final AuthService _service;
  final TokenStorage _tokens;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  bool _busy = false;
  String? _error;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get isBusy => _busy;
  bool get isSignedIn => _status == AuthStatus.signedIn;

  /// True until the stored token has been checked, so the router can hold
  /// protected routes instead of bouncing to login on a page refresh.
  bool get isResolving => _status == AuthStatus.unknown;

  String? get error => _error;

  /// Field-level errors from the last failed call, for inline form display.
  Map<String, String> _fieldErrors = const {};
  Map<String, String> get fieldErrors => _fieldErrors;

  /// Restores a session from storage on app start.
  Future<void> bootstrap() async {
    await _tokens.load();
    if (!_tokens.hasSession) {
      _status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }

    try {
      _user = await _service.currentUser();
      _status = AuthStatus.signedIn;
    } on ApiException {
      // Expired or revoked refresh token: start clean rather than looping.
      await _tokens.clear();
      _user = null;
      _status = AuthStatus.signedOut;
    }
    notifyListeners();
  }

  /// Called by the API client when a token refresh fails mid-session.
  void handleSessionExpired() {
    if (_status == AuthStatus.signedOut) return;
    _user = null;
    _status = AuthStatus.signedOut;
    _error = 'Your session has expired. Please sign in again.';
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) =>
      _run(() async {
        await _service.login(email: email, password: password);
        _user = await _service.currentUser();
        _status = AuthStatus.signedIn;
      });

  /// Registers an account. The caller then routes to OTP verification —
  /// `LoginSerializer` refuses unverified accounts, so there is no way to skip.
  Future<bool> register({
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
    String firstName = '',
    String lastName = '',
  }) => _run(() async {
    await _service.register(
      email: email,
      phone: phone,
      password: password,
      confirmPassword: confirmPassword,
      firstName: firstName,
      lastName: lastName,
    );
  });

  /// Asks the backend to mail a fresh registration OTP.
  ///
  /// False means the server refused — too soon after the last send, or the
  /// address is already verified — and [error] carries its reason.
  Future<bool> resendEmailOtp(String email) =>
      _run(() => _service.resendEmailOtp(email: email));

  /// Confirms the registration OTP, which also signs the customer in.
  Future<bool> verifyEmail({required String email, required String otp}) =>
      _run(() async {
        final session = await _service.verifyEmail(email: email, otp: otp);
        _user = session.user ?? await _service.currentUser();
        _status = AuthStatus.signedIn;
      });

  Future<bool> forgotPassword(String email) =>
      _run(() => _service.forgotPassword(email));

  /// Returns the reset token, or null when the OTP was rejected.
  Future<String?> verifyPasswordOtp({
    required String email,
    required String otp,
  }) async {
    String? token;
    final ok = await _run(() async {
      token = await _service.verifyPasswordOtp(email: email, otp: otp);
    });
    return ok ? token : null;
  }

  Future<bool> resetPassword({
    required String resetToken,
    required String password,
    required String confirmPassword,
  }) => _run(
    () => _service.resetPassword(
      resetToken: resetToken,
      password: password,
      confirmPassword: confirmPassword,
    ),
  );

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) => _run(
    () => _service.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    ),
  );

  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) => _run(() async {
    _user = await _service.updateProfile(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );
  });

  Future<void> logout() async {
    await _service.logout();
    _user = null;
    _status = AuthStatus.signedOut;
    _error = null;
    _fieldErrors = const {};
    notifyListeners();
  }

  void clearError() {
    if (_error == null && _fieldErrors.isEmpty) return;
    _error = null;
    _fieldErrors = const {};
    notifyListeners();
  }

  /// Runs an auth call with uniform busy/error handling.
  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    _fieldErrors = const {};
    notifyListeners();

    try {
      await action();
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      _fieldErrors = error.fieldErrors;
      return false;
    } catch (error) {
      _error = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
