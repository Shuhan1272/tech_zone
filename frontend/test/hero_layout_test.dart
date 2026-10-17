// The hero is a two-column banner on desktop and a stacked one below that.
// Both arrangements carry a headline, two CTAs, a product collage and three
// feature cards, so they have plenty of room to overflow at an awkward width.
// These tests pump the real widgets at each breakpoint and fail on any
// overflow, which is the failure mode a layout change actually has.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:techzone/core/network/api_client.dart';
import 'package:techzone/core/network/token_storage.dart';
import 'package:techzone/core/theme/app_theme.dart';
import 'package:techzone/models/catalog.dart';
import 'package:techzone/models/product.dart';
import 'package:techzone/providers/catalog_provider.dart';
import 'package:techzone/screens/home/home_screen.dart';
import 'package:techzone/services/product_service.dart';

/// Serves a small, fixed catalogue so the hero has real products to show.
class _StubService extends ProductService {
  _StubService() : super(ApiClient(tokens: TokenStorage()));

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
  Future<Paginated<Product>> fetchProducts(ProductQuery query) async =>
      Paginated<Product>(items: products, count: products.length);
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
      child: MaterialApp(theme: AppTheme.light(), home: const HomeScreen()),
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
    testWidgets('the hero lays out without overflow on $label', (
      tester,
    ) async {
      await _pumpHome(tester, size);

      expect(find.text('Technology that keeps up with you'), findsOneWidget);
      expect(find.text('Shop all products'), findsOneWidget);
      expect(find.text('See featured'), findsOneWidget);

      // The three feature cards survive every arrangement.
      expect(find.text('Live stock'), findsOneWidget);
      expect(find.text('Per-variant pricing'), findsOneWidget);
      expect(find.text('Deep filters'), findsOneWidget);

      // takeException catches RenderFlex overflow errors.
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the showcase renders a card per product it was given', (
    tester,
  ) async {
    await _pumpHome(tester, const Size(1440, 1400));

    // The large card captions itself with the product's name and price.
    expect(
      find.textContaining('Showcase product 1'),
      findsWidgets,
      reason: 'the hero collage is built from real catalogue products',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the hero still renders before any product has arrived', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final service = _StubService();
    final catalog = CatalogProvider(service);
    addTearDown(catalog.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProductService>.value(value: service),
          ChangeNotifierProvider<CatalogProvider>.value(value: catalog),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const HomeScreen()),
      ),
    );
    // One frame only: the fetch has not resolved, so the collage has nothing.
    await tester.pump();

    expect(find.text('Technology that keeps up with you'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
