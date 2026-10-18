// Render smoke tests.
//
// `flutter analyze` proves the code type-checks; it cannot prove a screen
// actually builds. These pump the real app — real router, real providers, real
// widgets — against a fake Dio adapter that replays payloads captured from the
// live Django API, and assert each route renders without throwing.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techzone/core/network/api_client.dart';
import 'package:techzone/core/network/token_storage.dart';
import 'package:techzone/core/router/app_router.dart';
import 'package:techzone/core/theme/app_theme.dart';
import 'package:techzone/core/utils/responsive.dart';
import 'package:techzone/providers/account_provider.dart';
import 'package:techzone/providers/auth_provider.dart';
import 'package:techzone/providers/cart_provider.dart';
import 'package:techzone/providers/catalog_provider.dart';
import 'package:techzone/providers/order_provider.dart';
import 'package:techzone/services/account_service.dart';
import 'package:techzone/services/auth_service.dart';
import 'package:techzone/services/cart_service.dart';
import 'package:techzone/services/discount_service.dart';
import 'package:techzone/services/order_service.dart';
import 'package:techzone/services/product_service.dart';

// ---------------------------------------------------------------- fixtures
//
// Shapes copied from real responses. Image fields are left empty so
// RemoteImage takes its placeholder branch instead of hitting the network.

const _variant = {
  'id': 1,
  'product': 1,
  'sku': 'msi-cyborg-15-8GB-512GB',
  'options': {'RAM': '8GB', 'Storage': '512GB'},
  'price': '140000.00',
  'discount_percentage': '11.50',
  'discounted_price': 123900.0,
  'saved_price': 16100.0,
  'stock': 5,
  'is_default': true,
  'is_active': true,
};

const _listProduct = {
  'id': 1,
  'name': 'MSI Cyborg 15 A13VE Gaming Laptop',
  'slug': 'msi-cyborg-15',
  'category': 'Desktop → Gaming pc',
  'brand': 'MSI',
  'key_feature': {'Processor': 'Intel Core i5-13420H', 'RAM': '8GB DDR5'},
  'specification': {'Generation': '13th Gen', 'Processor Brand': 'Intel'},
  'colors': ['Black', 'White'],
  'is_active': true,
  'is_featured': true,
  'default_variant': _variant,
};

const _detailProduct = {
  'id': 1,
  'category': 'Desktop → Gaming pc',
  'brand': 'MSI',
  'name': 'MSI Cyborg 15 A13VE Gaming Laptop',
  'slug': 'msi-cyborg-15',
  'description': 'A 15.6 inch 144Hz gaming laptop with an RTX 4050.',
  'specification': {'Generation': '13th Gen', 'Processor Brand': 'Intel'},
  'is_active': true,
  'is_featured': true,
  'variants': [_variant],
};

const _categories = [
  {
    'id': 1,
    'name': 'Desktop',
    'description': '',
    'filters': {
      'Processor': ['Intel', 'AMD'],
      'RAM': ['8 GB', '16 GB'],
    },
    'slug': 'desktop',
    'image': '',
    'brands': [],
    'sub_categories': [
      {
        'id': 2,
        'name': 'Gaming pc',
        'description': '',
        'filters': {},
        'slug': 'gaming-pc',
        'image': '',
        'brands': [
          {'id': 2, 'name': 'MSI', 'slug': 'msi', 'is_active': true},
        ],
        'sub_categories': [],
        'is_active': true,
        'is_featured': false,
      },
    ],
    'is_active': true,
    'is_featured': true,
  },
];

const _brands = [
  {'id': 2, 'name': 'MSI', 'description': '', 'slug': 'msi', 'is_active': true},
];

const _notices = [
  {
    'id': 1,
    'title': 'Eid sale is live',
    'message': 'Up to 23% off selected appliances.',
    'notice_type': 'promotion',
    'is_active': true,
    'is_featured': true,
    'start_at': null,
    'end_at': null,
  },
];

const _user = {
  'id': 10,
  'email': 'tester@example.com',
  'first_name': 'Flutter',
  'last_name': 'Tester',
  'phone': '01712345678',
  'date_joined': '2026-10-14T00:41:01.088162Z',
};

const _cartItem = {
  'id': 5,
  'variant': 1,
  'product_name': 'MSI Cyborg 15 A13VE Gaming Laptop',
  'variant_price': '140000.00',
  'discounted_price': '123900.00',
  'quantity': 2,
};

