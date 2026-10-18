import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/network/api_exception.dart';
import '../models/order.dart';
import '../services/order_service.dart';

/// Owns order placement and the customer's order history.
///
/// Nothing here is optimistic. An order exists only once the server has
/// confirmed it and returned an order number; until then the checkout screen
/// shows progress, not success.
///
/// The disposal guard follows the same pattern as the other providers in this
/// app: an in-flight request that lands after the widget tree has let go of
/// the provider must not call [notifyListeners].
class OrderProvider extends ChangeNotifier {
  OrderProvider(this._service, {Duration? placementTimeout})
    : _placementTimeout = placementTimeout ?? defaultPlacementTimeout;

  final OrderService _service;

  /// Outer ceiling on one placement attempt.
  ///
  /// Dio already applies [AppConfig.connectTimeout] and
  /// [AppConfig.receiveTimeout], but those cover the HTTP exchange only. This
  /// is the backstop for everything else: whatever stalls, the button comes
  /// back and the customer is told what to do.
  static final Duration defaultPlacementTimeout =
      AppConfig.connectTimeout +
      AppConfig.receiveTimeout +
      const Duration(seconds: 10);

  /// The same backstop for the read calls, so a stalled request cannot leave
  /// "Loading your orders…" on screen forever either.
  static final Duration defaultReadTimeout =
      AppConfig.connectTimeout + AppConfig.receiveTimeout;

  final Duration _placementTimeout;

  Duration get _readTimeout => _placementTimeout == defaultPlacementTimeout
      ? defaultReadTimeout
      : _placementTimeout;

  static const String _timedOutMessage =
      'The server did not answer in time. Please check your connection and '
      'try again.';

  bool _disposed = false;

  // ----------------------------------------------------------- history state

  List<Order> _orders = const [];
  bool _loadingHistory = false;
  bool _loadingMore = false;
  String? _historyError;
  int _count = 0;
  bool _hasNext = false;
  int _page = 1;
  bool _historyLoadedOnce = false;

  // ------------------------------------------------------------ detail state

  final Map<String, Order> _details = <String, Order>{};
  final Set<String> _detailLoading = <String>{};
  final Map<String, String> _detailErrors = <String, String>{};

  // --------------------------------------------------------- placement state

  bool _placing = false;
  String? _placeError;
  Map<String, String> _placeFieldErrors = const {};
  Order? _lastPlaced;

  /// The idempotency key for the checkout attempt in progress.
  ///
  /// Deliberately kept across a *failed* attempt whose outcome is unknown (a
  /// timeout, a 5xx), so pressing "Try again" resends the same key and the
  /// server returns the order it may already have created instead of making
  /// a second one. Cleared after a success, and after a 400, because a 400
  /// means nothing was written.
  String? _pendingKey;

  // ------------------------------------------------------------------ getters

  List<Order> get orders => _orders;
  bool get isLoadingHistory => _loadingHistory;
  bool get isLoadingMore => _loadingMore;
  String? get historyError => _historyError;
  int get count => _count;
  bool get hasMore => _hasNext;
  bool get isEmpty => _orders.isEmpty;
  bool get hasLoadedHistory => _historyLoadedOnce;

  bool get isPlacing => _placing;
  String? get placeError => _placeError;
  Map<String, String> get placeFieldErrors => _placeFieldErrors;
  Order? get lastPlaced => _lastPlaced;

  Order? detail(String orderNumber) => _details[orderNumber];
  bool isLoadingDetail(String orderNumber) =>
      _detailLoading.contains(orderNumber);
  String? detailError(String orderNumber) => _detailErrors[orderNumber];

  // ------------------------------------------------------------------ history

  /// Loads the first page of the customer's orders.
  ///
  /// Repeat calls are cheap: already loaded and not forced means no request.
  Future<void> loadHistory({bool force = false}) async {
    if (_loadingHistory) return;
    if (_historyLoadedOnce && !force) return;

    _loadingHistory = true;
    _historyError = null;
    _notify();

    try {
      final page = await _service.fetchOrders(page: 1).timeout(_readTimeout);
      _orders = page.items;
      _count = page.count;
      _hasNext = page.hasNext;
      _page = 1;
      _historyLoadedOnce = true;
    } on ApiException catch (error) {
      _historyError = error.message;
    } on TimeoutException {
      _historyError = _timedOutMessage;
    } catch (error, stack) {
      debugPrint('Order history failed unexpectedly: $error\n$stack');
      _historyError = 'We could not load your orders. Please try again.';
    } finally {
      _loadingHistory = false;
      _notify();
    }
  }

  /// Appends the next page, for the "Load more orders" button.
  Future<void> loadMore() async {
    if (_loadingMore || _loadingHistory || !_hasNext) return;

    _loadingMore = true;
    _notify();

    try {
      final page = await _service
          .fetchOrders(page: _page + 1)
          .timeout(_readTimeout);
      _orders = [..._orders, ...page.items];
      _count = page.count;
      _hasNext = page.hasNext;
      _page += 1;
    } on ApiException catch (error) {
      _historyError = error.message;
    } on TimeoutException {
      _historyError = _timedOutMessage;
    } catch (error, stack) {
      debugPrint('Loading more orders failed unexpectedly: $error\n$stack');
      _historyError = 'We could not load more orders. Please try again.';
    } finally {
      _loadingMore = false;
      _notify();
    }
  }

