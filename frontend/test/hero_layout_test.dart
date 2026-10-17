// The hero is a two-column banner on desktop and a stacked one below that.
// Both arrangements carry a headline, two CTAs, a product collage and three
// feature cards, so they have plenty of room to overflow at an awkward width.
// These tests pump the real widgets at each breakpoint and fail on any
// overflow, which is the failure mode a layout change actually has.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:techzone/core/network/api_client.dart';
import 'package:techzone/core/network/token_storage.dart';
import 'package:techzone/core/theme/app_theme.dart';
import 'package:techzone/models/catalog.dart';
import 'package:techzone/models/paginated.dart';
import 'package:techzone/models/product.dart';
import 'package:techzone/providers/catalog_provider.dart';
import 'package:techzone/screens/home/home_screen.dart';
import 'package:techzone/services/product_service.dart';

/// Serves a small, fixed catalogue so the hero has real products to show.
class _StubService extends ProductService {
  _StubService({this.hangProducts = false})
    : super(ApiClient(tokens: TokenStorage()));

  /// Leaves the product request pending, for the state before the first
  /// response lands.
  final bool hangProducts;

  static final products = <Product>[
    for (var i = 1; i <= 3; i++)
      Product(
        id: i,
        name: 'Showcase product $i with a deliberately long name',
        slug: 'showcase-$i',
        variants: [
          ProductVariant(
            id: i,
            productId: i,
            sku: 'sku-$i',
            price: 123456,
            discountedPrice: 111110,
            savedPrice: 12346,
            discountPercentage: 10,
            stock: 5,
            isDefault: true,
          ),
        ],
      ),
  ];

  @override
  Future<List<Category>> fetchCategories({bool? featured}) async => const [];

  @override
  Future<List<Brand>> fetchBrands({String? categorySlug}) async => const [];

  @override
  Future<List<Notice>> fetchNotices({bool activeOnly = true}) async => const [];

  @override
  Future<Map<int, List<ProductImage>>> fetchImageIndex() async => {
    for (final product in products)
      product.id: [
        ProductImage(
          id: product.id,
          productId: product.id,
          // Never fetched: the test binding answers image requests with 400,
          // so RemoteImage falls back to its placeholder either way.
          url: 'http://127.0.0.1:8000/media/products/p${product.id}.webp',
          isPrimary: true,
        ),
      ],
  };

  @override
  Future<Paginated<Product>> fetchProducts(ProductQuery query) {
    if (hangProducts) return Completer<Paginated<Product>>().future;
    return Future.value(
      Paginated<Product>(items: products, count: products.length),
    );
  }
}

Future<void> _pumpHome(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final service = _StubService();
  final catalog = CatalogProvider(service);
  addTearDown(catalog.dispose);
  await catalog.load();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ProductService>.value(value: service),
        ChangeNotifierProvider<CatalogProvider>.value(value: catalog),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        // AppShell gives the page its scroll view in the real app;
        // without one here a tall page reports a bottom overflow
        // the shell would never produce.
        home: const Scaffold(body: SingleChildScrollView(child: HomeScreen())),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  const breakpoints = <String, Size>{
    'phone': Size(390, 1600),
    'large phone': Size(430, 1600),
    'tablet': Size(820, 1600),
    'small desktop': Size(1024, 1400),
    'desktop': Size(1440, 1400),
    'wide': Size(1920, 1400),
  };

  breakpoints.forEach((label, size) {
    testWidgets('the hero lays out without overflow on $label', (tester) async {
      await _pumpHome(tester, size);

      // Over 1024 the banner is the supplied artwork, which carries its copy
      // as pixels; under it the same banner is built from widgets.
      if (size.width > 1024) {
        for (final label in const [
          'Shop all products',
          'See featured',
          'Live stock — straight from the warehouse',
        ]) {
          expect(find.bySemanticsLabel(label), findsOneWidget);
        }
      } else {
        expect(find.text('Upgrade Your\nEveryday Tech'), findsOneWidget);
        expect(find.text('Shop all products'), findsOneWidget);
        expect(find.text('See featured'), findsOneWidget);

        // The three feature cards survive every arrangement.
        expect(find.text('Live stock'), findsOneWidget);
        expect(find.text('Per-variant pricing'), findsOneWidget);
        expect(find.text('Deep filters'), findsOneWidget);
      }

      // takeException catches RenderFlex overflow errors.
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the widget banner draws its five devices', (tester) async {
    // Below the desktop breakpoint, where the widget banner is used.
    await _pumpHome(tester, const Size(820, 1800));

    const drawn = {
      '_LaptopPainter',
      '_HeadphonesPainter',
      '_PhonePainter',
      '_WatchPainter',
      '_EarbudsPainter',
    };

    final devices = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          drawn.contains(widget.painter?.runtimeType.toString()),
    );

    expect(
      devices,
      findsNWidgets(5),
      reason: 'laptop, headphones, phone, watch and earbuds are all drawn',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the banner shows no catalogue products', (tester) async {
    await _pumpHome(tester, const Size(1440, 1400));

    // The artwork used to be a collage of whatever the listing returned,
    // which put rice cookers and fridges in the banner. It is drawn now.
    expect(find.textContaining('Showcase product'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the widget banner renders before any product has arrived', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(820, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final service = _StubService(hangProducts: true);
    final catalog = CatalogProvider(service);
    addTearDown(catalog.dispose);
    await catalog.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProductService>.value(value: service),
          ChangeNotifierProvider<CatalogProvider>.value(value: catalog),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          // AppShell gives the page its scroll view in the real app;
          // without one here a tall page reports a bottom overflow
          // the shell would never produce.
          home: const Scaffold(
            body: SingleChildScrollView(child: HomeScreen()),
          ),
        ),
      ),
    );
    // The product request never resolves here: the banner must still draw.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Upgrade Your\nEveryday Tech'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('the supplied artwork banner', () {
    testWidgets('is used on desktop and carries working hotspots', (
      tester,
    ) async {
      await _pumpHome(tester, const Size(1920, 1400));

      final artwork = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/hero-devices.png',
      );
      expect(artwork, findsOneWidget, reason: 'the artwork is the banner');

      // Every element the picture only draws has a real target over it.
      for (final label in const [
        'Shop all products',
        'See featured',
        'Live stock — straight from the warehouse',
        'Per-variant pricing — discounts applied for you',
        'Deep filters — brand, category, specification',
      ]) {
        expect(
          find.bySemanticsLabel(label),
          findsOneWidget,
          reason: 'the artwork cannot be read, so "$label" needs a label',
        );
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('each hotspot sits over the artwork it covers', (tester) async {
      await _pumpHome(tester, const Size(1920, 1400));

      final frame = tester.getRect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/hero-devices.png',
        ),
      );

      // Measured off the artwork: the primary button fills x 106..415 and
      // y 454..517 of its 1920 x 819 frame.
      final cta = tester.getRect(find.bySemanticsLabel('Shop all products'));
      expect(
        (cta.left - frame.left) / frame.width,
        moreOrLessEquals(106 / 1920, epsilon: 0.01),
      );
      expect(
        (cta.top - frame.top) / frame.height,
        moreOrLessEquals(454 / 819, epsilon: 0.01),
      );
      expect(
        cta.width / frame.width,
        moreOrLessEquals((415 - 106) / 1920, epsilon: 0.01),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('narrow windows keep the readable widget banner', (
      tester,
    ) async {
      await _pumpHome(tester, const Size(820, 1800));

      expect(
        find.text('Upgrade Your\nEveryday Tech'),
        findsOneWidget,
        reason: 'the baked-in text would be a few pixels tall here',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
