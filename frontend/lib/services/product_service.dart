import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/catalog.dart';
import '../models/paginated.dart';
import '../models/product.dart';

/// Sort options the backend's `OrderingFilter` actually accepts.
///
/// `ProductViewSet.ordering_fields` is `['name', 'price', 'created_at']`, where
/// `price` is a queryset annotation computing the discounted minimum. Anything
/// outside this list is silently ignored by DRF, so the UI only offers these.
enum ProductSort {
  newest('-created_at', 'Newest first'),
  priceLowToHigh('price', 'Price: low to high'),
  priceHighToLow('-price', 'Price: high to low'),
  nameAsc('name', 'Name: A to Z'),
  nameDesc('-name', 'Name: Z to A');

  const ProductSort(this.query, this.label);
  final String query;
  final String label;
}

/// A catalog query, mapped 1:1 onto the query parameters `ProductFilter`
/// understands.
class ProductQuery {
  const ProductQuery({
    this.categorySlug,
    this.brandSlug,
    this.search,
    this.sort = ProductSort.newest,
    this.specFilters = const {},
    this.featuredOnly = false,
    this.page = 1,
    this.pageSize = AppConfig.defaultPageSize,
  });

  /// Matches the category OR its parent (`ProductFilter.filter_category`), so
  /// selecting "Desktop" also returns products filed under "Gaming pc".
  final String? categorySlug;
  final String? brandSlug;
  final String? search;
  final ProductSort sort;

  /// Facet selections keyed by `Product.specification` key. `ProductFilter`
  /// treats every unreserved query parameter as
  /// `specification__<key>__iexact`, OR-ing repeated values for one key.
  final Map<String, List<String>> specFilters;

  final bool featuredOnly;
  final int page;
  final int pageSize;

  bool get hasFilters =>
      (categorySlug ?? '').isNotEmpty ||
      (brandSlug ?? '').isNotEmpty ||
      (search ?? '').isNotEmpty ||
      featuredOnly ||
      specFilters.values.any((v) => v.isNotEmpty);

  Map<String, dynamic> toQueryParameters() {
    final params = <String, dynamic>{
      'ordering': sort.query,
      'limit': pageSize.clamp(1, AppConfig.maxPageSize),
      'page': page,
      // Customers must never see deactivated products.
      'is_active': true,
    };

    if ((categorySlug ?? '').isNotEmpty) params['category'] = categorySlug;
    if ((brandSlug ?? '').isNotEmpty) params['brand'] = brandSlug;
    if ((search ?? '').trim().isNotEmpty) params['search'] = search!.trim();
    if (featuredOnly) params['is_featured'] = true;

    // Repeated values for one key become a list, which Dio serialises as
    // `?RAM=8GB&RAM=16GB` — exactly the `getlist` form the filter expects.
    for (final entry in specFilters.entries) {
      final values = entry.value.where((v) => v.trim().isNotEmpty).toList();
      if (values.isEmpty) continue;
      params[entry.key] = values.length == 1 ? values.first : values;
    }

    return params;
  }

  ProductQuery copyWith({
    Object? categorySlug = _unset,
    Object? brandSlug = _unset,
    Object? search = _unset,
    ProductSort? sort,
    Map<String, List<String>>? specFilters,
    bool? featuredOnly,
    int? page,
    int? pageSize,
  }) => ProductQuery(
    categorySlug: categorySlug == _unset
        ? this.categorySlug
        : categorySlug as String?,
    brandSlug: brandSlug == _unset ? this.brandSlug : brandSlug as String?,
    search: search == _unset ? this.search : search as String?,
    sort: sort ?? this.sort,
    specFilters: specFilters ?? this.specFilters,
    featuredOnly: featuredOnly ?? this.featuredOnly,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
  );

  static const Object _unset = Object();
}

/// Wraps the `products` and `core` read APIs.
///
/// Everything here is public except reviews and questions, whose ViewSets
/// declare `IsAuthenticated` even for GET.
class ProductService {
  ProductService(this._client);

  final ApiClient _client;

  /// Root categories, each with `sub_categories` and `brands` nested.
  Future<List<Category>> fetchCategories({bool? featured}) async {
    final data = await _client.get<dynamic>(
      ApiEndpoints.categories,
      skipAuth: true,
      query: {'is_featured': ?featured},
    );
    return Paginated.fromAny<Category>(data, Category.fromJson).items;
  }

