// Order model parsing and OrderProvider behaviour.
//
// The money and the duplicate-submission rules are the parts of checkout that
// cost real money when they are wrong, so they are pinned down here rather
// than only exercised through the UI.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:techzone/core/network/api_client.dart';
import 'package:techzone/core/network/api_exception.dart';
import 'package:techzone/core/network/token_storage.dart';
import 'package:techzone/models/order.dart';
import 'package:techzone/models/paginated.dart';
import 'package:techzone/providers/order_provider.dart';
import 'package:techzone/services/order_service.dart';

const _detailPayload = {
  'order_number': 'TZ-261018-A4F9C2',
  'status': 'pending',
  'status_display': 'Pending',
  'payment_method': 'cod',
  'payment_method_display': 'Cash on Delivery',
  'payment_status': 'unpaid',
  'payment_status_display': 'Unpaid',
  'items_subtotal': '280000.00',
  'product_discount_total': '32200.00',
  'coupon_discount': '0.00',
  'shipping_fee': '0.00',
  'grand_total': '247800.00',
  'total_quantity': 2,
  'item_count': 1,
  'summary': 'MSI Cyborg 15',
  'placed_at': '2026-10-18T09:15:00Z',
  'items': [
    {
      'id': 1,
      'variant_id': 1,
      'product_name': 'MSI Cyborg 15',
      'product_slug': 'msi-cyborg-15',
      'variant_sku': 'msi-cyborg-15-8GB-512GB',
      'options': {'RAM': '8GB', 'Storage': '512GB'},
      'unit_price': '140000.00',
      'unit_discount_percentage': '11.50',
      'unit_price_paid': '123900.00',
      'quantity': 2,
      'line_total': '247800.00',
    },
  ],
  'shipping_address': {
    'recipient': 'Abdur Rahman',
    'company': '',
    'phone': '01712345678',
    'address1': 'House 12, Road 5',
    'address2': '',
    'city': 'Dhaka',
    'postal_code': '1207',
    'region': 'Dhaka',
    'country': 'Bangladesh',
  },
  'customer_note': 'Call before delivery',
};

/// A list row: the same shape minus items, address and note.
Map<String, dynamic> _listPayload({
  String number = 'TZ-261018-A4F9C2',
  String status = 'pending',
  String statusDisplay = 'Pending',
}) {
  final row = Map<String, dynamic>.of(_detailPayload);
  row
    ..remove('items')
    ..remove('shipping_address')
    ..remove('customer_note');
  row['order_number'] = number;
  row['status'] = status;
  row['status_display'] = statusDisplay;
  return row;
}

/// An OrderService whose answers each test controls.
class _FakeOrderService extends OrderService {
  _FakeOrderService() : super(ApiClient(tokens: TokenStorage()));

  final List<String> keysSeen = [];
  final List<String> notesSeen = [];

  int placeCalls = 0;
  int historyCalls = 0;
  int detailCalls = 0;

  /// When set, [placeOrder] throws this instead of succeeding.
  ApiException? placeFailure;

  /// When set, [placeOrder] throws it *synchronously*, before returning a
  /// future at all — the shape of the bug that once stuck the button.
  Object? synchronousFailure;

  ApiException? historyFailure;
  ApiException? detailFailure;

  /// Holds a history request open, to exercise the read timeout.
  Completer<void>? historyGate;

  /// When set, [placeOrder] waits on it — so a test can hold a submission
  /// open and try to start a second one.
  Completer<void>? gate;

  List<Map<String, dynamic>> historyRows = [_listPayload()];
  bool historyHasNext = false;

  // Deliberately not `async`, so [synchronousFailure] can be thrown before a
  // future exists at all.
  @override
  Future<Order> placeOrder({
    required String idempotencyKey,
    String paymentMethod = 'cod',
    String customerNote = '',
  }) {
    placeCalls++;
    keysSeen.add(idempotencyKey);
    notesSeen.add(customerNote);

    final sync = synchronousFailure;
    if (sync != null) throw sync;

    return _place();
  }

  Future<Order> _place() async {
    if (gate != null) await gate!.future;

    final failure = placeFailure;
    if (failure != null) throw failure;

    return Order.fromJson(Map<String, dynamic>.of(_detailPayload));
  }