const _address = {
  'id': 1,
  'first_name': 'Abdur',
  'last_name': 'Rahman',
  'company': '',
  'address1': 'House 12, Road 5',
  'address2': '',
  'city': 'Dhaka',
  'postal_code': '1207',
  'country': 'Bangladesh',
  'region': 'Dhaka',
};

const _orderItem = {
  'id': 1,
  'variant_id': 1,
  'product_name': 'MSI Cyborg 15 A13VE Gaming Laptop',
  'product_slug': 'msi-cyborg-15',
  'variant_sku': 'msi-cyborg-15-8GB-512GB',
  'options': {'RAM': '8GB', 'Storage': '512GB'},
  'unit_price': '140000.00',
  'unit_discount_percentage': '11.50',
  'unit_price_paid': '123900.00',
  'quantity': 2,
  'line_total': '247800.00',
};

/// `OrderDetailSerializer` output. The list endpoint returns the same shape
/// without `items`, `shipping_address` and `customer_note`, and the screens
/// cope with both, so one fixture serves for both here.
const _order = {
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
  'summary': 'MSI Cyborg 15 A13VE Gaming Laptop',
  'placed_at': '2026-10-18T09:15:00Z',
  'items': [_orderItem],
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
  'customer_note': '',
};

/// Replays the fixtures above for whichever path Dio asks for.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({
    this.signedIn = true,
    this.cartItems = const [_cartItem],
    this.orders = const [_order],
  });

  final bool signedIn;
  final List<Map<String, dynamic>> cartItems;
  final List<Map<String, dynamic>> orders;

  /// Paths requested, so a test can assert what the UI actually called.
  final List<String> calls = [];

  /// Every `Idempotency-Key` an order POST arrived with, so a test can prove
  /// the client sends one and reuses it rather than inventing a new key.
  final List<String> placedKeys = [];

  /// The same key as carried in the request *body*. A browser drops any
  /// header the server has not allowed through CORS, so the client sends it
  /// both ways and both are asserted.
  final List<String> placedBodyKeys = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    calls.add('${options.method} $path');

    dynamic body;
    var status = 200;

    if (path.startsWith('/products/categories/')) {
      body = _categories;
    } else if (path.startsWith('/products/brands/')) {
      body = _brands;
    } else if (path.startsWith('/products/product-images/')) {
      body = const <Map<String, dynamic>>[];
    } else if (path.startsWith('/products/variants/')) {
      body = _variant;
    } else if (path == '/products/products/') {
      body = {
        'count': 1,
        'next': null,
        'previous': null,
        'results': [_listProduct],
      };
    } else if (path.startsWith('/products/products/')) {
      body = _detailProduct;
    } else if (path.startsWith('/products/reviews/') ||
        path.startsWith('/products/questions/')) {
      if (!signedIn) {
        status = 401;
        body = {'detail': 'Authentication credentials were not provided.'};
      } else {
        body = const <Map<String, dynamic>>[];
      }
    } else if (path.startsWith('/core/notices/')) {
      body = _notices;
    } else if (path == '/accounts/me/') {
      if (!signedIn) {
        status = 401;
        body = {'detail': 'Authentication credentials were not provided.'};
      } else {
        body = _user;
      }
    } else if (path.startsWith('/accounts/address/')) {
      body = signedIn ? [_address] : <Map<String, dynamic>>[];
      if (!signedIn) status = 401;
    } else if (path == '/cart/') {
      if (!signedIn) {
        status = 401;
        body = {'detail': 'Authentication credentials were not provided.'};
      } else {
        body = {
          'id': 1,
          'items': cartItems,
          'created_at': '2026-10-02T10:30:00Z',
          'updated_at': '2026-10-02T10:35:00Z',
        };
      }
    } else if (path == '/orders/') {
      if (!signedIn) {
        status = 401;
        body = {'detail': 'Authentication credentials were not provided.'};
      } else if (options.method == 'POST') {
        placedKeys.add((options.headers['Idempotency-Key'] ?? '').toString());

        final sent = options.data;
        placedBodyKeys.add(
          sent is Map ? (sent['idempotency_key'] ?? '').toString() : '',
        );

        status = 201;
        body = _order;
      } else {
        body = {
          'count': orders.length,
          'next': null,
          'previous': null,
          'results': orders,
        };
      }
    } else if (path.startsWith('/orders/')) {
      if (!signedIn) {
        status = 401;
        body = {'detail': 'Authentication credentials were not provided.'};
      } else {
        final number = path.substring('/orders/'.length).replaceAll('/', '');

        Map<String, dynamic>? match;
        for (final row in orders) {
          if (row['order_number'] == number) match = row;
        }

        if (match == null) {
          // What the real server answers for somebody else's order too.
          status = 404;
          body = {'detail': 'Not found.'};
        } else {
          body = match;
        }
      }
    } else if (path.startsWith('/discounts/')) {
      // Mirrors the real server: the app is not routed.
      status = 404;
      body = {'detail': 'Not found.'};
    } else {
      status = 404;
      body = {'detail': 'Not found.'};
    }

    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Lets the widget tree finish the work it kicked off on mount.