  Future<Category> fetchCategory(String slug) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.category(slug),
      skipAuth: true,
    );
    return Category.fromJson(data);
  }

  /// All brands, or only those linked to one category.
  ///
  /// `BrandFilter` exposes the parameter as `categories` (plural) — the docx
  /// shows `?category=`, which the filter does not declare.
  Future<List<Brand>> fetchBrands({String? categorySlug}) async {
    final data = await _client.get<dynamic>(
      ApiEndpoints.brands,
      skipAuth: true,
      query: {if ((categorySlug ?? '').isNotEmpty) 'categories': categorySlug},
    );
    return Paginated.fromAny<Brand>(data, Brand.fromJson).items;
  }

  Future<Paginated<Product>> fetchProducts(ProductQuery query) async {
    final data = await _client.get<dynamic>(
      ApiEndpoints.products,
      skipAuth: true,
      query: query.toQueryParameters(),
    );
    return Paginated.fromAny<Product>(data, (json) => Product.fromJson(json));
  }

  Future<Product> fetchProduct(String slug) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.product(slug),
      skipAuth: true,
    );
    return Product.fromJson(data, isDetail: true);
  }

  /// Images for one product. Requires the `product` field/filter addition.
  Future<List<ProductImage>> fetchProductImages(int productId) async {
    final data = await _client.get<dynamic>(
      ApiEndpoints.productImages,
      skipAuth: true,
      query: {'product': productId},
    );
    final images = Paginated.fromAny<ProductImage>(
      data,
      ProductImage.fromJson,
    ).items.toList();
    images.sort(ProductImage.compare);
    return images;
  }

  /// Every image in one request, grouped by product id.
  ///
  /// The listing endpoint returns no images of its own, so the catalog grid
  /// fetches the whole (small, unpaginated) image table once and indexes it
  /// rather than issuing one request per card.
  Future<Map<int, List<ProductImage>>> fetchImageIndex() async {
    final data = await _client.get<dynamic>(
      ApiEndpoints.productImages,
      skipAuth: true,
    );
    final images = Paginated.fromAny<ProductImage>(
      data,
      ProductImage.fromJson,
    ).items;

    final index = <int, List<ProductImage>>{};
    for (final image in images) {
      if (image.url.isEmpty) continue;
      index.putIfAbsent(image.productId, () => <ProductImage>[]).add(image);
    }
    for (final list in index.values) {
      list.sort(ProductImage.compare);
    }
    return index;
  }

  Future<ProductVariant> fetchVariant(int id) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.variant(id),
      skipAuth: true,
    );
    return ProductVariant.fromJson(data);
  }

  /// Reviews for one product.
  ///
  /// `ProductReviewViewSet` declares no `filterset_fields`, so `?product=`
  /// is ignored server-side and the whole table comes back; filtering happens
  /// here. Requires authentication.
  Future<List<ProductReview>> fetchReviews(int productId) async {
    final data = await _client.get<dynamic>(ApiEndpoints.reviews);
    return Paginated.fromAny<ProductReview>(data, ProductReview.fromJson).items
        .where((review) => review.productId == productId)
        .toList(growable: false);
  }

  Future<ProductReview> createReview({
    required int productId,
    required int rating,
    required String review,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.reviews,
      body: {'product': productId, 'rating': rating, 'review': review},
    );
    return ProductReview.fromJson(data);
  }

  /// Questions for one product. Same auth and client-filtering caveats as
  /// [fetchReviews].
  Future<List<ProductQuestion>> fetchQuestions(int productId) async {
    final data = await _client.get<dynamic>(ApiEndpoints.questions);
    return Paginated.fromAny<ProductQuestion>(data, ProductQuestion.fromJson)
        .items
        .where((question) => question.productId == productId)
        .toList(growable: false);
  }

  Future<ProductQuestion> createQuestion({
    required int productId,
    required String question,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.questions,
      body: {'product': productId, 'question': question},
    );
    return ProductQuestion.fromJson(data);
  }

  /// Site-wide notices for the home page banner.
  Future<List<Notice>> fetchNotices({bool activeOnly = true}) async {
    final data = await _client.get<dynamic>(
      ApiEndpoints.notices,
      skipAuth: true,
      query: {if (activeOnly) 'is_active': true},
    );
    return Paginated.fromAny<Notice>(data, Notice.fromJson).items
        .where((notice) => !activeOnly || notice.isLive)
        .toList(growable: false);
  }
}
