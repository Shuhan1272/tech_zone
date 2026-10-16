import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/token_storage.dart';
import '../models/user.dart';

/// Result of a call that hands back a JWT pair.
class AuthSession {
  const AuthSession({required this.access, required this.refresh, this.user});

  final String access;
  final String refresh;

  /// `verify-email/` returns an inline user object; `token/` does not.
  final AppUser? user;
}

/// Wraps the `accounts` API.
///
/// The flow this backend actually enforces (accounts/serializers.py):
///
///   register  ->  email OTP is mailed  ->  verify-email  ->  JWT issued
///
/// `LoginSerializer` rejects any account whose `is_email_verified` is false,
/// so verification is mandatory, not optional. There is no Firebase, no
/// EmailJS and no role selection anywhere in this flow — `role` defaults to
/// `customer` server-side and is never accepted from the client.
class AuthService {
  AuthService({required ApiClient client, required TokenStorage tokens})
    : _client = client,
      _tokens = tokens;

  final ApiClient _client;
  final TokenStorage _tokens;

  /// Creates an unverified account and triggers the verification OTP email.
  ///
  /// Returns nothing useful: `RegisterView` echoes back the submitted fields
  /// (no id, no tokens) because the account cannot be used until verified.
  ///
  /// Note the backend deletes any pre-existing *unverified* account with the
  /// same email rather than erroring, so re-registering is a valid retry.
  Future<void> register({
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
    String firstName = '',
    String lastName = '',
  }) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.register,
      skipAuth: true,
      body: {
        'email': email.trim(),
        'phone': phone.trim(),
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'password': password,
        'password2': confirmPassword,
      },
    );
  }

  /// Mails a fresh verification OTP for an account that has not been
  /// verified yet, replacing whatever code was sent before.
  ///
  /// `ResendEmailOTPSerializer` refuses a second send within a minute, and
  /// refuses outright once the address is verified; both arrive as an
  /// [ApiException] carrying the server's message.
  Future<void> resendEmailOtp({required String email}) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.resendEmailOtp,
      skipAuth: true,
      body: {'email': email.trim()},
    );
  }

  /// Confirms the 6-digit OTP from the registration email.
  ///
  /// On success `VerifyEmailView` issues a JWT pair *and* an inline user
  /// object, so the customer is signed in immediately without a second call.
  Future<AuthSession> verifyEmail({
    required String email,
    required String otp,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.verifyEmail,
      skipAuth: true,
      body: {'email': email.trim(), 'otp': otp.trim()},
    );

    final session = AuthSession(
      access: (data['access'] ?? '') as String,
      refresh: (data['refresh'] ?? '') as String,
      user: data['user'] is Map<String, dynamic>
          ? AppUser.fromJson(data['user'] as Map<String, dynamic>)
          : null,
    );
    await _tokens.save(access: session.access, refresh: session.refresh);
    return session;
  }

  /// Exchanges credentials for a JWT pair via `POST /accounts/token/`.
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      skipAuth: true,
      body: {'email': email.trim(), 'password': password},
    );

    final session = AuthSession(
      access: (data['access'] ?? '') as String,
      refresh: (data['refresh'] ?? '') as String,
    );
    await _tokens.save(access: session.access, refresh: session.refresh);
    return session;
  }

  /// There is no server-side logout or token blacklist endpoint exposed
  /// (`rest_framework_simplejwt.token_blacklist` is not in INSTALLED_APPS and
  /// no logout route is declared), so signing out is a client-side discard of
  /// the stored tokens.
  Future<void> logout() => _tokens.clear();

  Future<AppUser> currentUser() async {
    final data = await _client.get<Map<String, dynamic>>(ApiEndpoints.me);
    return AppUser.fromJson(data);
  }

  Future<AppUser> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    final body = <String, dynamic>{};
    if (firstName != null) body['first_name'] = firstName.trim();
    if (lastName != null) body['last_name'] = lastName.trim();
    if (phone != null) body['phone'] = phone.trim();

    final data = await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.me,
      body: body,
    );
    return AppUser.fromJson(data);
  }

  /// Changes the password for the signed-in user.
  ///
  /// The field is `current_password`, NOT the `old_password` the docx shows —
  /// `ChangePasswordSerializer` declares `current_password`.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.changePassword,
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password2': confirmPassword,
      },
    );
  }

  /// Step 1 of password recovery: mails a reset OTP.
  ///
  /// `ForgotPasswordView` always answers with the same generic message, but
  /// `ForgotPasswordSerializer.validate_email` still 400s for an unknown
  /// address — so an error here does reveal whether the account exists.
  Future<void> forgotPassword(String email) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.forgotPassword,
      skipAuth: true,
      body: {'email': email.trim()},
    );
  }

  /// Step 2: exchanges the emailed OTP for a short-lived reset token.
  /// The token is valid for 10 minutes.
  Future<String> verifyPasswordOtp({
    required String email,
    required String otp,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.verifyPasswordOtp,
      skipAuth: true,
      body: {'email': email.trim(), 'otp': otp.trim()},
    );
    return (data['reset_token'] ?? '') as String;
  }

  /// Step 3: sets the new password.
  ///
  /// `ResetPasswordSerializer` takes only `reset_token` + the password pair —
  /// the docx additionally lists `email` and names the field `token`, both of
  /// which the implementation ignores/rejects.
  Future<void> resetPassword({
    required String resetToken,
    required String password,
    required String confirmPassword,
  }) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.resetPassword,
      skipAuth: true,
      body: {
        'reset_token': resetToken,
        'password': password,
        'password2': confirmPassword,
      },
    );
  }
}
