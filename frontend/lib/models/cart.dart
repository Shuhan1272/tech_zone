import 'paginated.dart';
import 'product.dart';

/// Mirrors `cart.serializers.CartItemSerializer`.
///
/// The serializer is deliberately thin — it exposes the variant *id* plus a
/// product name and the two prices, but no stock, options, slug or image. So
/// [variant] and [product] are hydrated separately from the products API when
/// the cart screen needs stock limits or a thumbnail, and stay null until then.
class CartItem {
  const CartItem({
    required this.id,
    required this.variantId,
    required this.productName,
    required this.unitPrice,
    required this.unitDiscountedPrice,
    required this.quantity,
    this.variant,
    this.product,
  });

  /// CartItem primary key — this, *not* [variantId], is what PATCH and DELETE
  /// address (`/cart/items/{id}/`).
  final int id;

  /// ProductVariant primary key — what POST `/cart/items/` expects.
  final int variantId;

  final String productName;

  /// Backend `variant.price`: list price before the variant's own discount.
  final double unitPrice;

  /// Backend `variant.discounted_price`: the authoritative payable unit price.
  final double unitDiscountedPrice;

  final int quantity;

  /// Hydrated from `/products/variants/{id}/` for stock and option labels.
  final ProductVariant? variant;

  /// Hydrated from `/products/products/?...` for the slug and thumbnail.
  final Product? product;

  /// Line total from the server's unit price. Display only — the backend
  /// remains the authority on what is actually charged.
  double get lineTotal => unitDiscountedPrice * quantity;

  /// Line total at list price, for the strike-through comparison.
  double get lineListTotal => unitPrice * quantity;

  double get lineSavings =>
      (lineListTotal - lineTotal).clamp(0, double.infinity);

  bool get hasDiscount => unitPrice > unitDiscountedPrice;

  /// Stock ceiling, when known. Null means "not hydrated yet", which the UI
  /// treats as "do not block the user" and lets the server reject instead.
  int? get availableStock => variant?.stock;

  bool get canIncrease {
    final stock = availableStock;
    return stock == null || quantity < stock;
  }

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    id: parseInt(json['id']),
    variantId: parseInt(json['variant']),
    productName: (json['product_name'] ?? '') as String,
    unitPrice: parseDecimal(json['variant_price']) ?? 0,
    unitDiscountedPrice:
        parseDecimal(json['discounted_price']) ??
        parseDecimal(json['variant_price']) ??
        0,
    quantity: parseInt(json['quantity'], fallback: 1),
  );

  CartItem copyWith({ProductVariant? variant, Product? product}) => CartItem(
    id: id,
    variantId: variantId,
    productName: productName,
    unitPrice: unitPrice,
    unitDiscountedPrice: unitDiscountedPrice,
    quantity: quantity,
    variant: variant ?? this.variant,
    product: product ?? this.product,
  );
}

/// Mirrors `cart.serializers.CartSerializer`.
///
/// The serializer returns no monetary totals, so [subtotal] and [savings] are
/// summed on the client *from server-supplied unit prices*. They are shown as
/// an order summary, never used to authorise a charge — there is no checkout
/// endpoint to send them to.
class Cart {
  const Cart({required this.id, this.items = const [], this.updatedAt});

  final int id;
  final List<CartItem> items;
  final DateTime? updatedAt;

  bool get isEmpty => items.isEmpty;

  /// Distinct line count (what the header badge shows).
  int get lineCount => items.length;

  /// Total pieces across all lines.
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  /// Sum of server-provided discounted unit prices x quantity.
  double get subtotal => items.fold(0, (sum, item) => sum + item.lineTotal);

  /// Sum at list price, before per-variant discounts.
  double get listSubtotal =>
      items.fold(0, (sum, item) => sum + item.lineListTotal);

  /// How much the per-variant discounts already save.
  double get savings => (listSubtotal - subtotal).clamp(0, double.infinity);

  CartItem? itemForVariant(int variantId) {
    for (final item in items) {
      if (item.variantId == variantId) return item;
    }
    return null;
  }

  factory Cart.fromJson(Map<String, dynamic> json) => Cart(
    id: parseInt(json['id']),
    items: (json['items'] is List ? json['items'] as List : const [])
        .whereType<Map<String, dynamic>>()
        .map(CartItem.fromJson)
        .toList(growable: false),
    updatedAt: parseDate(json['updated_at']),
  );

  Cart copyWithItems(List<CartItem> newItems) =>
      Cart(id: id, items: newItems, updatedAt: updatedAt);

  static Cart get empty => const Cart(id: 0);
}
