// The product grid reads its photos from one index that CatalogProvider
// fetches for the whole catalogue. These tests pin down what happens to that
// index when a refresh goes wrong, because a dropped request used to empty it
// and every photo on the page disappeared until a later refresh happened to
// succeed.
import 'package:flutter_test/flutter_test.dart';
import 'package:techzone/core/network/api_client.dart';
import 'package:techzone/core/network/api_exception.dart';
import 'package:techzone/core/network/token_storage.dart';
import 'package:techzone/models/catalog.dart';
import 'package:techzone/models/product.dart';
import 'package:techzone/providers/catalog_provider.dart';
import 'package:techzone/services/product_service.dart';

const _category = Category(id: 1, name: 'Router', slug: 'router');

const _image = ProductImage(
  id: 7,
  productId: 42,
  url: 'http://127.0.0.1:8000/media/products/router.webp',
  isPrimary: true,
);

/// A service whose image-index call can be made to fail on demand.
class _FlakyService extends ProductService {
  _FlakyService() : super(ApiClient(tokens: TokenStorage()));

  bool failIndex = false;
  int indexCalls = 0;

  @override
  Future<List<Category>> fetchCategories({bool? featured}) async => [_category];

  @override
  Future<List<Brand>> fetchBrands({String? categorySlug}) async => const [];

  @override
  Future<List<Notice>> fetchNotices({bool activeOnly = true}) async => const [];

  @override
  Future<Map<int, List<ProductImage>>> fetchImageIndex() async {
    indexCalls++;
    if (failIndex) {
      throw ApiException(message: 'boom', statusCode: 500);
    }
    return {
      _image.productId: const [_image],
    };
  }
}

void main() {
  test(
    'a failed image-index refresh keeps the photos already loaded',
    () async {
      final service = _FlakyService();
      final catalog = CatalogProvider(service);

      await catalog.load();
      expect(
        catalog.primaryImageFor(_image.productId),
        _image.url,
        reason: 'the first load should populate the index',
      );

      // The dev server drops the next index request.
      service.failIndex = true;
      await catalog.load(force: true, silent: true);

      expect(
        catalog.primaryImageFor(_image.productId),
        _image.url,
        reason: 'a failed refresh must not empty the index',
      );
      expect(catalog.categories, isNotEmpty);
    },
  );

  test(
    'a failed category refresh keeps the categories already loaded',
    () async {
      final service = _FlakyService();
      final catalog = CatalogProvider(service);

      await catalog.load();
      expect(catalog.categories, hasLength(1));

      service.failIndex = true;
      await catalog.load(force: true, silent: true);

      expect(catalog.categories, hasLength(1));
      expect(
        catalog.error,
        isNull,
        reason: 'a silent refresh must not surface an error',
      );
    },
  );

  test('ensureImagesFor chases an unknown product once, then stops', () async {
    final service = _FlakyService();
    final catalog = CatalogProvider(service);

    await catalog.load();
    final callsAfterLoad = service.indexCalls;

    // Product 99 is not in the index: worth one refetch.
    catalog.ensureImagesFor([99]);
    await Future<void>.delayed(Duration.zero);
    expect(service.indexCalls, callsAfterLoad + 1);

    // Still missing after that refetch, so it must not be chased again,
    // however many times the grid rebuilds.
    catalog.ensureImagesFor([99]);
    catalog.ensureImagesFor([99]);
    await Future<void>.delayed(Duration.zero);
    expect(
      service.indexCalls,
      callsAfterLoad + 1,
      reason: 'a product with no photo must not refetch on every rebuild',
    );
  });

  test('ensureImagesFor ignores products the index already covers', () async {
    final service = _FlakyService();
    final catalog = CatalogProvider(service);

    await catalog.load();
    final callsAfterLoad = service.indexCalls;

    catalog.ensureImagesFor([_image.productId]);
    await Future<void>.delayed(Duration.zero);

    expect(service.indexCalls, callsAfterLoad);
  });
}
