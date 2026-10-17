// Screen-scoped providers are disposed the instant the customer navigates
// away, while the fetches they started are still in flight. When one of those
// fetches lands it notifies its listeners, and ChangeNotifier.notifyListeners
// throws once the notifier has been disposed:
//
//   A ProductDetailProvider was used after being disposed.
//
// The screens start these loads without awaiting them, so the throw surfaces
// as an unhandled framework error rather than a caught one. These tests pin
// the behaviour down: a load that lands after disposal must finish quietly.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:techzone/core/network/api_client.dart';
import 'package:techzone/core/network/api_exception.dart';
import 'package:techzone/core/network/token_storage.dart';
import 'package:techzone/models/paginated.dart';
import 'package:techzone/models/product.dart';
import 'package:techzone/providers/catalog_provider.dart';
import 'package:techzone/providers/product_detail_provider.dart';
import 'package:techzone/services/product_service.dart';

/// A service whose requests hang until the test releases them, which is the
/// window the real bug lives in: between navigating away and the response
/// arriving.
class _PendingService extends ProductService {
  _PendingService() : super(ApiClient(tokens: TokenStorage()));

  final Completer<void> gate = Completer<void>();

  int productCalls = 0;
  int listCalls = 0;

  @override
  Future<Product> fetchProduct(String slug) async {
    productCalls++;
    await gate.future;
    throw ApiException(message: 'gone', statusCode: 404);
  }

  @override
  Future<Paginated<Product>> fetchProducts(ProductQuery query) async {
    listCalls++;
    await gate.future;
    throw ApiException(message: 'gone', statusCode: 404);
  }

  @override
  Future<List<ProductImage>> fetchProductImages(int productId) async =>
      const [];

  @override
  Future<List<ProductReview>> fetchReviews(int productId) async => const [];

  @override
  Future<List<ProductQuestion>> fetchQuestions(int productId) async => const [];
}

void main() {
  test(
    'ProductDetailProvider survives being disposed while its load is in flight',
    () async {
      final service = _PendingService();
      final provider = ProductDetailProvider(service);

      final pending = provider.load('some-product', isSignedIn: false);
      expect(
        service.productCalls,
        1,
        reason: 'the request should be in flight',
      );

      // The customer navigates away: the screen's dispose() runs now.
      provider.dispose();

      // The response finally arrives.
      service.gate.complete();

      await expectLater(
        pending,
        completes,
        reason: 'a response landing after disposal must not throw',
      );
    },
  );

  test(
    'ProductListProvider survives being disposed while its fetch is in flight',
    () async {
      final service = _PendingService();
      final provider = ProductListProvider(service);

      final pending = provider.applyQuery(const ProductQuery());
      expect(service.listCalls, 1, reason: 'the request should be in flight');

      provider.dispose();
      service.gate.complete();

      await expectLater(
        pending,
        completes,
        reason: 'a response landing after disposal must not throw',
      );
    },
  );

  test(
    'ProductListProvider survives disposal during a silent background refresh',
    () async {
      final service = _PendingService();
      final provider = ProductListProvider(service);

      final pending = provider.refreshSilently();
      expect(service.listCalls, 1);

      provider.dispose();
      service.gate.complete();

      await expectLater(pending, completes);
    },
  );

  test('a disposed provider stops notifying its listeners', () async {
    final service = _PendingService();
    final provider = ProductListProvider(service);

    var notifications = 0;
    void listener() => notifications++;
    provider.addListener(listener);

    final pending = provider.applyQuery(const ProductQuery());
    final beforeDisposal = notifications;
    expect(
      beforeDisposal,
      greaterThan(0),
      reason: 'the fetch should notify once when it starts',
    );

    provider.removeListener(listener);
    provider.dispose();
    service.gate.complete();
    await pending;

    expect(
      notifications,
      beforeDisposal,
      reason: 'nothing should be delivered after disposal',
    );
  });
}
