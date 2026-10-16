/// DRF PageNumberPagination envelope.
///
/// Only the product and variant endpoints are paginated (they set
/// `pagination_class = ProductPagination`); categories, brands, images,
/// notices, reviews and questions return bare JSON arrays. [Paginated.fromAny]
/// accepts either shape so callers do not have to care.
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.count,
    this.next,
    this.previous,
  });

  final List<T> items;
  final int count;
  final String? next;
  final String? previous;

  bool get hasNext => next != null;
  bool get isEmpty => items.isEmpty;

  static Paginated<T> empty<T>() => Paginated<T>(items: const [], count: 0);

  static Paginated<T> fromAny<T>(
    dynamic data,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (data is List) {
      final items = data
          .whereType<Map<String, dynamic>>()
          .map(parse)
          .toList(growable: false);
      return Paginated<T>(items: items, count: items.length);
    }

    if (data is Map<String, dynamic>) {
      final raw = data['results'];
      final items = (raw is List ? raw : const [])
          .whereType<Map<String, dynamic>>()
          .map(parse)
          .toList(growable: false);
      return Paginated<T>(
        items: items,
        count: (data['count'] as num?)?.toInt() ?? items.length,
        next: data['next'] as String?,
        previous: data['previous'] as String?,
      );
    }

    return Paginated<T>(items: const [], count: 0);
  }

  /// Appends a freshly-fetched page, keeping the newer paging cursors.
  Paginated<T> concat(Paginated<T> page) => Paginated<T>(
    items: [...items, ...page.items],
    count: page.count,
    next: page.next,
    previous: page.previous,
  );
}

/// Django serialises DecimalField as a JSON *string* ("83490.00") but computed
/// `@property` fields as a *number* (3757.5). Both appear in the same payload
/// (ProductVariantSerializer returns `price` as a string and `discounted_price`
/// as a double), so every money field goes through here.
double? parseDecimal(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

int parseInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

bool parseBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.toLowerCase().trim();
    if (v == 'true' || v == '1') return true;
    if (v == 'false' || v == '0') return false;
  }
  return fallback;
}

DateTime? parseDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

/// `key_feature`, `specification`, `options` and `Category.filters` are
/// JSONFields that default to `{}` but can hold other shapes, so coerce
/// defensively rather than casting.
Map<String, dynamic> parseJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const {};
}

List<String> parseStringList(dynamic value) {
  if (value is List) {
    return value
        .where((e) => e != null)
        .map((e) => e.toString())
        .toList(growable: false);
  }
  return const [];
}
