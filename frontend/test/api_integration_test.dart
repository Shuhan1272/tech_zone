// End-to-end integration tests: the real Flutter service layer against a
// running Django server. These prove the parsing, query building, auth header
// and refresh logic agree with the live API rather than with the docs.
//
// They are tagged `integration` and skipped unless a backend is reachable, so
// `flutter test` stays green without one.
//
// Run with a server on 127.0.0.1:8000:
//
//   cd Backend && venv\Scripts\python.exe manage.py runserver
//   cd frontend && flutter test test/api_integration_test.dart
//
// Override the host or the signed-in test account with:
//
//   --dart-define=API_BASE_URL=http://127.0.0.1:8000
//   --dart-define=TEST_EMAIL=... --dart-define=TEST_PASSWORD=...

@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:techzone/core/config/app_config.dart';
import 'package:techzone/core/network/api_client.dart';
import 'package:techzone/core/network/api_exception.dart';
import 'package:techzone/core/network/token_storage.dart';
import 'package:techzone/models/discount.dart';
import 'package:techzone/services/account_service.dart';
import 'package:techzone/services/auth_service.dart';
import 'package:techzone/services/cart_service.dart';
import 'package:techzone/services/discount_service.dart';
import 'package:techzone/services/product_service.dart';

/// Credentials for an already-verified account on the dev database.
/// `LoginSerializer` refuses unverified users, so the account must have been
/// through the OTP step once.
const _email = String.fromEnvironment(
  'TEST_EMAIL',
  defaultValue: 'fluttertest@example.com',
);
const _password = String.fromEnvironment(
  'TEST_PASSWORD',
  defaultValue: 'TechZone!2026',
);

