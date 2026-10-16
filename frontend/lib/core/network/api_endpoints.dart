/// Every API path the frontend talks to.
///
/// These were verified against the running Django server, not just the
/// `Guideline/API/*.docx` documents. Where the two disagree the implementation
/// wins and the difference is noted inline.
library;

class ApiEndpoints {
  const ApiEndpoints._();

  // ---------------------------------------------------------------- accounts
  static const String register = '/accounts/register/';
  static const String verifyEmail = '/accounts/verify-email/';

  /// Mails a fresh registration OTP to an account that is still unverified.
  /// Refused for a minute after the previous send.
  static const String resendEmailOtp = '/accounts/resend-email-otp/';
  static const String login = '/accounts/token/';
  static const String refreshToken = '/accounts/token/refresh/';
  static const String me = '/accounts/me/';

  /// NOTE: the docx documents `old_password`; the serializer
  /// (accounts/serializers.py ChangePasswordSerializer) requires
  /// `current_password`. The implementation is authoritative.
  static const String changePassword = '/accounts/change-password/';

  static const String forgotPassword = '/accounts/forgot-password/';
  static const String verifyPasswordOtp = '/accounts/verify-password-otp/';

  /// NOTE: the docx documents `email` + `token`; the serializer requires only
  /// `reset_token` (plus password/password2).
  static const String resetPassword = '/accounts/reset-password/';

  static const String addresses = '/accounts/address/';
  static String address(int id) => '/accounts/address/$id/';

  // ---------------------------------------------------------------- products
  static const String categories = '/products/categories/';
  static String category(String slug) => '/products/categories/$slug/';

  static const String brands = '/products/brands/';
  static String brand(String slug) => '/products/brands/$slug/';

  static const String products = '/products/products/';
  static String product(String slug) => '/products/products/$slug/';

  static const String variants = '/products/variants/';
  static String variant(int id) => '/products/variants/$id/';

  /// `product` filtering here relies on the approved two-line addition of
  /// `product` to ProductImageSerializer.fields and `filterset_fields` on
  /// ProductImageViewSet.
  static const String productImages = '/products/product-images/';

  /// NOTE: both of these require authentication even for GET
  /// (ViewSets declare `permission_classes = [IsAuthenticated]`), and neither
  /// declares a filterset, so `?product=` is ignored server-side and results
  /// must be filtered client-side.
  static const String reviews = '/products/reviews/';
  static String review(int id) => '/products/reviews/$id/';
  static const String questions = '/products/questions/';
  static String question(int id) => '/products/questions/$id/';

  // -------------------------------------------------------------------- core
  static const String notices = '/core/notices/';

  // -------------------------------------------------------------------- cart
  static const String cart = '/cart/';
  static const String cartItems = '/cart/items/';
  static String cartItem(int id) => '/cart/items/$id/';

  // --------------------------------------------------------------- discounts
  /// Declared in `discounts/urls.py` but NOT included by `config/urls.py`,
  /// and the app has no migrations, so there is no `discounts_discount` table.
  /// Both of these currently return 404 and are probed at runtime.
  static const String discounts = '/discounts/discounts/';
  static const String applyDiscount = '/discounts/apply/';

  // ------------------------------------------------------------------ orders
  /// The `order` app contains no models, serializers, views or urls, and is
  /// not routed. There is no order API to call yet.
  static const String orders = '/orders/';
}
