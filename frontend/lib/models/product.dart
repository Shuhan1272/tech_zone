import '../core/config/app_config.dart';
import 'paginated.dart';

/// Mirrors `products.serializers.ProductVariantSerializer`.
///
/// Price authority lives here: [price], [discountedPrice] and [savedPrice] all
/// come straight from the server (the latter two are model `@property`
/// computations). The frontend never recomputes a discount — it only formats
/// what the backend sent.
class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.productId,
    required this.sku,
    required this.price,
    required this.discountedPrice,
    required this.savedPrice,
    required this.discountPercentage,
    required this.stock,
    this.options = const {},
    this.isDefault = false,
    this.isActive = true,
  });

  final int id;
  final int productId;
  final String sku;

  /// List price before discount, as sent by the server.
  final double price;

  /// Server-computed payable price. Authoritative.
  final double discountedPrice;

  /// Server-computed saving (price - discountedPrice).
  final double savedPrice;

  final double discountPercentage;
  final int stock;

  /// Free-form variant axes, e.g. `{"RAM": "16GB", "Storage": "512GB"}`.
  /// Empty string values are common in the seed data and are hidden in the UI.
  final Map<String, dynamic> options;

  final bool isDefault;
  final bool isActive;

  bool get hasDiscount => discountPercentage > 0 && savedPrice > 0;
  bool get inStock => stock > 0;

  /// Only the axes that actually carry a value.
  Map<String, String> get labelledOptions {
    final result = <String, String>{};
    for (final entry in options.entries) {
      final value = entry.value?.toString().trim() ?? '';
      if (value.isNotEmpty) result[entry.key] = value;
    }
    return result;
  }

  /// Short description of the variant, e.g. "16GB / 512GB".
  String get optionSummary {
    final labelled = labelledOptions;
    if (labelled.isEmpty) return 'Standard';
    return labelled.values.join(' / ');
  }

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
    id: parseInt(json['id']),
    productId: parseInt(json['product']),
    sku: (json['sku'] ?? '') as String,
    price: parseDecimal(json['price']) ?? 0,
    discountedPrice:
        parseDecimal(json['discounted_price']) ??
        parseDecimal(json['price']) ??
        0,
    savedPrice: parseDecimal(json['saved_price']) ?? 0,
    discountPercentage: parseDecimal(json['discount_percentage']) ?? 0,
    stock: parseInt(json['stock']),
    options: parseJsonMap(json['options']),
    isDefault: parseBool(json['is_default']),
    isActive: parseBool(json['is_active'], fallback: true),
  );
}

/// Mirrors `products.serializers.ProductImageSerializer`.
///
/// `product` is present thanks to the approved two-line backend addition;
/// without it there is no way to tell which product an image belongs to.
class ProductImage {
  const ProductImage({
    required this.id,
    required this.productId,
    required this.url,
    this.altText = '',
    this.isPrimary = false,
    this.displayOrder = 0,
  });

  final int id;
  final int productId;
  final String url;
  final String altText;
  final bool isPrimary;
  final int displayOrder;

  factory ProductImage.fromJson(Map<String, dynamic> json) => ProductImage(
    id: parseInt(json['id']),
    productId: parseInt(json['product']),
    url: AppConfig.resolveMedia(json['image'] as String?) ?? '',
    altText: (json['alt_text'] ?? '') as String,
    isPrimary: parseBool(json['is_primary']),
    displayOrder: parseInt(json['display_order']),
  );

  /// Primary first, then by the admin-defined display order.
  static int compare(ProductImage a, ProductImage b) {
    if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
    return a.displayOrder.compareTo(b.displayOrder);
  }
}