  // ------------------------------------------------------------------- detail

  /// Loads one order in full. The list payload carries no items or address,
  /// so a history row always needs this before it can be shown in detail.
  Future<void> loadDetail(String orderNumber, {bool force = false}) async {
    if (orderNumber.isEmpty) return;
    if (_detailLoading.contains(orderNumber)) return;

    final cached = _details[orderNumber];
    if (cached != null && cached.hasDetail && !force) return;

    _detailLoading.add(orderNumber);
    _detailErrors.remove(orderNumber);
    _notify();

    try {
      final order = await _service
          .fetchOrder(orderNumber)
          .timeout(_readTimeout);
      _details[orderNumber] = order;
      _replaceInHistory(order);
    } on ApiException catch (error) {
      _detailErrors[orderNumber] = error.isNotFound
          ? 'We could not find that order on your account.'
          : error.message;
    } on TimeoutException {
      _detailErrors[orderNumber] = _timedOutMessage;
    } catch (error, stack) {
      debugPrint('Order detail failed unexpectedly: $error\n$stack');
      _detailErrors[orderNumber] =
          'We could not load that order. Please try again.';
    } finally {
      _detailLoading.remove(orderNumber);
      _notify();
    }
  }

  // ---------------------------------------------------------------- placement

  /// Places the cart as an order and returns it, or null on failure.
  ///
  /// Guards against a second submission three ways: the [_placing] flag stops
  /// a second tap reaching the network at all; the idempotency key stops a
  /// retry creating a second order; and the server empties the cart inside the
  /// same transaction, so a request that gets through anyway finds nothing to
  /// order.
  Future<Order?> placeOrder({String customerNote = ''}) async {
    if (_placing) return null;

    _placing = true;
    _placeError = null;
    _placeFieldErrors = const {};
    _notify();

    try {
      // Generated inside the try deliberately. Anything that throws between
      // setting the flag and getting an answer — including this line, which
      // used to sit outside the try and once left the button disabled for
      // the rest of the session — must still reach the finally below.
      final key = _pendingKey ??= OrderService.newIdempotencyKey();

      final order = await _service
          .placeOrder(idempotencyKey: key, customerNote: customerNote)
          .timeout(_placementTimeout);

      _lastPlaced = order;
      _details[order.orderNumber] = order;

      _orders = [
        order,
        ..._orders.where((row) => row.orderNumber != order.orderNumber),
      ];
      _count = _orders.length > _count ? _orders.length : _count;

      // That attempt is finished; the next checkout is a new one.
      _pendingKey = null;

      return order;
    } on ApiException catch (error) {
      _placeError = error.message;
      _placeFieldErrors = error.fieldErrors;

      // A 400 is a rejection, not an unknown outcome: the server wrote
      // nothing, so the next attempt may safely use a fresh key.
      if (error.statusCode == 400) {
        _pendingKey = null;
      }

      return null;
    } on TimeoutException {
      // The outcome is genuinely unknown — the order may already be written.
      // _pendingKey is kept on purpose: pressing Place order again resends
      // the same key, and the server answers with the order it already has
      // rather than writing a second one.
      _placeError =
          'The server did not answer in time. Your order may still have gone '
          'through — press Place order again to check. You will not be '
          'charged twice or given two orders.';

      return null;
    } catch (error, stack) {
      // A fault on this device, not a rejection by the server. Without this
      // the exception would vanish into an unhandled async error and the
      // customer would be left staring at a spinner.
      debugPrint('Order placement failed unexpectedly: $error\n$stack');

      _placeError =
          'Something went wrong on this device while placing your order. '
          'Please try again.';

      return null;
    } finally {
      _placing = false;
      _notify();
    }
  }

  void clearPlaceError() {
    if (_placeError == null && _placeFieldErrors.isEmpty) return;
    _placeError = null;
    _placeFieldErrors = const {};
    _notify();
  }

  /// Drops every trace of the previous customer on sign-out.
  void reset() {
    _orders = const [];
    _loadingHistory = false;
    _loadingMore = false;
    _historyError = null;
    _count = 0;
    _hasNext = false;
    _page = 1;
    _historyLoadedOnce = false;
    _details.clear();
    _detailLoading.clear();
    _detailErrors.clear();
    _placing = false;
    _placeError = null;
    _placeFieldErrors = const {};
    _lastPlaced = null;
    _pendingKey = null;
    _notify();
  }

  // ------------------------------------------------------------------ private

  /// Keeps a history row in step with a freshly fetched detail payload.
  void _replaceInHistory(Order order) {
    final index = _orders.indexWhere(
      (row) => row.orderNumber == order.orderNumber,
    );

    if (index < 0) return;

    final next = [..._orders];
    next[index] = order;
    _orders = next;
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