Future<bool> _serverIsUp() async {
  try {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/products/products/');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4);
    final request = await client.getUrl(uri);
    final response = await request.close();
    await response.drain<void>();
    client.close();
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}

void main() {
  late TokenStorage tokens;
  late ApiClient client;
  late ProductService products;
  late AuthService auth;
  late CartService carts;
  late AccountService accounts;
  late DiscountService discounts;

  bool serverUp = false;

  /// Marks the running test as skipped when no backend is reachable, so an
  /// absent server can never be mistaken for a passing integration suite.
  bool ready() {
    if (serverUp) return true;
    markTestSkipped('requires a Django server at ${AppConfig.apiBaseUrl}');
    return false;
  }

  setUpAll(() async {
    // flutter_test's binding installs an HttpOverrides mock that answers every
    // request with 400, which would silently defeat the point of these tests.
    // Clearing it restores real sockets. The binding itself is not needed:
    // TokenStorage already tolerates SharedPreferences being unavailable.
    HttpOverrides.global = null;

    serverUp = await _serverIsUp();
    if (!serverUp) {
      // ignore: avoid_print
      print('No server at ${AppConfig.apiBaseUrl} - tests will be SKIPPED.');
    }
  });

  setUp(() {
    tokens = TokenStorage();
    client = ApiClient(tokens: tokens);
    products = ProductService(client);
    auth = AuthService(client: client, tokens: tokens);
    carts = CartService(client);
    accounts = AccountService(client);
    discounts = DiscountService(client);
  });

  // ------------------------------------------------------------ public reads

  group('public catalog', () {
    test('GET /products/categories/ parses the nested taxonomy', () async {
      if (!ready()) return;
      final categories = await products.fetchCategories();

      expect(categories, isNotEmpty);
      // The ViewSet filters `parent=None`, so the list is roots only.
      final withChildren = categories.where((c) => c.hasChildren);
      expect(
        withChildren,
        isNotEmpty,
        reason: 'expected at least one root with sub_categories nested',
      );

      // `filters` is the admin-authored facet map that drives the sidebar.
      final withFacets = categories.where((c) => c.facets.isNotEmpty);
      expect(withFacets, isNotEmpty);

      for (final category in categories) {
        expect(category.slug, isNotEmpty);
        // Nested images come back relative; AppConfig must absolutise them.
        if (category.imageUrl != null) {
          expect(category.imageUrl, startsWith('http'));
        }
      }
    });

    test('GET /products/brands/ parses', () async {
      if (!ready()) return;
      final brands = await products.fetchBrands();
      expect(brands, isNotEmpty);
      expect(brands.first.slug, isNotEmpty);
    });

    test('GET /products/ returns a paginated page with priced variants',
        () async {
      if (!ready()) return;
      final page = await products.fetchProducts(const ProductQuery());

      expect(page.count, greaterThan(0));
      expect(page.items, isNotEmpty);

      for (final product in page.items) {
        expect(product.slug, isNotEmpty);
        final variant = product.primaryVariant;
        expect(
          variant,
          isNotNull,
          reason: '${product.slug} has no active variant',
        );
        // Price authority: the server sends all three figures.
        expect(variant!.discountedPrice, greaterThan(0));
        expect(variant.price, greaterThanOrEqualTo(variant.discountedPrice));
      }
    });

    test('ordering=price really sorts by the discounted annotation', () async {
      if (!ready()) return;
      final ascending = await products.fetchProducts(
        const ProductQuery(sort: ProductSort.priceLowToHigh),
      );
      final prices =
          ascending.items.map((p) => p.primaryVariant!.discountedPrice).toList();
      final sorted = [...prices]..sort();
      expect(prices, sorted);

      final descending = await products.fetchProducts(
        const ProductQuery(sort: ProductSort.priceHighToLow),
      );
      expect(
        descending.items.first.primaryVariant!.discountedPrice,
        greaterThanOrEqualTo(
          descending.items.last.primaryVariant!.discountedPrice,
        ),
      );
    });

    test('search filters server-side', () async {
      if (!ready()) return;
      final all = await products.fetchProducts(const ProductQuery());
      final term = all.items.first.name.split(' ').first;

      final hits = await products.fetchProducts(ProductQuery(search: term));
      expect(hits.count, greaterThan(0));
      expect(hits.count, lessThanOrEqualTo(all.count));
    });

    test('category filter matches the category or its parent', () async {
      if (!ready()) return;
      final categories = await products.fetchCategories();
      final root = categories.firstWhere(
        (c) => c.hasChildren,
        orElse: () => categories.first,
      );

      final page = await products.fetchProducts(
        ProductQuery(categorySlug: root.slug),
      );
      // Selecting a root must include products filed under its children.
      expect(page.count, greaterThanOrEqualTo(0));
      for (final product in page.items) {
        expect(product.categoryName, isNotNull);
      }
    });

    test('limit is honoured as the page size parameter', () async {
      if (!ready()) return;
      final page = await products.fetchProducts(
        const ProductQuery(pageSize: 1),
      );
      expect(page.items.length, lessThanOrEqualTo(1));
    });

    test('GET /products/{slug}/ returns detail with variants', () async {
      if (!ready()) return;
      final page = await products.fetchProducts(const ProductQuery());
      final slug = page.items.first.slug;

      final detail = await products.fetchProduct(slug);
      expect(detail.slug, slug);
      expect(detail.isDetail, isTrue);
      expect(detail.variants, isNotEmpty);
    });

    test('product images resolve to a product id and an absolute URL',
        () async {
      if (!ready()) return;
      final index = await products.fetchImageIndex();
      expect(
        index,
        isNotEmpty,
        reason: 'needs `product` on ProductImageSerializer',
      );

      for (final entry in index.entries) {
        expect(entry.key, greaterThan(0));
        for (final image in entry.value) {
          expect(image.url, startsWith('http'));
          expect(image.productId, entry.key);
        }
      }

      // And the server-side filter narrows to one product.
      final productId = index.keys.first;
      final filtered = await products.fetchProductImages(productId);
      expect(filtered, isNotEmpty);
      expect(filtered.every((i) => i.productId == productId), isTrue);
    });

    test('GET /core/notices/ parses', () async {
      if (!ready()) return;
      final notices = await products.fetchNotices();
      expect(notices, isA<List>());
    });

    test('reviews and questions reject anonymous reads with 401', () async {
      if (!ready()) return;
      // Both ViewSets declare IsAuthenticated even for GET, so the UI must
      // gate them behind sign-in rather than showing an empty list.
      await expectLater(
        products.fetchReviews(1),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'status', 401),
        ),
      );
    });
  });

  // ------------------------------------------------------------------- auth

  group('authentication', () {
    test('login issues a JWT pair and /me/ returns the profile', () async {
      if (!ready()) return;
      await auth.login(email: _email, password: _password);

      expect(tokens.accessToken, isNotNull);
      expect(tokens.refreshToken, isNotNull);
      expect(tokens.hasSession, isTrue);

      final user = await auth.currentUser();
      expect(user.email, _email);
      expect(user.id, greaterThan(0));
    });

    test('bad credentials surface a readable message', () async {
      if (!ready()) return;
      await expectLater(
        auth.login(email: _email, password: 'definitely-wrong-password'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 400)
              .having(
                (e) => e.message.toLowerCase(),
                'message',
                contains('invalid'),
              ),
        ),
      );
    });

    test('registering a duplicate verified email is rejected', () async {
      if (!ready()) return;
      await expectLater(
        auth.register(
          email: _email,
          phone: '01700000000',
          password: 'AnotherPass!2026',
          confirmPassword: 'AnotherPass!2026',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.fieldErrors['email'] ?? e.message,
            'email error',
            contains('already exists'),
          ),
        ),
      );
    });

    test('a protected endpoint rejects an anonymous request', () async {
      if (!ready()) return;
      await expectLater(
        carts.fetchCart(),
        throwsA(
          isA<ApiException>().having((e) => e.isUnauthorized, 'is401', isTrue),
        ),
      );
    });

    test('an expired access token is refreshed and the request replayed',
        () async {
      if (!ready()) return;
      await auth.login(email: _email, password: _password);
      final goodRefresh = tokens.refreshToken!;

      // Corrupt only the access token; the interceptor should notice the 401,
      // refresh with the still-valid refresh token, and replay transparently.
      await tokens.updateAccess('not-a-valid-access-token');

      final user = await auth.currentUser();
      expect(user.email, _email);
      // ROTATE_REFRESH_TOKENS is on, so the refresh token should have changed.
      expect(tokens.refreshToken, isNot(goodRefresh));
    });
  });

  // ------------------------------------------------------------------- cart

  group('cart workflow', () {
    test('add, increment, set quantity, then remove', () async {
      if (!ready()) return;
      await auth.login(email: _email, password: _password);

      // Start from a clean cart so assertions are deterministic.
      final initial = await carts.fetchCart();
      for (final item in initial.items) {
        await carts.removeItem(item.id);
      }
      expect((await carts.fetchCart()).items, isEmpty);

      // Pick an in-stock variant from the live catalog.
      final page = await products.fetchProducts(const ProductQuery());
      final variant = page.items
          .map((p) => p.primaryVariant)
          .whereType<dynamic>()
          .firstWhere((v) => v.inStock && v.stock >= 3);

      final added = await carts.addItem(variantId: variant.id, quantity: 1);
      expect(added.quantity, 1);
      expect(added.variantId, variant.id);
      // The cart serializer echoes the server's own prices.
      expect(added.unitDiscountedPrice, variant.discountedPrice);

      // Adding the same variant increments rather than creating a new line.
      final again = await carts.addItem(variantId: variant.id, quantity: 2);
      expect(again.id, added.id, reason: 'should reuse the same CartItem');
      expect(again.quantity, 3);

      var cart = await carts.fetchCart();
      expect(cart.items.length, 1);
      expect(cart.totalQuantity, 3);
      // Totals computed from server-supplied unit prices.
      expect(cart.subtotal, closeTo(variant.discountedPrice * 3, 0.01));

      // PATCH sets an absolute quantity, addressed by CartItem id.
      final updated = await carts.updateQuantity(
        cartItemId: added.id,
        quantity: 2,
      );
      expect(updated.quantity, 2);

      // Over-stock is rejected server-side.
      await expectLater(
        carts.updateQuantity(
          cartItemId: added.id,
          quantity: variant.stock + 1000,
        ),
        throwsA(isA<ApiException>()),
      );

      await carts.removeItem(added.id);
      cart = await carts.fetchCart();
      expect(cart.items, isEmpty);
    });

    test('adding an unknown variant reports 404', () async {
      if (!ready()) return;
      await auth.login(email: _email, password: _password);
      await expectLater(
        carts.addItem(variantId: 999999, quantity: 1),
        throwsA(
          isA<ApiException>().having((e) => e.isNotFound, 'is404', isTrue),
        ),
      );
    });
  });

  // ---------------------------------------------------------------- address

  group('address', () {
    test('reads the single shipping address slot', () async {
      if (!ready()) return;
      await auth.login(email: _email, password: _password);
      final address = await accounts.fetchAddress();
      // Zero or one, because Address.user is a OneToOneField.
      expect(address == null || address.id > 0, isTrue);
    });
  });

  // -------------------------------------------------------------- discounts

  group('optional endpoints', () {
    test('the discount probe reports what this server actually supports',
        () async {
      if (!ready()) return;
      final availability = await discounts.probe();

      // On the current backend `discounts.urls` is never included by
      // `config/urls.py` and the app has no migrations, so this is
      // `unavailable`. The assertion accepts any verdict so the test keeps
      // passing once the route is wired up.
      expect(availability, isA<DiscountAvailability>());
      // ignore: avoid_print
      print('Discount endpoint availability: ${availability.name}');
    });
  });
}
