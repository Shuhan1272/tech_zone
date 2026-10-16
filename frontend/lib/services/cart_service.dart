import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/cart.dart';

/// Wraps the `cart` API.
///
/// Every endpoint requires authentication — `Cart` is a OneToOne on the user
/// and `CartView.get_object` does `get_or_create`, so a signed-in customer
/// always has exactly one cart and there is no guest/anonymous cart to merge.
///
/// Note the two different id spaces, which the guideline stresses:
///   * POST   `/cart/items/`      takes a **ProductVariant** id
///   * PATCH  `/cart/items/{id}/` takes a **CartItem** id
///   * DELETE `/cart/items/{id}/` takes a **CartItem** id
class CartService {
  CartService(this._client);

  final ApiClient _client;

  Future<Cart> fetchCart() async {
    final data = await _client.get<Map<String, dynamic>>(ApiEndpoints.cart);
    return Cart.fromJson(data);
  }

  /// Adds a variant to the cart.
  ///
  /// The backend *increments* when the variant is already present (its
  /// `get_or_create` + add branch), so this is "add N more", not "set to N".
  /// Stock is validated server-side and a shortfall comes back as a 400 with
  /// `{"detail": "Not enough stock available."}`.
  Future<CartItem> addItem({required int variantId, int quantity = 1}) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.cartItems,
      body: {'variant': variantId, 'quantity': quantity},
    );
    return CartItem.fromJson(data);
  }

  /// Sets an existing line's quantity to an absolute value.
  ///
  /// `CartItemDetailView.perform_update` rejects a missing quantity, anything
  /// below 1, and anything above the variant's stock.
  Future<CartItem> updateQuantity({
    required int cartItemId,
    required int quantity,
  }) async {
    final data = await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.cartItem(cartItemId),
      body: {'quantity': quantity},
    );
    return CartItem.fromJson(data);
  }

  Future<void> removeItem(int cartItemId) =>
      _client.delete(ApiEndpoints.cartItem(cartItemId));
}