/// A product as returned by either `ProductListSerializer` or
/// `ProductSerializer`.
///
/// The two serializers expose different field sets and neither is a superset:
///
///   * list only:   `key_feature`, `colors`, `default_variant`
///   * detail only: `description`, `variants`, `created_at`, `updated_at`
///   * both:        `id`, `name`, `slug`, `category`, `brand`,
///                  `specification`, `is_active`, `is_featured`
///
/// One class models both, with [isDetail] recording which was parsed and
/// [mergeWith] letting a detail fetch inherit the list-only fields when the
/// user navigated from a listing.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.slug,
    this.categoryName,
    this.brandName,
    this.description = '',
    this.keyFeature = const {},
    this.specification = const {},
    this.colors = const [],
    this.variants = const [],
    this.defaultVariant,
    this.isActive = true,
    this.isFeatured = false,
    this.isDetail = false,
  });

  final int id;
  final String name;
  final String slug;

  /// Both serializers use `StringRelatedField`, so these are the models'
  /// `__str__` output — not ids. A nested category renders as
  /// "Desktop → Gaming pc", which is why the arrow is stripped for display.
  final String? categoryName;
  final String? brandName;

  final String description;
  final Map<String, dynamic> keyFeature;
  final Map<String, dynamic> specification;
  final List<String> colors;

  /// Populated by the detail serializer only.
  final List<ProductVariant> variants;

  /// Populated by the list serializer only.
  final ProductVariant? defaultVariant;

  final bool isActive;
  final bool isFeatured;

  /// True when parsed from `ProductSerializer` (the detail endpoint).
  final bool isDetail;

  /// Leaf category name, e.g. "Gaming pc" from "Desktop → Gaming pc".
  String? get categoryLeaf => categoryName?.split('→').last.trim();

  /// Every variant worth offering, newest serializer first.
  List<ProductVariant> get sellableVariants {
    final source = variants.isNotEmpty
        ? variants
        : (defaultVariant == null
              ? const <ProductVariant>[]
              : [defaultVariant!]);
    return source.where((v) => v.isActive).toList(growable: false);
  }

  /// The variant a product page should select on open: the backend's default
  /// if it is active, else the first active one.
  ProductVariant? get primaryVariant {
    final sellable = sellableVariants;
    if (sellable.isEmpty) return null;
    for (final variant in sellable) {
      if (variant.isDefault) return variant;
    }
    return sellable.first;
  }

  /// Lowest payable price across sellable variants, for the "from" label.
  double? get fromPrice {
    final sellable = sellableVariants;
    if (sellable.isEmpty) return null;
    return sellable
        .map((v) => v.discountedPrice)
        .reduce((a, b) => a < b ? a : b);
  }

  bool get hasMultipleVariants => sellableVariants.length > 1;

  bool get inStock => sellableVariants.any((v) => v.inStock);

  factory Product.fromJson(Map<String, dynamic> json, {bool isDetail = false}) {
    final rawVariants = json['variants'];
    final rawDefault = json['default_variant'];

    return Product(
      id: parseInt(json['id']),
      name: (json['name'] ?? '') as String,
      slug: (json['slug'] ?? '') as String,
      categoryName: json['category']?.toString(),
      brandName: json['brand']?.toString(),
      description: (json['description'] ?? '') as String,
      keyFeature: parseJsonMap(json['key_feature']),
      specification: parseJsonMap(json['specification']),
      colors: parseStringList(json['colors']),
      variants: (rawVariants is List ? rawVariants : const [])
          .whereType<Map<String, dynamic>>()
          .map(ProductVariant.fromJson)
          .toList(growable: false),
      defaultVariant: rawDefault is Map<String, dynamic>
          ? ProductVariant.fromJson(rawDefault)
          : null,
      isActive: parseBool(json['is_active'], fallback: true),
      isFeatured: parseBool(json['is_featured']),
      isDetail: isDetail,
    );
  }

  /// Carries `key_feature` and `colors` — which the detail serializer omits —
  /// over from a list entry the user navigated from. Returns `this` unchanged
  /// when there is nothing to inherit.
  Product mergeWith(Product? listEntry) {
    if (listEntry == null) return this;
    return Product(
      id: id,
      name: name,
      slug: slug,
      categoryName: categoryName ?? listEntry.categoryName,
      brandName: brandName ?? listEntry.brandName,
      description: description,
      keyFeature: keyFeature.isNotEmpty ? keyFeature : listEntry.keyFeature,
      specification: specification.isNotEmpty
          ? specification
          : listEntry.specification,
      colors: colors.isNotEmpty ? colors : listEntry.colors,
      variants: variants,
      defaultVariant: defaultVariant ?? listEntry.defaultVariant,
      isActive: isActive,
      isFeatured: isFeatured,
      isDetail: isDetail,
    );
  }
}

/// Mirrors `products.serializers.ProductReviewSerializer`.
///
/// `user` is read-only and serialised as the user's primary key, so the UI can
/// only show "You" versus "A customer" — there is no name on the payload.
class ProductReview {
  const ProductReview({
    required this.id,
    required this.productId,
    required this.userId,
    required this.rating,
    required this.review,
    this.createdAt,
  });

  final int id;
  final int productId;
  final int userId;
  final int rating;
  final String review;
  final DateTime? createdAt;

  factory ProductReview.fromJson(Map<String, dynamic> json) => ProductReview(
    id: parseInt(json['id']),
    productId: parseInt(json['product']),
    userId: parseInt(json['user']),
    rating: parseInt(json['rating']),
    review: (json['review'] ?? '') as String,
    createdAt: parseDate(json['created_at']),
  );
}

/// Mirrors `products.serializers.ProductQuestionSerializer`.
///
/// `answer` and `is_approved` are read-only — only an admin can fill them in
/// (via Django admin), so the UI renders the answer when present.
class ProductQuestion {
  const ProductQuestion({
    required this.id,
    required this.productId,
    required this.userId,
    required this.question,
    this.answer = '',
    this.isApproved = false,
    this.createdAt,
  });

  final int id;
  final int productId;
  final int userId;
  final String question;
  final String answer;
  final bool isApproved;
  final DateTime? createdAt;

  bool get isAnswered => answer.trim().isNotEmpty;

  factory ProductQuestion.fromJson(Map<String, dynamic> json) =>
      ProductQuestion(
        id: parseInt(json['id']),
        productId: parseInt(json['product']),
        userId: parseInt(json['user']),
        question: (json['question'] ?? '') as String,
        answer: (json['answer'] ?? '') as String,
        isApproved: parseBool(json['is_approved']),
        createdAt: parseDate(json['created_at']),
      );
}
