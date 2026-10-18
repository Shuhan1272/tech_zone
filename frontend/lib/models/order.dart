import 'paginated.dart';

/// Where an order has got to.
///
/// The server sends the raw token *and* its own display label, so the label
/// is never invented here; the enum exists only to pick an icon and a colour.
enum OrderStatus {
  pending,
  confirmed,
  processing,
  shipped,
  delivered,
  cancelled,

  /// A status this build of the app has not been taught about. Shown using
  /// the server's label rather than hidden.
  unknown;

  static OrderStatus parse(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    for (final status in OrderStatus.values) {
      if (status != OrderStatus.unknown && status.name == value) return status;
    }
    return OrderStatus.unknown;
  }

  bool get isCancelled => this == OrderStatus.cancelled;
  bool get isDelivered => this == OrderStatus.delivered;

  /// True while the order is still working its way to the customer.
  bool get isOpen =>
      this != OrderStatus.cancelled && this != OrderStatus.delivered;
}

/// One line of an order. Every field is the server's snapshot of how things
/// were when the order was placed, so a later price or name change in the
/// catalogue does not rewrite history.
class OrderItem {
  const OrderItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.unitPricePaid,
    required this.lineTotal,
    this.variantId,
    this.productSlug,
    this.variantSku = '',
    this.options = const {},
    this.unitDiscountPercentage = 0,
  });

  final int id;
  final int? variantId;
  final String productName;
  final String? productSlug;
  final String variantSku;
  final Map<String, dynamic> options;

  /// List price per unit at the time of the order.
  final double unitPrice;

  final double unitDiscountPercentage;

  /// What the customer actually pays per unit.
  final double unitPricePaid;

  final int quantity;
  final double lineTotal;

  bool get hasDiscount => unitPrice > unitPricePaid;

  double get lineSavings =>
      ((unitPrice - unitPricePaid) * quantity).clamp(0, double.infinity);

  /// "8GB · 512GB" from the variant options, blank when there are none.
  String get optionLabel => options.entries
      .where((entry) => (entry.value ?? '').toString().trim().isNotEmpty)
      .map((entry) => entry.value.toString().trim())
      .join(' · ');

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    id: parseInt(json['id']),
    variantId: json['variant_id'] == null ? null : parseInt(json['variant_id']),
    productName: (json['product_name'] ?? '') as String,
    productSlug: json['product_slug'] as String?,
    variantSku: (json['variant_sku'] ?? '') as String,
    options: parseJsonMap(json['options']),
    unitPrice: parseDecimal(json['unit_price']) ?? 0,
    unitDiscountPercentage: parseDecimal(json['unit_discount_percentage']) ?? 0,
    unitPricePaid:
        parseDecimal(json['unit_price_paid']) ??
        parseDecimal(json['unit_price']) ??
        0,
    quantity: parseInt(json['quantity'], fallback: 1),
    lineTotal: parseDecimal(json['line_total']) ?? 0,
  );
}

/// The delivery address as it was when the order was placed.
///
/// A copy, not a live link to the account's address: editing the account
/// address later must not change where a past order was sent.
class OrderShippingAddress {
  const OrderShippingAddress({
    required this.recipient,
    required this.address1,
    required this.city,
    required this.postalCode,
    required this.region,
    required this.country,
    this.company = '',
    this.phone = '',
    this.address2 = '',
  });

  final String recipient;
  final String company;
  final String phone;
  final String address1;
  final String address2;
  final String city;
  final String postalCode;
  final String region;
  final String country;

  /// Multi-line postal form, the same shape the account screen uses.
  String get formatted => [
    address1,
    if (address2.trim().isNotEmpty) address2,
    '$city $postalCode'.trim(),
    region,
    country,
  ].where((line) => line.trim().isNotEmpty).join('\n');

