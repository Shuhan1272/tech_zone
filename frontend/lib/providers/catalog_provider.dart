import 'dart:async';

// `foundation` exports a `Category` annotation that collides with our model.
import 'package:flutter/foundation.dart' hide Category;

import '../core/network/api_exception.dart';
import '../models/catalog.dart';
import '../models/paginated.dart';
import '../models/product.dart';
import '../services/product_service.dart';

/// Shared, app-wide catalog reference data: categories, brands, notices and
/// the product-image index.
///
/// Loaded once on start and reused by the header navigation, the home page and
/// the catalog sidebar, so browsing does not re-fetch the taxonomy.
class CatalogProvider extends ChangeNotifier {
  CatalogProvider(this._service);

  final ProductService _service;

  List<Category> _categories = const [];
  List<Brand> _brands = const [];
  List<Notice> _notices = const [];
  Map<int, List<ProductImage>> _imageIndex = const {};

  bool _loading = false;
  String? _error;

  List<Category> get categories => _categories;
  List<Brand> get brands => _brands;
  List<Notice> get notices => _notices;
  bool get isLoading => _loading;
  String? get error => _error;

  List<Category> get featuredCategories =>
      _categories.where((c) => c.isFeatured).toList(growable: false);

  /// Every category, roots and descendants, for slug lookups.
  List<Category> get allCategories =>
      _categories.expand((c) => c.flattened).toList(growable: false);

  Category? categoryBySlug(String? slug) {
    if (slug == null || slug.isEmpty) return null;
    for (final category in allCategories) {
      if (category.slug == slug) return category;
    }
    return null;
  }

  /// Primary image URL for a product card, or null to fall back to a
  /// placeholder. Reads the index fetched by [load].
  String? primaryImageFor(int productId) {
    final images = _imageIndex[productId];
    if (images == null || images.isEmpty) return null;
    return images.first.url;
  }

  List<ProductImage> imagesFor(int productId) =>
      _imageIndex[productId] ?? const [];

  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (!force && _categories.isNotEmpty) return;

    _loading = true;
    _error = null;
    notifyListeners();

    // Reference data is independent; fetch concurrently and let each part
    // degrade on its own rather than failing the whole header.
    final results = await Future.wait([
      _service.fetchCategories().catchError((_) => <Category>[]),
      _service.fetchBrands().catchError((_) => <Brand>[]),
      _service.fetchNotices().catchError((_) => <Notice>[]),
      _service.fetchImageIndex().catchError((_) => <int, List<ProductImage>>{}),
    ]);

    _categories = results[0] as List<Category>;
    _brands = results[1] as List<Brand>;
    _notices = results[2] as List<Notice>;
    _imageIndex = results[3] as Map<int, List<ProductImage>>;

    if (_categories.isEmpty) {
      _error = 'Could not load the catalog. Is the TechZone API reachable?';
    }

    _loading = false;
    notifyListeners();
  }
}

/// Drives one product listing: the catalog page and search results.
///
/// All filtering, sorting, searching and paging is delegated to the backend's
/// `ProductFilter` / `OrderingFilter` / `ProductPagination`; this class only
/// holds the current [ProductQuery] and the page that came back.
class ProductListProvider extends ChangeNotifier {
  ProductListProvider(this._service);

  final ProductService _service;

  ProductQuery _query = const ProductQuery();
  Paginated<Product> _page = Paginated.empty<Product>();

  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  /// Guards against an out-of-order response overwriting a newer one when the
  /// user types quickly or toggles filters.
  int _requestId = 0;

  ProductQuery get query => _query;
  List<Product> get products => _page.items;
  int get totalCount => _page.count;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _page.hasNext;
  String? get error => _error;
  bool get isEmpty => !_loading && _page.items.isEmpty && _error == null;

  /// Replaces the query and refetches from page 1.
  Future<void> applyQuery(ProductQuery query) {
    _query = query.copyWith(page: 1);
    return _fetch(reset: true);
  }

  Future<void> refresh() => _fetch(reset: true);

  Future<void> setCategory(String? slug) =>
      applyQuery(_query.copyWith(categorySlug: slug, specFilters: const {}));

  Future<void> setBrand(String? slug) =>
      applyQuery(_query.copyWith(brandSlug: slug));

  Future<void> setSearch(String? term) =>
      applyQuery(_query.copyWith(search: term));

  Future<void> setSort(ProductSort sort) =>
      applyQuery(_query.copyWith(sort: sort));

  Future<void> setPageSize(int size) =>
      applyQuery(_query.copyWith(pageSize: size));

  /// Toggles one value of one `specification` facet.
  Future<void> toggleSpecFilter(String key, String value) {
    final next = {
      for (final entry in _query.specFilters.entries)
        entry.key: [...entry.value],
    };
    final values = next.putIfAbsent(key, () => <String>[]);

    if (values.contains(value)) {
      values.remove(value);
      if (values.isEmpty) next.remove(key);
    } else {
      values.add(value);
    }

    return applyQuery(_query.copyWith(specFilters: next));
  }

  bool isSpecSelected(String key, String value) =>
      _query.specFilters[key]?.contains(value) ?? false;

  Future<void> clearFilters() =>
      applyQuery(ProductQuery(sort: _query.sort, pageSize: _query.pageSize));

  /// Appends the next page, for the "Load more" button.
  Future<void> loadMore() async {
    if (_loadingMore || _loading || !_page.hasNext) return;

    _loadingMore = true;
    notifyListeners();

    final token = ++_requestId;
    try {
      final next = await _service.fetchProducts(
        _query.copyWith(page: _query.page + 1),
      );
      if (token != _requestId) return;
      _query = _query.copyWith(page: _query.page + 1);
      _page = _page.concat(next);
    } on ApiException catch (error) {
      if (token != _requestId) return;
      _error = error.message;
    } finally {
      if (token == _requestId) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    final token = ++_requestId;

    _loading = true;
    _error = null;
    if (reset) _page = Paginated.empty<Product>();
    notifyListeners();

    try {
      final page = await _service.fetchProducts(_query);
      if (token != _requestId) return;
      _page = page;
    } on ApiException catch (error) {
      if (token != _requestId) return;
      _error = error.message;
      _page = Paginated.empty<Product>();
    } finally {
      if (token == _requestId) {
        _loading = false;
        notifyListeners();
      }
    }
  }
}
