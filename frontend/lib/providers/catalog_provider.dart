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

  /// True while a fetch is in flight, whether or not it shows a spinner.
  bool _inFlight = false;
  bool _indexRefreshing = false;

  /// Product ids already chased through [ensureImagesFor], so a product with
  /// no photo is not refetched on every rebuild.
  final Set<int> _chasedIds = <int>{};
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
  ///
  /// Kept free of side effects on purpose: every card calls this from inside
  /// `context.select`, which re-runs the selector on each notification to see
  /// whether the value changed. Logging here fired once per card per
  /// notification, and on the web every log line crosses into the browser
  /// console.
  String? primaryImageFor(int productId) {
    final images = _imageIndex[productId];
    if (images == null || images.isEmpty) return null;
    return images.first.url;
  }

  List<ProductImage> imagesFor(int productId) =>
      _imageIndex[productId] ?? const [];

  /// Fetches the reference data the header and home page are built from.
  ///
  /// `silent` refetches without flipping [isLoading], so a background refresh
  /// swaps the data in underneath the page instead of replacing it with a
  /// spinner. That is how the image index picks up products added since the
  /// tab was opened.
  Future<void> load({bool force = false, bool silent = false}) async {
    // Guards re-entry on its own, because a silent load deliberately leaves
    // `_loading` alone — without this a 30s refresh timer would stack another
    // fetch on top of one still in flight against a slow dev server.
    if (_inFlight) return;
    if (!force && _categories.isNotEmpty) return;

    _inFlight = true;
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }

    try {
      // Reference data is independent, so each part is fetched concurrently
      // and degrades on its own. A part that fails comes back null and the
      // value already held is kept: this used to substitute an empty list,
      // which meant one dropped request against the dev server wiped the
      // image index and every photo on the page vanished until the next
      // refresh happened to succeed.
      final results = await Future.wait([
        _orNull(_service.fetchCategories()),
        _orNull(_service.fetchBrands()),
        _orNull(_service.fetchNotices()),
        _orNull(_service.fetchImageIndex()),
      ]);

      final categories = results[0] as List<Category>?;
      final brands = results[1] as List<Brand>?;
      final notices = results[2] as List<Notice>?;
      final images = results[3] as Map<int, List<ProductImage>>?;

      if (categories != null) _categories = categories;
      if (brands != null) _brands = brands;
      if (notices != null) _notices = notices;
      if (images != null) _imageIndex = images;

      if (_categories.isEmpty && !silent) {
        _error = 'Could not load the catalog. Is the TechZone API reachable?';
      }
    } finally {
      _inFlight = false;
      _loading = false;
      notifyListeners();
    }
  }

  /// Resolves to null instead of throwing, so one failed part of [load] does
  /// not take the rest of the reference data with it.
  static Future<T?> _orNull<T>(Future<T> future) =>
      future.then<T?>((value) => value).catchError((_) => null);

  /// Fetches the image index again when a grid is showing products the index
  /// has never heard of.
  ///
  /// The index is loaded once for the whole catalogue, so a product added
  /// since the tab opened — or an index fetch that failed earlier — leaves
  /// cards with a placeholder where a photo should be. Each unknown id is
  /// only chased once, so a product that genuinely has no photo costs one
  /// request, not one per rebuild.
  void ensureImagesFor(Iterable<int> productIds) {
    final unknown = productIds.where(
      (id) => !_imageIndex.containsKey(id) && !_chasedIds.contains(id),
    );
    if (unknown.isEmpty) return;

    _chasedIds.addAll(unknown);
    // Out of the current build: this ends in notifyListeners().
    Future.microtask(_refreshImageIndex);
  }

  Future<void> _refreshImageIndex() async {
    if (_indexRefreshing) return;
    _indexRefreshing = true;
    try {
      final index = await _service.fetchImageIndex();
      if (index.isEmpty) return;
      _imageIndex = index;
      // Anything still missing after a good fetch really has no photo; drop
      // the ids that are now known so a later upload can still be picked up.
      _chasedIds.removeWhere(index.containsKey);
      notifyListeners();
    } catch (_) {
      // Keep the index we have; the next refresh can try again.
      _chasedIds.clear();
    } finally {
      _indexRefreshing = false;
    }
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

  /// Set by [dispose]. One of these belongs to each listing screen and is
  /// disposed as soon as the customer navigates away, which regularly happens
  /// while a fetch is still in flight. The response then notifies a disposed
  /// notifier, `notifyListeners` throws, and because the screens do not await
  /// their fetches that throw escapes as an unhandled error.
  ///
  /// [CatalogProvider] deliberately does not carry this: it lives for the
  /// lifetime of the app and is never disposed mid-navigation.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// [notifyListeners], unless this provider is already gone.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

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

  /// Refetches without showing a spinner, for a background refresh that must
  /// not blank the grid the customer is reading.
  ///
  /// Does nothing once "Load more" has been used: `_query.page` has moved on,
  /// so refetching it would replace the accumulated list with that one page
  /// and the earlier products would vanish under the customer.
  Future<void> refreshSilently() async {
    if (_query.page > 1) return;
    await _fetch(silent: true);
  }

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
    _notify();

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
        _notify();
      }
    }
  }

  Future<void> _fetch({bool reset = false, bool silent = false}) async {
    final token = ++_requestId;

    if (!silent) {
      _loading = true;
      _error = null;
      if (reset) _page = Paginated.empty<Product>();
      _notify();
    }

    try {
      final page = await _service.fetchProducts(_query);
      if (token != _requestId) return;
      _page = page;
    } on ApiException catch (error) {
      if (token != _requestId) return;
      // A failed background refresh keeps whatever is already on screen; only
      // a foreground fetch is allowed to replace it with an error.
      if (silent) return;
      _error = error.message;
      _page = Paginated.empty<Product>();
    } finally {
      if (token == _requestId) {
        _loading = false;
        _notify();
      }
    }
  }
}