  @override
  Future<Paginated<Order>> fetchOrders({int page = 1, int limit = 20}) async {
    historyCalls++;

    if (historyGate != null) await historyGate!.future;

    final failure = historyFailure;
    if (failure != null) throw failure;

    return Paginated<Order>(
      items: historyRows.map(Order.fromJson).toList(growable: false),
      count: historyRows.length,
      next: historyHasNext ? 'http://next' : null,
    );
  }

  @override
  Future<Order> fetchOrder(String orderNumber) async {
    detailCalls++;

    final failure = detailFailure;
    if (failure != null) throw failure;

    final payload = Map<String, dynamic>.of(_detailPayload);
    payload['order_number'] = orderNumber;
    return Order.fromJson(payload);
  }
}

void main() {
  group('Order parsing', () {
    test('a detail payload keeps the server figures exactly', () {
      final order = Order.fromJson(Map<String, dynamic>.of(_detailPayload));

      expect(order.orderNumber, 'TZ-261018-A4F9C2');
      expect(order.status, OrderStatus.pending);
      expect(order.statusDisplay, 'Pending');
      expect(order.itemsSubtotal, 280000);
      expect(order.productDiscountTotal, 32200);
      expect(order.couponDiscount, 0);
      expect(order.grandTotal, 247800);
      expect(order.totalQuantity, 2);
      expect(order.hasDetail, isTrue);
      expect(order.customerNote, 'Call before delivery');
    });

    test('shipping is zero and cash on delivery is unpaid', () {
      final order = Order.fromJson(Map<String, dynamic>.of(_detailPayload));

      expect(order.shippingFee, 0);
      expect(order.isCashOnDelivery, isTrue);
      expect(
        order.isPaid,
        isFalse,
        reason: 'placing a COD order must never mark it paid',
      );
    });

    test('a line carries its own price snapshot', () {
      final order = Order.fromJson(Map<String, dynamic>.of(_detailPayload));
      final item = order.items.single;

      expect(item.productName, 'MSI Cyborg 15');
      expect(item.unitPrice, 140000);
      expect(item.unitPricePaid, 123900);
      expect(item.quantity, 2);
      expect(item.lineTotal, 247800);
      expect(item.hasDiscount, isTrue);
      expect(item.lineSavings, 32200);
      expect(item.optionLabel, '8GB · 512GB');
    });

    test('the address is formatted for display', () {
      final order = Order.fromJson(Map<String, dynamic>.of(_detailPayload));
      final address = order.shippingAddress!;

      expect(address.recipient, 'Abdur Rahman');
      expect(address.formatted, contains('House 12, Road 5'));
      expect(address.formatted, contains('Dhaka 1207'));
      expect(address.formatted, contains('Bangladesh'));
    });

    test('a list row has no items, so it is not a detail', () {
      final order = Order.fromJson(_listPayload());

      expect(order.items, isEmpty);
      expect(order.shippingAddress, isNull);
      expect(order.hasDetail, isFalse);
      expect(order.grandTotal, 247800);
    });

    test('an unrecognised status keeps the label the server sent', () {
      final row = _listPayload(
        status: 'awaiting_pickup',
        statusDisplay: 'Awaiting pickup',
      );

      final order = Order.fromJson(row);

      expect(order.status, OrderStatus.unknown);
      expect(order.statusDisplay, 'Awaiting pickup');
    });

    test('status helpers', () {
      expect(OrderStatus.parse('cancelled').isCancelled, isTrue);
      expect(OrderStatus.parse('delivered').isDelivered, isTrue);
      expect(OrderStatus.parse('delivered').isOpen, isFalse);
      expect(OrderStatus.parse('shipped').isOpen, isTrue);
      expect(OrderStatus.parse(null), OrderStatus.unknown);
    });
  });

  group('OrderProvider history', () {
    test('loads the first page once, then not again without force', () async {
      final service = _FakeOrderService();
      final provider = OrderProvider(service);

      await provider.loadHistory();
      await provider.loadHistory();

      expect(service.historyCalls, 1);
      expect(provider.orders, hasLength(1));
      expect(provider.count, 1);
      expect(provider.isEmpty, isFalse);

      await provider.loadHistory(force: true);
      expect(service.historyCalls, 2);
    });

    test('a failure is reported and leaves the list empty', () async {
      final service = _FakeOrderService()
        ..historyFailure = ApiException(
          message: 'Could not reach the TechZone server.',
          isNetworkError: true,
        );

      final provider = OrderProvider(service);
      await provider.loadHistory();

      expect(provider.historyError, contains('Could not reach'));
      expect(provider.orders, isEmpty);
    });

    test('a stalled history load times out instead of spinning', () async {
      final service = _FakeOrderService()..historyGate = Completer<void>();

      final provider = OrderProvider(
        service,
        placementTimeout: const Duration(milliseconds: 40),
      );

      await provider.loadHistory();

      expect(provider.isLoadingHistory, isFalse);
      expect(provider.historyError, contains('did not answer in time'));
    });

    test('loadMore only runs when the server said there is more', () async {
      final service = _FakeOrderService();
      final provider = OrderProvider(service);

      await provider.loadHistory();
      await provider.loadMore();

      expect(
        service.historyCalls,
        1,
        reason: 'no next page means no second request',
      );
    });
  });

  group('OrderProvider detail', () {
    test('loads a detail and caches it', () async {
      final service = _FakeOrderService();
      final provider = OrderProvider(service);

      await provider.loadDetail('TZ-261018-A4F9C2');
      await provider.loadDetail('TZ-261018-A4F9C2');

      expect(service.detailCalls, 1);
      expect(provider.detail('TZ-261018-A4F9C2')?.hasDetail, isTrue);
    });

    test('a 404 is phrased for the customer, not as a raw error', () async {
      final service = _FakeOrderService()
        ..detailFailure = ApiException(message: 'Not found.', statusCode: 404);

      final provider = OrderProvider(service);
      await provider.loadDetail('TZ-000000-ZZZZZZ');

      expect(
        provider.detailError('TZ-000000-ZZZZZZ'),
        'We could not find that order on your account.',
      );
      expect(provider.detail('TZ-000000-ZZZZZZ'), isNull);
    });
  });

  group('OrderProvider placement', () {
    test('a placed order is returned, cached and put at the top', () async {
      final service = _FakeOrderService();
      final provider = OrderProvider(service);

      final order = await provider.placeOrder();

      expect(order, isNotNull);
      expect(order!.orderNumber, 'TZ-261018-A4F9C2');
      expect(provider.lastPlaced, same(order));
      expect(provider.detail(order.orderNumber), isNotNull);
      expect(provider.orders.first.orderNumber, order.orderNumber);
      expect(provider.isPlacing, isFalse);
    });

    test('an order always carries an idempotency key', () async {
      final service = _FakeOrderService();
      final provider = OrderProvider(service);

      await provider.placeOrder();

      expect(service.keysSeen, hasLength(1));
      expect(service.keysSeen.single, isNotEmpty);
    });

    test('a second submission while one is in flight is refused', () async {
      final service = _FakeOrderService()..gate = Completer<void>();
      final provider = OrderProvider(service);

      final first = provider.placeOrder();

      // The customer taps again before the server has answered.
      final second = await provider.placeOrder();

      expect(second, isNull, reason: 'the second tap must not reach the API');
      expect(service.placeCalls, 1);

      service.gate!.complete();
      expect(await first, isNotNull);
      expect(service.placeCalls, 1);
    });

    test('a retry after an unknown outcome reuses the same key', () async {
      final service = _FakeOrderService()
        ..placeFailure = ApiException(
          message: 'The server stopped responding mid-request.',
          isNetworkError: true,
        );

      final provider = OrderProvider(service);

      expect(await provider.placeOrder(), isNull);
      expect(provider.placeError, contains('stopped responding'));

      // The outcome of the first attempt is unknown, so the retry must be
      // the *same* request as far as the server is concerned.
      service.placeFailure = null;
      final order = await provider.placeOrder();

      expect(order, isNotNull);
      expect(service.keysSeen, hasLength(2));
      expect(service.keysSeen[0], service.keysSeen[1]);
    });

    test('a rejected order starts a fresh key next time', () async {
      final service = _FakeOrderService()
        ..placeFailure = ApiException(
          message: 'Your cart is empty.',
          statusCode: 400,
          fieldErrors: const {'cart': 'Your cart is empty.'},
        );

      final provider = OrderProvider(service);

      expect(await provider.placeOrder(), isNull);
      expect(provider.placeError, 'Your cart is empty.');
      expect(provider.placeFieldErrors['cart'], 'Your cart is empty.');

      // A 400 means the server wrote nothing, so the next attempt is new.
      service.placeFailure = null;
      await provider.placeOrder();

      expect(service.keysSeen, hasLength(2));
      expect(service.keysSeen[0], isNot(service.keysSeen[1]));
    });

    test('the note the customer typed is what gets sent', () async {
      final service = _FakeOrderService();
      final provider = OrderProvider(service);

      await provider.placeOrder(customerNote: 'Leave at reception');

      expect(service.notesSeen.single, 'Leave at reception');
    });

    test('a synchronous fault still frees the button', () async {
      // Regression: the idempotency key used to be generated *outside* the
      // try, so a throw there skipped the finally. isPlacing stayed true, the
      // button stayed on "Placing your order…" for the rest of the session,
      // and no request was ever sent.
      final service = _FakeOrderService()
        ..synchronousFailure = RangeError('max must be in range 0 < max');

      final provider = OrderProvider(service);

      final order = await provider.placeOrder();

      expect(order, isNull);
      expect(
        provider.isPlacing,
        isFalse,
        reason: 'the loading state must always be cleared',
      );
      expect(provider.placeError, isNotNull);
      expect(
        provider.placeError,
        isNot(contains('RangeError')),
        reason: 'customers are not shown exception text',
      );
    });

    test('a timed-out placement frees the button and keeps the key', () async {
      final service = _FakeOrderService()..gate = Completer<void>();

      final provider = OrderProvider(
        service,
        placementTimeout: const Duration(milliseconds: 40),
      );

      final order = await provider.placeOrder();

      expect(order, isNull);
      expect(provider.isPlacing, isFalse);
      expect(provider.placeError, contains('may still have gone through'));

      // Retrying must not be able to create a second order, so the same key
      // goes back out.
      service
        ..gate = null
        ..synchronousFailure = null;

      final retried = await provider.placeOrder();

      expect(retried, isNotNull);
      expect(service.keysSeen, hasLength(2));
      expect(
        service.keysSeen[0],
        service.keysSeen[1],
        reason: 'an unknown outcome must be retried as the same request',
      );
      expect(provider.orders, hasLength(1));
    });

    test('an idempotency key is web-safe and unique', () {
      // `nextInt(1 << 32)` threw RangeError under dart2js, because JavaScript
      // shifts collapse past 31 bits and `1 << 32` is 0 on the web. Keys are
      // built from a literal bound now.
      final keys = {
        for (var i = 0; i < 200; i++) OrderService.newIdempotencyKey(),
      };

      expect(keys, hasLength(200));

      for (final key in keys) {
        expect(key, startsWith('tz-'));
        expect(key.length, lessThanOrEqualTo(64));
        expect(RegExp(r'^[a-z0-9-]+$').hasMatch(key), isTrue);
      }
    });

    test('clearPlaceError wipes the banner', () async {
      final service = _FakeOrderService()
        ..placeFailure = ApiException(message: 'nope', statusCode: 400);

      final provider = OrderProvider(service);
      await provider.placeOrder();
      expect(provider.placeError, isNotNull);

      provider.clearPlaceError();
      expect(provider.placeError, isNull);
      expect(provider.placeFieldErrors, isEmpty);
    });
  });

  group('OrderProvider lifecycle', () {
    test('reset drops the previous customer entirely', () async {
      final service = _FakeOrderService();
      final provider = OrderProvider(service);

      await provider.loadHistory();
      await provider.placeOrder();
      expect(provider.orders, isNotEmpty);

      provider.reset();

      expect(provider.orders, isEmpty);
      expect(provider.count, 0);
      expect(provider.lastPlaced, isNull);
      expect(provider.hasLoadedHistory, isFalse);
      expect(provider.detail('TZ-261018-A4F9C2'), isNull);
    });

    test('a request landing after disposal does not throw', () async {
      final service = _FakeOrderService()..gate = Completer<void>();
      final provider = OrderProvider(service);

      final pending = provider.placeOrder();

      // The screen is torn down while the order is still in flight.
      provider.dispose();
      service.gate!.complete();

      await expectLater(pending, completes);
    });
  });
}
