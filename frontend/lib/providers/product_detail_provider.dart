import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../models/product.dart';
import '../services/product_service.dart';

/// Loads everything one product page needs: the product, its images, and
/// (when signed in) its reviews and questions.
class ProductDetailProvider extends ChangeNotifier {
  ProductDetailProvider(this._service);

  final ProductService _service;

  /// Set by [dispose]. This provider belongs to one product page and is
  /// disposed the moment the customer navigates away — which routinely
  /// happens while [load] is still waiting on the four requests it makes.
  /// When those land they notify, and `notifyListeners` throws on a disposed
  /// notifier; the screen does not await [load], so that throw escapes as an
  /// unhandled error and takes the frame down with it.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// [notifyListeners], unless this provider is already gone.
  ///
  /// Used everywhere in this class rather than only on the async paths, so a
  /// later edit cannot reintroduce the bug by adding one more notify.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  Product? _product;
  List<ProductImage> _images = const [];
  List<ProductReview> _reviews = const [];
  List<ProductQuestion> _questions = const [];

  ProductVariant? _selectedVariant;
  String? _selectedColor;
  int _selectedImageIndex = 0;

  bool _loading = false;
  String? _error;

  /// True when reviews/questions were skipped because nobody is signed in.
  /// Both ViewSets require authentication even for GET.
  bool _engagementRequiresAuth = false;

  Product? get product => _product;
  List<ProductImage> get images => _images;
  List<ProductReview> get reviews => _reviews;
  List<ProductQuestion> get questions => _questions;
  ProductVariant? get selectedVariant => _selectedVariant;
  String? get selectedColor => _selectedColor;
  int get selectedImageIndex => _selectedImageIndex;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get engagementRequiresAuth => _engagementRequiresAuth;

  List<String> get imageUrls =>
      _images.map((image) => image.url).where((u) => u.isNotEmpty).toList();

  double? get averageRating {
    if (_reviews.isEmpty) return null;
    final total = _reviews.fold<int>(0, (sum, r) => sum + r.rating);
    return total / _reviews.length;
  }

  /// `key_feature` and `colors` come only from the list serializer, so a
  /// product opened by direct URL may legitimately have neither.
  bool get hasKeyFeatures => (_product?.keyFeature.isNotEmpty ?? false);

  /// Loads a product by slug.
  ///
  /// [listEntry] is the card the user clicked, when there was one. The detail
  /// serializer omits `key_feature` and `colors`, so passing it through lets
  /// the page show those without a second request.
  Future<void> load(
    String slug, {
    required bool isSignedIn,
    Product? listEntry,
  }) async {
    _loading = true;
    _error = null;
    _engagementRequiresAuth = false;
    _notify();

    try {
      final detail = await _service.fetchProduct(slug);
      _product = detail.mergeWith(listEntry);
      _selectedVariant = _product!.primaryVariant;
      _selectedColor = _product!.colors.isNotEmpty
          ? _product!.colors.first
          : null;
      _selectedImageIndex = 0;

      _images = await _service
          .fetchProductImages(_product!.id)
          .catchError((_) => <ProductImage>[]);

      if (isSignedIn) {
        await _loadEngagement(_product!.id);
      } else {
        _engagementRequiresAuth = true;
        _reviews = const [];
        _questions = const [];
      }
    } on ApiException catch (error) {
      _error = error.message;
      _product = null;
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> _loadEngagement(int productId) async {
    final results = await Future.wait([
      _service.fetchReviews(productId).catchError((_) => <ProductReview>[]),
      _service.fetchQuestions(productId).catchError((_) => <ProductQuestion>[]),
    ]);
    _reviews = results[0] as List<ProductReview>;
    _questions = results[1] as List<ProductQuestion>;
  }

  /// Re-fetches reviews/questions after the customer signs in or posts.
  Future<void> refreshEngagement() async {
    final product = _product;
    if (product == null) return;
    _engagementRequiresAuth = false;
    await _loadEngagement(product.id);
    _notify();
  }

  void selectVariant(ProductVariant variant) {
    if (_selectedVariant?.id == variant.id) return;
    _selectedVariant = variant;
    _notify();
  }

  void selectColor(String color) {
    if (_selectedColor == color) return;
    _selectedColor = color;
    _notify();
  }

  void selectImage(int index) {
    if (index < 0 || index >= _images.length || index == _selectedImageIndex) {
      return;
    }
    _selectedImageIndex = index;
    _notify();
  }

  /// Posts a review. Returns null on success or the server's message.
  ///
  /// A `unique_product_review` constraint means one review per customer per
  /// product; a second attempt comes back as a 400.
  Future<String?> submitReview({
    required int rating,
    required String review,
  }) async {
    final product = _product;
    if (product == null) return 'Product not loaded.';

    try {
      await _service.createReview(
        productId: product.id,
        rating: rating,
        review: review,
      );
      await refreshEngagement();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  /// Posts a question. `answer` and `is_approved` are admin-controlled, so the
  /// customer sees it unanswered until staff reply in Django admin.
  Future<String?> submitQuestion(String question) async {
    final product = _product;
    if (product == null) return 'Product not loaded.';

    try {
      await _service.createQuestion(productId: product.id, question: question);
      await refreshEngagement();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }
}
