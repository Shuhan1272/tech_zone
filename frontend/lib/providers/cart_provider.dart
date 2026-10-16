import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../models/cart.dart';
import '../models/discount.dart';
import '../services/cart_service.dart';
import '../services/discount_service.dart';
import '../services/product_service.dart';

/// Owns the signed-in customer's cart.
///
/// Every mutation round-trips to the server and the response replaces local
/// state — the cart is never advanced optimistically, because stock limits and
/// the add-vs-increment rule are enforced server-side and the client must not
/// pretend to know the outcome.
class CartProvider extends ChangeNotifier {
  CartProvider({
    required CartService cartService,
    required ProductService productService,
    required DiscountService discountService,
  }) : _cartService = cartService,
       _productService = productService,
       _discountService = discountService;

  final CartService _cartService;
  final ProductService _productService;
  final DiscountService _discountService;

  Cart _cart = Cart.empty;
  bool _loading = false;
  String? _error;

  /// CartItem ids with an in-flight mutation, so each row can show its own
  /// spinner without locking the whole cart.
  final Set<int> _pendingItems = <int>{};

  /// Variant ids currently being added, so each "Add to cart" button can show
  /// its own progress.
  final Set<int> _pendingVariants = <int>{};

  AppliedDiscount? _appliedDiscount;
  String? _discountError;
  DiscountAvailability _discountAvailability = DiscountAvailability.unknown;

  Cart get cart => _cart;
  List<CartItem> get items => _cart.items;
  bool get isLoading => _loading;
  bool get isEmpty => _cart.isEmpty;
  int get lineCount => _cart.lineCount;
  int get totalQuantity => _cart.totalQuantity;
  String? get error => _error;

  bool isItemPending(int cartItemId) => _pendingItems.contains(cartItemId);
  bool isVariantPending(int variantId) => _pendingVariants.contains(variantId);

  /// Sum of server-supplied discounted unit prices. Display only.
  double get subtotal => _cart.subtotal;
  double get variantSavings => _cart.savings;

  AppliedDiscount? get appliedDiscount => _appliedDiscount;
  String? get discountError => _discountError;
  DiscountAvailability get discountAvailability => _discountAvailability;
  bool get canApplyCoupon =>
      _discountAvailability == DiscountAvailability.applyAvailable;

  /// Order total. When a coupon has been applied the *server's*
  /// `total_after_discount` is used verbatim; otherwise it is the subtotal.
  /// No discount is ever computed here.
  double get orderTotal =>
      _appliedDiscount?.totalAfterDiscount ?? _cart.subtotal;

  double get couponDiscount => _appliedDiscount?.discountAmount ?? 0;

  /// How many of a variant are already in the cart, for the quantity stepper
  /// on the product page.
  int quantityInCart(int variantId) =>
      _cart.itemForVariant(variantId)?.quantity ?? 0;

