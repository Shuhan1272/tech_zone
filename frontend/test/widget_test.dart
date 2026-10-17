// Smoke tests for the TechZone storefront.
//
// These exercise the pure parsing and query-building logic, which is where a
// mismatch with the Django API would actually bite. They deliberately avoid
// pumping the full app, because every screen depends on a live backend.

import 'package:flutter_test/flutter_test.dart';
import 'package:techzone/models/cart.dart';
import 'package:techzone/models/paginated.dart';
import 'package:techzone/models/product.dart';
import 'package:techzone/services/product_service.dart';

void main() {
  group('decimal parsing', () {
    test('accepts the string form Django uses for DecimalField', () {
      expect(parseDecimal('83490.00'), 83490.0);
    });

    test('accepts the numeric form Django uses for @property fields', () {
      expect(parseDecimal(64287.3), 64287.3);
    });

    test('returns null rather than throwing on junk', () {
      expect(parseDecimal('not-a-number'), isNull);
      expect(parseDecimal(null), isNull);
    });
  });

  group('ProductVariant', () {
    // Shape copied from a real GET /api/v1/products/products/ response.
    final json = {
      'id': 2,
      'product': 2,
      'sku': 'singer-15-ton-inverter-ac--',
      'options': {'RAM': '', 'Storage': ''},
      'price': '83490.00',
      'discount_percentage': '23.00',
      'discounted_price': 64287.3,
      'saved_price': 19202.7,
      'stock': 100,
      'is_default': true,
      'is_active': true,
    };

    test('uses the server-computed discounted price verbatim', () {
      final variant = ProductVariant.fromJson(json);
      expect(variant.price, 83490.0);
      expect(variant.discountedPrice, 64287.3);
      expect(variant.savedPrice, 19202.7);
      expect(variant.hasDiscount, isTrue);
    });

    test('hides option axes whose value is blank', () {
      final variant = ProductVariant.fromJson(json);
      expect(variant.labelledOptions, isEmpty);
      expect(variant.optionSummary, 'Standard');
    });

    test('labels populated option axes', () {
      final variant = ProductVariant.fromJson({
        ...json,
        'options': {'RAM': '16GB', 'Storage': '512GB'},
      });
      expect(variant.optionSummary, '16GB / 512GB');
    });
  });

  group('Product', () {
    test('parses a list entry and picks the default variant', () {
      final product = Product.fromJson({
        'id': 1,
        'name': 'MSI Cyborg 15',
        'slug': 'msi-cyborg-15',
        'category': 'Desktop → Gaming pc',
        'brand': 'MSI',
        'key_feature': {'RAM': '8GB DDR5'},
        'specification': {'Generation': '13th Gen'},
        'colors': ['Black', 'White'],
        'is_active': true,
        'is_featured': false,
        'default_variant': {
          'id': 1,
          'product': 1,
          'price': '140000.00',
          'discount_percentage': '11.50',
          'discounted_price': 123900.0,
          'saved_price': 16100.0,
          'stock': 5,
          'is_default': true,
          'is_active': true,
        },
      });

      expect(product.primaryVariant?.id, 1);
      expect(product.fromPrice, 123900.0);
      expect(product.inStock, isTrue);
      // StringRelatedField gives "Parent → Child"; the leaf is what we show.
      expect(product.categoryLeaf, 'Gaming pc');
    });

    test('mergeWith recovers key_feature that the detail serializer omits', () {
      final listEntry = Product.fromJson({
        'id': 1,
        'name': 'MSI Cyborg 15',
        'slug': 'msi-cyborg-15',
        'key_feature': {'RAM': '8GB DDR5'},
        'colors': ['Black'],
      });
      final detail = Product.fromJson({
        'id': 1,
        'name': 'MSI Cyborg 15',
        'slug': 'msi-cyborg-15',
        'description': 'A gaming laptop.',
        'variants': const [],
      }, isDetail: true);

      final merged = detail.mergeWith(listEntry);
      expect(merged.description, 'A gaming laptop.');
      expect(merged.keyFeature['RAM'], '8GB DDR5');
      expect(merged.colors, ['Black']);
    });
  });

  group('Paginated', () {
    test('reads the DRF page envelope used by /products/', () {
      final page = Paginated.fromAny<Product>({
        'count': 3,
        'next': null,
        'previous': null,
        'results': [
          {'id': 1, 'name': 'A', 'slug': 'a'},
          {'id': 2, 'name': 'B', 'slug': 'b'},
        ],
      }, (json) => Product.fromJson(json));
      expect(page.count, 3);
      expect(page.items.length, 2);
      expect(page.hasNext, isFalse);
    });

    test('reads the bare array used by /categories/ and /brands/', () {
      final page = Paginated.fromAny<Product>([
        {'id': 1, 'name': 'A', 'slug': 'a'},
      ], (json) => Product.fromJson(json));
      expect(page.count, 1);
      expect(page.items.single.slug, 'a');
    });
  });

  group('Cart', () {
    test('totals from the server-supplied unit prices', () {
      final cart = Cart.fromJson({
        'id': 1,
        'items': [
          {
            'id': 5,
            'variant': 12,
            'product_name': 'iPhone 17 Pro',
            'variant_price': '120000.00',
            'discounted_price': '114000.00',
            'quantity': 2,
          },
        ],
      });

      expect(cart.totalQuantity, 2);
      expect(cart.subtotal, 228000.0);
      expect(cart.listSubtotal, 240000.0);
      expect(cart.savings, 12000.0);
      expect(cart.itemForVariant(12)?.id, 5);
    });
  });

  group('ProductQuery', () {
    test('maps onto the parameters ProductFilter understands', () {
      final params = const ProductQuery(
        categorySlug: 'laptop',
        brandSlug: 'msi',
        search: 'cyborg',
        sort: ProductSort.priceLowToHigh,
        pageSize: 20,
      ).toQueryParameters();

      expect(params['category'], 'laptop');
      expect(params['brand'], 'msi');
      expect(params['search'], 'cyborg');
      expect(params['ordering'], 'price');
      expect(params['limit'], 20);
      expect(params['is_active'], true);
    });

    test('sends repeated spec values as a list for the OR filter', () {
      final params = const ProductQuery(
        specFilters: {
          'RAM': ['8 GB', '16 GB'],
          'SSD': ['512GB SSD'],
        },
      ).toQueryParameters();

      expect(params['RAM'], ['8 GB', '16 GB']);
      expect(params['SSD'], '512GB SSD');
    });

    test('clamps page size to the backend max_page_size of 90', () {
      final params = const ProductQuery(pageSize: 500).toQueryParameters();
      expect(params['limit'], 90);
    });

    test('omits empty filters so no blank query parameters are sent', () {
      final params = const ProductQuery().toQueryParameters();
      expect(params.containsKey('category'), isFalse);
      expect(params.containsKey('search'), isFalse);
      expect(params.containsKey('is_featured'), isFalse);
    });
  });
}
