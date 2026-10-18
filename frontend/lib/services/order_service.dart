import 'dart:math';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/order.dart';
import '../models/paginated.dart';

/// Wraps the `order` API.
///
/// Three calls, all of them requiring a signed-in customer:
///   * `POST   /orders/`          place the cart as an order
///   * `GET    /orders/`          that customer's own orders
///   * `GET    /orders/{number}/` one of them, by order number
///
/// Note what [placeOrder] does *not* send: no item list, no prices, no
/// totals. The server reads the cart itself and prices it from the catalogue,
/// so a tampered client cannot change what an order costs.
class OrderService {
  OrderService(this._client);

  final ApiClient _client;

  static final Random _random = Random();

  /// A key for one checkout attempt.
  ///
  /// The caller keeps it across retries: the server stores it on the order
  /// and refuses to create a second order for the same key, so a double tap,
  /// a dropped response or a replayed request can only ever place one order.
  static String newIdempotencyKey() {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);

    // The bound is a plain literal, never `1 << 32`. JavaScript bitwise
    // operators are 32-bit, so dart2js collapses any shift past 31 bits to
    // zero: on Flutter Web `1 << 32` is 0, and `nextInt(0)` throws
    // RangeError. On the Dart VM it is 2^32 and works, which is exactly how
    // such a bug reaches the browser with a green `flutter test`.
    final noise = _random.nextInt(0x40000000).toRadixString(36);

    return 'tz-$stamp-$noise';
  }

  /// Places the signed-in customer's cart as an order.
  ///
  /// Cash on delivery is the only payment method the server accepts, and the
  /// order comes back `unpaid` — placing an order does not pay for it.
  Future<Order> placeOrder({
    required String idempotencyKey,
    String paymentMethod = 'cod',
    String customerNote = '',
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.orders,
      body: {
        'payment_method': paymentMethod,
        if (customerNote.trim().isNotEmpty)
          'customer_note': customerNote.trim(),
        // Sent in the body as well as the header. A browser refuses to send
        // any header the server has not listed in Access-Control-Allow-
        // Headers, and surfaces that refusal as a plain network error, so the
        // no-duplicate-orders guarantee must not rest on the header alone.
        'idempotency_key': idempotencyKey,
      },
      headers: {'Idempotency-Key': idempotencyKey},
    );

    return Order.fromJson(data);
  }

  /// The customer's own order history, newest first.
  Future<Paginated<Order>> fetchOrders({int page = 1, int limit = 20}) async {
    final data = await _client.get<dynamic>(
      ApiEndpoints.orders,
      query: {'page': page, 'limit': limit},
    );

    return Paginated.fromAny<Order>(data, Order.fromJson);
  }

  /// One order in full, including its lines and the address it was sent to.
  ///
  /// Another customer's order number answers 404, so there is no way to read
  /// somebody else's order through this call.
  Future<Order> fetchOrder(String orderNumber) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.order(orderNumber),
    );

    return Order.fromJson(data);
  }
}