///
/// Two flutter_test facts shape this:
///
///  * Dio's futures do not progress inside the fake-async zone a `testWidgets`
///    body runs in, so the real event loop has to be given a turn via
///    [WidgetTester.runAsync].
///  * `pumpAndSettle` waits for *all* animations to stop, and a
///    `CircularProgressIndicator` never stops — so a screen that renders one
///    while loading would hang it. Bounded pumps are used instead.
Future<void> _settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Builds the app exactly as `main.dart` does, but over [adapter].
Future<_Harness> _pumpApp(
  WidgetTester tester, {
  bool signedIn = true,
  List<Map<String, dynamic>> cartItems = const [_cartItem],
  List<Map<String, dynamic>> orders = const [_order],
  String location = '/',
  Size surface = const Size(1600, 2600),
}) async {
  // A tall surface so a full page lays out in one pass and any RenderFlex
  // overflow is a genuine layout bug rather than an artifact of a short view.
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(
    signedIn
        ? {
            'techzone.access_token': 'fake-access',
            'techzone.refresh_token': 'fake-refresh',
          }
        : {},
  );

  final adapter = _FakeAdapter(
    signedIn: signedIn,
    cartItems: cartItems,
    orders: orders,
  );
  final tokens = TokenStorage();
  final dio = Dio()
    ..httpClientAdapter = adapter
    // Dio's default BackgroundTransformer decodes JSON in an isolate via
    // compute(), which never completes inside flutter_test's fake-async zone,
    // so pumpAndSettle would spin forever. Decoding synchronously is also what
    // actually happens on Flutter Web, where compute() has no isolate.
    ..transformer = SyncTransformer();
  final client = ApiClient(tokens: tokens, dio: dio);

  final productService = ProductService(client);
  final authService = AuthService(client: client, tokens: tokens);
  final cartService = CartService(client);
  final accountService = AccountService(client);
  final discountService = DiscountService(client);
  final orderService = OrderService(client);

  final auth = AuthProvider(service: authService, tokens: tokens);
  final catalog = CatalogProvider(productService);
  final cart = CartProvider(
    cartService: cartService,
    productService: productService,
    discountService: discountService,
  );
  final account = AccountProvider(accountService);
  final orderProvider = OrderProvider(orderService);

  // Dio needs the real event loop; see _settle.
  await tester.runAsync(() async {
    await auth.bootstrap();
    await catalog.load();
    if (auth.isSignedIn) {
      await cart.load();
      await account.load();
    }
  });

  final router = AppRouter(auth);
  router.router.go(location);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: client),
        Provider<ProductService>.value(value: productService),
        Provider<AuthService>.value(value: authService),
        Provider<CartService>.value(value: cartService),
        Provider<DiscountService>.value(value: discountService),
        Provider<AccountService>.value(value: accountService),
        Provider<OrderService>.value(value: orderService),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<CatalogProvider>.value(value: catalog),
        ChangeNotifierProvider<CartProvider>.value(value: cart),
        ChangeNotifierProvider<AccountProvider>.value(value: account),
        ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router.router,
      ),
    ),
  );
  await _settle(tester);

  return _Harness(
    adapter: adapter,
    auth: auth,
    cart: cart,
    orders: orderProvider,
  );
}

class _Harness {
  _Harness({
    required this.adapter,
    required this.auth,
    required this.cart,
    required this.orders,
  });

  final _FakeAdapter adapter;
  final AuthProvider auth;
  final CartProvider cart;
  final OrderProvider orders;
}