  /// Loads the cart and hydrates each line with its variant (for stock) and
  /// product (for the thumbnail and a link back to the product page).
  ///
  /// `CartItemSerializer` carries neither, so this is a necessary second pass.
  Future<void> load({bool hydrate = true}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _cart = await _cartService.fetchCart();
      if (hydrate && _cart.items.isNotEmpty) {
        await _hydrate();
      }
      // Re-check whether the coupon endpoints are live.
      _discountAvailability = await _discountService.probe();
    } on ApiException catch (error) {
      _error = error.message;
      _cart = Cart.empty;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Clears local cart state on sign-out. The server-side cart persists.
  void reset() {
    _cart = Cart.empty;
    _error = null;
    _appliedDiscount = null;
    _discountError = null;
    _pendingItems.clear();
    _pendingVariants.clear();
    notifyListeners();
  }

  /// Fetches the variant and product behind each line, concurrently.
  Future<void> _hydrate() async {
    final hydrated = await Future.wait(
      _cart.items.map((item) async {
        try {
          final variant = await _productService.fetchVariant(item.variantId);
          return item.copyWith(variant: variant);
        } on ApiException {
          // A missing variant must not break the whole cart view.
          return item;
        }
      }),
    );
    _cart = _cart.copyWithItems(hydrated);
  }

  /// Adds (or increments, server-side) a variant.
  ///
  /// Returns null on success, or a message to surface in a snackbar — stock
  /// shortfalls arrive here as the server's own 400 text.
  Future<String?> addToCart({required int variantId, int quantity = 1}) async {
    if (_pendingVariants.contains(variantId)) return null;

    _pendingVariants.add(variantId);
    _error = null;
    notifyListeners();

    try {
      await _cartService.addItem(variantId: variantId, quantity: quantity);
      // Refetch so totals and the badge reflect the server's arithmetic
      // rather than a guess at how it merged the line.
      _cart = await _cartService.fetchCart();
      await _hydrate();
      _invalidateCoupon();
      return null;
    } on ApiException catch (error) {
      return error.message;
    } finally {
      _pendingVariants.remove(variantId);
      notifyListeners();
    }
  }

  /// Sets a line to an absolute quantity.
  Future<String?> updateQuantity({
    required int cartItemId,
    required int quantity,
  }) async {
    if (_pendingItems.contains(cartItemId)) return null;
    if (quantity < 1) return removeItem(cartItemId);

    _pendingItems.add(cartItemId);
    notifyListeners();

    try {
      await _cartService.updateQuantity(
        cartItemId: cartItemId,
        quantity: quantity,
      );
      _cart = await _cartService.fetchCart();
      await _hydrate();
      _invalidateCoupon();
      return null;
    } on ApiException catch (error) {
      return error.message;
    } finally {
      _pendingItems.remove(cartItemId);
      notifyListeners();
    }
  }

  Future<String?> increment(CartItem item) =>
      updateQuantity(cartItemId: item.id, quantity: item.quantity + 1);

  Future<String?> decrement(CartItem item) =>
      updateQuantity(cartItemId: item.id, quantity: item.quantity - 1);

  Future<String?> removeItem(int cartItemId) async {
    if (_pendingItems.contains(cartItemId)) return null;

    _pendingItems.add(cartItemId);
    notifyListeners();

    try {
      await _cartService.removeItem(cartItemId);
      _cart = await _cartService.fetchCart();
      await _hydrate();
      _invalidateCoupon();
      return null;
    } on ApiException catch (error) {
      return error.message;
    } finally {
      _pendingItems.remove(cartItemId);
      notifyListeners();
    }
  }

  /// Empties the cart by removing each line. There is no bulk-clear endpoint.
  Future<String?> clearCart() async {
    final ids = _cart.items.map((item) => item.id).toList();
    for (final id in ids) {
      final failure = await removeItem(id);
      if (failure != null) return failure;
    }
    return null;
  }

  /// Asks the server to validate and price a promo code.
  Future<void> applyCoupon(String code) async {
    _discountError = null;

    if (!canApplyCoupon) {
      _discountError = 'Coupon codes are not available on this server yet.';
      notifyListeners();
      return;
    }

    try {
      _appliedDiscount = await _discountService.applyCode(code);
    } on ApiException catch (error) {
      _appliedDiscount = null;
      _discountError = error.isNotFound
          ? 'Coupon codes are not available on this server yet.'
          : error.message;
    }
    notifyListeners();
  }

  void removeCoupon() {
    if (_appliedDiscount == null && _discountError == null) return;
    _appliedDiscount = null;
    _discountError = null;
    notifyListeners();
  }

  /// A coupon priced against an older subtotal is no longer trustworthy, so
  /// any cart change drops it and the customer re-applies.
  void _invalidateCoupon() {
    if (_appliedDiscount == null) return;
    _appliedDiscount = null;
    _discountError = 'Cart changed — please re-apply your coupon.';
  }
}
