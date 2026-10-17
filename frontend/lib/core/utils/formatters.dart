import 'package:intl/intl.dart';

/// Money and date formatting.
///
/// The seed data is Bangladeshi (`Address.country` defaults to Bangladesh and
/// the guideline quotes prices in ৳), so amounts render as BDT. The backend
/// stores plain decimals with no currency field, so this is presentation only.
class Formatters {
  const Formatters._();

  static final NumberFormat _money = NumberFormat.currency(
    locale: 'en_US',
    symbol: '৳ ', // ৳ + non-breaking space
    decimalDigits: 0,
  );

  static final NumberFormat _compact = NumberFormat.compact(locale: 'en_US');
  static final DateFormat _date = DateFormat('d MMM yyyy');
  static final DateFormat _dateTime = DateFormat('d MMM yyyy, h:mm a');

  /// Whole-taka display, which is how prices are quoted on the storefront.
  ///
  /// Always whole taka, never paisa. A discounted price is derived from a
  /// percentage, so it lands on fractions that are an artefact of that
  /// arithmetic rather than a real price: 1,349 at 9.56% off comes out as
  /// 1,220.0356, and a shelf label reading 1,220.04 is wrong, not precise.
  static String money(double? amount) {
    if (amount == null) return '—';
    return _money.format(amount);
  }

  static String compact(num value) => _compact.format(value);

  static String date(DateTime? value) =>
      value == null ? '—' : _date.format(value.toLocal());

  static String dateTime(DateTime? value) =>
      value == null ? '—' : _dateTime.format(value.toLocal());

  /// "5 days ago" style relative label for reviews and questions.
  static String relative(DateTime? value) {
    if (value == null) return '';
    final delta = DateTime.now().difference(value.toLocal());
    if (delta.inMinutes < 1) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    if (delta.inDays < 30) return '${delta.inDays}d ago';
    return date(value);
  }

  /// Turns a snake_case or lowercase API token into a readable label,
  /// e.g. `new_customer` -> "New customer".
  static String humanize(String value) {
    if (value.isEmpty) return value;
    final spaced = value.replaceAll('_', ' ').trim();
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  /// Discount badge text, e.g. "23% off".
  static String discountBadge(double percentage) =>
      '${percentage.toStringAsFixed(percentage % 1 == 0 ? 0 : 1)}% off';

  /// Savings badge for a product tile, e.g. "Save: ৳ 3,663 (-22%)".
  ///
  /// Both halves come from the backend's own `saved_price` and
  /// `discount_percentage`; nothing is recomputed here.
  static String savingsBadge(double? saved, double percentage) {
    final percent = percentage.toStringAsFixed(percentage % 1 == 0 ? 0 : 1);
    if (saved == null || saved <= 0) return '-$percent%';
    return 'Save: ${money(saved)} (-$percent%)';
  }
}