void main() {
  testWidgets('home renders the hero, notices, categories and products', (
    tester,
  ) async {
    final harness = await _pumpApp(tester);

    expect(find.text('TechZone'), findsWidgets);
    // This surface is desktop width, where the banner is the supplied
    // artwork: its copy is pixels, and the call to action is a labelled
    // hotspot laid over it.
    expect(find.bySemanticsLabel('Shop all products'), findsOneWidget);
    // Notice banner from /core/notices/.
    expect(find.text('Eid sale is live'), findsOneWidget);
    // Category tile from /products/categories/.
    expect(find.text('Desktop'), findsWidgets);
    // Product card, with the server's discounted price.
    expect(find.textContaining('MSI Cyborg 15'), findsWidgets);
    expect(find.textContaining('123,900'), findsWidgets);
    // The strike-through list price is shown too.
    expect(find.textContaining('140,000'), findsWidgets);

    expect(harness.adapter.calls, contains('GET /products/categories/'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog renders filters, sort controls and the grid', (
    tester,
  ) async {
    await _pumpApp(tester, location: '/catalog');

    expect(find.text('All products'), findsWidgets);
    expect(find.text('Sort by'), findsOneWidget);
    expect(find.text('Per page'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);
    // Brand facet from /products/brands/.
    expect(find.text('MSI'), findsWidgets);
    expect(find.textContaining('1 product'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog shows the specification facets of a category', (
    tester,
  ) async {
    await _pumpApp(tester, location: '/catalog?category=desktop');

    // Facet groups come from Category.filters.
    expect(find.text('Processor'), findsWidgets);
    expect(find.text('RAM'), findsWidgets);
    expect(find.text('Intel'), findsWidgets);
    expect(find.text('16 GB'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product detail renders price, variant, specs and tabs', (
    tester,
  ) async {
    await _pumpApp(tester, location: '/product/msi-cyborg-15');

    expect(find.textContaining('MSI Cyborg 15'), findsWidgets);
    expect(find.textContaining('123,900'), findsWidgets);
    // Server-computed saving, not a local calculation.
    expect(find.textContaining('16,100'), findsWidgets);
    expect(find.text('11.5% off'), findsWidgets);
    expect(find.textContaining('5 in stock'), findsOneWidget);
    expect(find.text('Add to cart'), findsWidgets);

    // Tabs.
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Specification'), findsOneWidget);
    expect(find.textContaining('Reviews'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cart renders lines and a total summed from server prices', (
    tester,
  ) async {
    await _pumpApp(tester, location: '/cart');

    // The footer links "Your cart" too, so scope to the page heading.
    expect(
      find.descendant(
        of: find.byType(PageContainer),
        matching: find.text('Your cart'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('MSI Cyborg 15'), findsWidgets);
    expect(find.text('Order summary'), findsOneWidget);
    // 123900 x 2 = 247800
    expect(find.textContaining('247,800'), findsWidgets);
    expect(find.text('Proceed to checkout'), findsOneWidget);
    // Shipping is stated as zero rather than left out, so the customer is not
    // left wondering what delivery costs.
    expect(find.text('Shipping'), findsOneWidget);
    // Coupons are unavailable on this backend and must say so rather than
    // offering a code box that cannot work.
    expect(find.text('Coupons Coming Soon'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty cart renders its empty state', (tester) async {
    await _pumpApp(tester, location: '/cart', cartItems: const []);

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('Start shopping'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout offers cash on delivery with a live Place order', (
    tester,
  ) async {
    await _pumpApp(tester, location: '/checkout');

    expect(find.text('Checkout'), findsOneWidget);
    expect(find.text('Delivery address'), findsOneWidget);
    // The saved address is shown.
    expect(find.textContaining('House 12, Road 5'), findsWidgets);

    // Cash on delivery, stated as the only method and as unpaid-for-now.
    expect(find.text('Cash on Delivery'), findsOneWidget);
    expect(find.text('Online payment is not available yet.'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.textContaining('Place order'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      button.onPressed,
      isNotNull,
      reason: 'the order API is routed, so the button must work',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('placing an order posts once, with an idempotency key', (
    tester,
  ) async {
    final harness = await _pumpApp(tester, location: '/checkout');

    await tester.tap(find.textContaining('Place order'));
    await _settle(tester);

    // Exactly one POST, carrying a key.
    expect(
      harness.adapter.calls.where((call) => call == 'POST /orders/').length,
      1,
    );
    expect(harness.adapter.placedKeys, hasLength(1));
    expect(harness.adapter.placedKeys.single, isNotEmpty);

    // And the same key in the body, so the guarantee survives a server whose
    // CORS configuration does not let the header through.
    expect(
      harness.adapter.placedBodyKeys.single,
      harness.adapter.placedKeys.single,
    );

    // The order number came back and the app moved to the order.
    expect(harness.orders.lastPlaced?.orderNumber, 'TZ-261018-A4F9C2');
    expect(find.text('TZ-261018-A4F9C2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('order history lists the orders the server returned', (
    tester,
  ) async {
    await _pumpApp(tester, location: '/account/orders');

    expect(find.text('Your orders'), findsOneWidget);
    expect(find.text('TZ-261018-A4F9C2'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    // The server's total, shown as whole taka.
    expect(find.textContaining('247,800'), findsWidgets);
    expect(find.text('View details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('order history renders an empty state with no orders', (
    tester,
  ) async {
    await _pumpApp(tester, location: '/account/orders', orders: const []);

    expect(find.text('No orders yet'), findsOneWidget);
    expect(find.text('Browse products'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('order detail shows items, totals and the delivery address', (
    tester,
  ) async {
    await _pumpApp(tester, location: '/account/orders/TZ-261018-A4F9C2');

    expect(find.text('TZ-261018-A4F9C2'), findsOneWidget);
    expect(find.textContaining('MSI Cyborg 15'), findsWidgets);
    // Payment state is stated honestly: cash on delivery, not yet paid.
    expect(find.text('Cash on Delivery · Unpaid'), findsOneWidget);
    // Shipping is shown even at zero.
    expect(find.text('Shipping'), findsOneWidget);
    expect(find.textContaining('247,800'), findsWidgets);
    // The address snapshot.
    expect(find.text('Abdur Rahman'), findsWidgets);
    expect(find.textContaining('House 12, Road 5'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an order number that is not the customer\'s shows not found', (
    tester,
  ) async {
    await _pumpApp(tester, location: '/account/orders/TZ-000000-ZZZZZZ');

    expect(find.text('Order not available'), findsOneWidget);
    expect(find.text('All orders'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cart redirects a signed-out visitor to a sign-in prompt', (
    tester,
  ) async {
    await _pumpApp(tester, signedIn: false, location: '/cart');

    expect(find.text('Sign in to see your cart'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a protected route redirects a signed-out visitor to login', (
    tester,
  ) async {
    await _pumpApp(tester, signedIn: false, location: '/account');

    // AppRouter.redirect sends /account to /login?next=…
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login validates before calling the API', (tester) async {
    final harness = await _pumpApp(tester, signedIn: false, location: '/login');

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await _settle(tester, rounds: 3);

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(
      harness.adapter.calls.where((c) => c.contains('/accounts/token/')),
      isEmpty,
      reason: 'must not hit the API with an invalid form',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('register enforces matching passwords locally', (tester) async {
    await _pumpApp(tester, signedIn: false, location: '/register');

    expect(find.text('Create your account'), findsOneWidget);
    // No Student/Faculty role picker: TechZone has no such concept.
    expect(find.textContaining('Student'), findsNothing);
    expect(find.textContaining('Faculty'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'someone@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone number'),
      '01712345678',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'First name'),
      'Test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Last name'),
      'User',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'StrongPass!2026',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'DifferentPass!2026',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await _settle(tester, rounds: 3);

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account renders the profile and links to order history', (
    tester,
  ) async {
    await _pumpApp(tester, location: '/account');

    // The footer links "My profile" too.
    expect(find.text('My profile'), findsWidgets);
    expect(find.text('Flutter Tester'), findsWidgets);
    expect(find.text('tester@example.com'), findsWidgets);

    // Order history is a working link now, not a disabled placeholder.
    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Order history'),
        matching: find.byType(ListTile),
      ),
    );
    expect(tile.onTap, isNotNull);
    expect(find.text('Order history unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('address form is seeded from the saved address', (tester) async {
    await _pumpApp(tester, location: '/account/address');

    expect(find.text('Shipping address'), findsWidgets);
    expect(find.text('House 12, Road 5'), findsWidgets);
    expect(find.text('Dhaka'), findsWidgets);
    expect(find.text('Update address'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forgot-password starts on the request-code step', (
    tester,
  ) async {
    await _pumpApp(tester, signedIn: false, location: '/forgot-password');

    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Send reset code'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unknown route renders the not-found page', (tester) async {
    await _pumpApp(tester, location: '/no-such-page');

    expect(find.text('Page not found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home lays out at phone width without overflow', (tester) async {
    await _pumpApp(tester, surface: const Size(390, 3600));

    // The mobile layout swaps the category bar for a drawer button.
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    expect(find.text('Upgrade Your\nEveryday Tech'), findsOneWidget);
    // takeException catches RenderFlex overflow errors.
    expect(tester.takeException(), isNull);
  });
}