  factory OrderShippingAddress.fromJson(Map<String, dynamic> json) =>
      OrderShippingAddress(
        recipient: (json['recipient'] ?? '') as String,
        company: (json['company'] ?? '') as String,
        phone: (json['phone'] ?? '') as String,
        address1: (json['address1'] ?? '') as String,
        address2: (json['address2'] ?? '') as String,
        city: (json['city'] ?? '') as String,
        postalCode: (json['postal_code'] ?? '') as String,
        region: (json['region'] ?? '') as String,
        country: (json['country'] ?? '') as String,
      );
}

/// Mirrors `order.serializers.OrderListSerializer` and, for a single order,
/// `OrderDetailSerializer` — which is the list shape plus [items],
/// [shippingAddress] and the customer's note.
///
/// Every monetary figure here was calculated by the server. The app displays
/// them; it never recomputes a total.
class Order {
  const Order({
    required this.orderNumber,
    required this.status,
    required this.statusDisplay,
    required this.paymentMethod,
    required this.paymentMethodDisplay,
    required this.paymentStatus,
    required this.paymentStatusDisplay,
    required this.itemsSubtotal,
    required this.productDiscountTotal,
    required this.couponDiscount,
    required this.shippingFee,
    required this.grandTotal,
    required this.totalQuantity,
    required this.itemCount,
    this.summary = '',
    this.placedAt,
    this.items = const [],
    this.shippingAddress,
    this.customerNote = '',
  });

  /// The customer-quotable identifier, e.g. `TZ-261018-A4F9C2`. This is also
  /// what the detail endpoint is addressed by.
  final String orderNumber;

  final OrderStatus status;

  /// The server's own label for [status] — shown verbatim.
  final String statusDisplay;

  final String paymentMethod;
  final String paymentMethodDisplay;

  final String paymentStatus;
  final String paymentStatusDisplay;

  final double itemsSubtotal;
  final double productDiscountTotal;
  final double couponDiscount;

  /// Always 0.00 today: no delivery charge is calculated anywhere in the
  /// system, and the checkout says so rather than guessing a figure.
  final double shippingFee;

  final double grandTotal;

  final int totalQuantity;
  final int itemCount;

  /// "Asus VivoBook 15 + 2 more" — enough to recognise the order in a list.
  final String summary;

  final DateTime? placedAt;

  /// Populated by the detail endpoint only; empty in a history row.
  final List<OrderItem> items;

  /// Populated by the detail endpoint only.
  final OrderShippingAddress? shippingAddress;

  final String customerNote;

  /// True once the full detail payload has been loaded.
  bool get hasDetail => items.isNotEmpty || shippingAddress != null;

  bool get isCashOnDelivery => paymentMethod == 'cod';

  bool get isPaid => paymentStatus == 'paid';

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final rawAddress = json['shipping_address'];

    return Order(
      orderNumber: (json['order_number'] ?? '') as String,
      status: OrderStatus.parse(json['status']),
      statusDisplay: (json['status_display'] ?? '') as String,
      paymentMethod: (json['payment_method'] ?? '') as String,
      paymentMethodDisplay: (json['payment_method_display'] ?? '') as String,
      paymentStatus: (json['payment_status'] ?? '') as String,
      paymentStatusDisplay: (json['payment_status_display'] ?? '') as String,
      itemsSubtotal: parseDecimal(json['items_subtotal']) ?? 0,
      productDiscountTotal: parseDecimal(json['product_discount_total']) ?? 0,
      couponDiscount: parseDecimal(json['coupon_discount']) ?? 0,
      shippingFee: parseDecimal(json['shipping_fee']) ?? 0,
      grandTotal: parseDecimal(json['grand_total']) ?? 0,
      totalQuantity: parseInt(json['total_quantity']),
      itemCount: parseInt(json['item_count']),
      summary: (json['summary'] ?? '') as String,
      placedAt: parseDate(json['placed_at']),
      items: (rawItems is List ? rawItems : const [])
          .whereType<Map<String, dynamic>>()
          .map(OrderItem.fromJson)
          .toList(growable: false),
      shippingAddress: rawAddress is Map<String, dynamic>
          ? OrderShippingAddress.fromJson(rawAddress)
          : null,
      customerNote: (json['customer_note'] ?? '') as String,
    );
  }
}
