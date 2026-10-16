import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../models/discount.dart';
import '../models/paginated.dart';

/// Wraps the `discounts` API, which is **optional at runtime**.
///
/// On the current backend neither endpoint exists:
///   * `config/urls.py` never `include()`s `discounts.urls`
///   * the app has no migrations, so `discounts_discount` is not in the DB
///   * `POST /discounts/apply/` was never implemented (the guideline lists it
///     as the next step)
///
/// Rather than hardcoding that assumption, the service probes once and caches
/// the verdict. The coupon UI reads [availability] and either enables itself or
/// explains that the feature is not live yet — so wiring the route up on the
/// backend makes the UI work with no frontend change.
class DiscountService {
  DiscountService(this._client);

  final ApiClient _client;

  DiscountAvailability _availability = DiscountAvailability.unknown;
  DiscountAvailability get availability => _availability;

  bool get isListAvailable =>
      _availability == DiscountAvailability.listAvailable ||
      _availability == DiscountAvailability.applyAvailable;

  bool get isApplyAvailable =>
      _availability == DiscountAvailability.applyAvailable;

  /// Checks what the server actually supports. Cheap, cached, and safe to call
  /// on every cart view.
  Future<DiscountAvailability> probe({bool force = false}) async {
    if (!force && _availability != DiscountAvailability.unknown) {
      return _availability;
    }

    // Does the management endpoint resolve at all?
    var listWorks = false;
    try {
      await _client.get<dynamic>(ApiEndpoints.discounts, skipAuth: true);
      listWorks = true;
    } on ApiException catch (error) {
      // A 401/403 still proves the route exists — it is just protected.
      listWorks = !error.isNotFound && !error.isNetworkError;
    }

    if (!listWorks) {
      return _availability = DiscountAvailability.unavailable;
    }

    // Does the apply endpoint exist? An empty POST should come back as a
    // validation error (400) if implemented, and 404 if not.
    try {
      await _client.post<dynamic>(
        ApiEndpoints.applyDiscount,
        body: const <String, dynamic>{},
      );
      return _availability = DiscountAvailability.applyAvailable;
    } on ApiException catch (error) {
      if (error.isNotFound || error.isNetworkError) {
        return _availability = DiscountAvailability.listAvailable;
      }
      // 400 means the view ran and rejected our empty payload: it exists.
      return _availability = DiscountAvailability.applyAvailable;
    }
  }

  /// Lists discounts. Promo codes are intentionally excluded from anything
  /// customer-facing — only `staff` / `new_customer` style offers are safe to
  /// advertise, and even those are informational.
  Future<List<Discount>> fetchDiscounts() async {
    final data = await _client.get<dynamic>(ApiEndpoints.discounts);
    return Paginated.fromAny<Discount>(data, Discount.fromJson).items;
  }

  /// Asks the **server** to validate a promo code and compute the amount.
  ///
  /// The client deliberately sends only the code. It never sends a subtotal or
  /// a discount amount, and never derives one locally — per the guideline, the
  /// backend decides the actual amount.
  Future<AppliedDiscount> applyCode(String code) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.applyDiscount,
      body: {'code': code.trim().toUpperCase()},
    );
    return AppliedDiscount.fromJson(data);
  }
}
