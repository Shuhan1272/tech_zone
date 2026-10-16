import 'paginated.dart';

/// Mirrors `discounts.serializers.DiscountSerializer`.
///
/// IMPORTANT: this endpoint is not reachable on the current backend.
/// `discounts/urls.py` exists but `config/urls.py` never `include()`s it, and
/// the app has no migrations so there is no `discounts_discount` table. The
/// model is here so the UI is ready the moment the route is wired up; until
/// then [DiscountAvailability] reports the feature as unavailable.
class Discount {
  const Discount({
    required this.id,
    required this.name,
    required this.discountType,
    required this.valueType,
    required this.value,
    this.code,
    this.maxDiscount,
    this.minimumOrderAmount = 0,
    this.usageLimit,
    this.usedCount = 0,
    this.startDate,
    this.endDate,
    this.isActive = true,
  });

  final int id;
  final String name;

  /// One of `promo`, `staff`, `new_customer`.
  final String discountType;

  /// One of `percentage`, `fixed`.
  final String valueType;

  final double value;

  /// Only set for `promo` discounts; the serializer nulls it otherwise.
  final String? code;

  /// Percentage-only cap on the computed amount.
  final double? maxDiscount;

  final double minimumOrderAmount;
  final int? usageLimit;
  final int usedCount;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;

  bool get isPromo => discountType == 'promo';
  bool get isPercentage => valueType == 'percentage';

  String get valueLabel => isPercentage
      ? '${value.toStringAsFixed(0)}% off'
      : '${value.toStringAsFixed(0)} off';

  factory Discount.fromJson(Map<String, dynamic> json) => Discount(
    id: parseInt(json['id']),
    name: (json['name'] ?? '') as String,
    discountType: (json['discount_type'] ?? '') as String,
    valueType: (json['value_type'] ?? '') as String,
    value: parseDecimal(json['value']) ?? 0,
    code: json['code'] as String?,
    maxDiscount: parseDecimal(json['max_discount']),
    minimumOrderAmount: parseDecimal(json['minimum_order_amount']) ?? 0,
    usageLimit: json['usage_limit'] == null
        ? null
        : parseInt(json['usage_limit']),
    usedCount: parseInt(json['used_count']),
    startDate: parseDate(json['start_date']),
    endDate: parseDate(json['end_date']),
    isActive: parseBool(json['is_active'], fallback: true),
  );
}

/// Response shape documented for `POST /api/v1/discounts/apply/`.
///
/// That endpoint does not exist yet — the Discounts guideline itself lists
/// building it as the "next logical step". The model exists so that the
/// coupon UI consumes a *server-computed* amount the instant it ships, rather
/// than ever calculating a discount on the client.
class AppliedDiscount {
  const AppliedDiscount({
    required this.discountName,
    required this.discountAmount,
    required this.subtotal,
    required this.totalAfterDiscount,
    this.discountCode,
    this.discountType,
  });

  final String discountName;
  final String? discountCode;
  final String? discountType;

  /// Server-calculated. Never derived on the client.
  final double discountAmount;
  final double subtotal;
  final double totalAfterDiscount;

  factory AppliedDiscount.fromJson(Map<String, dynamic> json) =>
      AppliedDiscount(
        discountName: (json['discount_name'] ?? 'Discount') as String,
        discountCode: json['discount_code'] as String?,
        discountType: json['discount_type'] as String?,
        discountAmount: parseDecimal(json['discount_amount']) ?? 0,
        subtotal: parseDecimal(json['subtotal']) ?? 0,
        totalAfterDiscount: parseDecimal(json['total_after_discount']) ?? 0,
      );
}

/// What a runtime probe learned about the optional discount endpoints.
enum DiscountAvailability {
  /// Not probed yet.
  unknown,

  /// `/discounts/discounts/` responded — discount listing works.
  listAvailable,

  /// `/discounts/apply/` responded — server-side coupon calculation works.
  applyAvailable,

  /// Both endpoints 404. The backend has not wired the app up.
  unavailable,
}
