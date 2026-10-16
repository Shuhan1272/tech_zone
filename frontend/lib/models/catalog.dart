import '../core/config/app_config.dart';
import 'paginated.dart';

/// Mirrors `products.serializers.BrandSerializer`.
///
/// The serializer does not expose `image`, even though `Brand.image` exists on
/// the model, so brands render as text chips rather than logos.
class Brand {
  const Brand({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
    this.isActive = true,
  });

  final int id;
  final String name;
  final String slug;
  final String description;
  final bool isActive;

  factory Brand.fromJson(Map<String, dynamic> json) => Brand(
    id: parseInt(json['id']),
    name: (json['name'] ?? '') as String,
    slug: (json['slug'] ?? '') as String,
    description: (json['description'] ?? '') as String,
    isActive: parseBool(json['is_active'], fallback: true),
  );
}

/// Mirrors `products.serializers.CategorySerializer`.
///
/// The list endpoint returns only roots (`CategoryViewSet.queryset` filters
/// `parent=None`) with children nested under `sub_categories`, recursively.
/// `filters` is the admin-authored map of facet name -> allowed values, which
/// drives the catalog sidebar; those keys are matched server-side against
/// `Product.specification` by `ProductFilter.filter_queryset`.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
    this.imageUrl,
    this.filters = const {},
    this.brands = const [],
    this.subCategories = const [],
    this.isActive = true,
    this.isFeatured = false,
  });

  final int id;
  final String name;
  final String slug;
  final String description;
  final String? imageUrl;
  final Map<String, dynamic> filters;
  final List<Brand> brands;
  final List<Category> subCategories;
  final bool isActive;
  final bool isFeatured;

  bool get hasChildren => subCategories.isNotEmpty;

  /// The facet map as `name -> values`, dropping malformed entries so a bad
  /// admin edit cannot break the sidebar.
  Map<String, List<String>> get facets {
    final result = <String, List<String>>{};
    for (final entry in filters.entries) {
      final values = parseStringList(entry.value);
      if (values.isNotEmpty) result[entry.key] = values;
    }
    return result;
  }

  /// This category plus every descendant, depth-first.
  List<Category> get flattened => [
    this,
    for (final child in subCategories) ...child.flattened,
  ];

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: parseInt(json['id']),
    name: (json['name'] ?? '') as String,
    slug: (json['slug'] ?? '') as String,
    description: (json['description'] ?? '') as String,
    imageUrl: AppConfig.resolveMedia(json['image'] as String?),
    filters: parseJsonMap(json['filters']),
    brands: (json['brands'] is List ? json['brands'] as List : const [])
        .whereType<Map<String, dynamic>>()
        .map(Brand.fromJson)
        .toList(growable: false),
    subCategories:
        (json['sub_categories'] is List
                ? json['sub_categories'] as List
                : const [])
            .whereType<Map<String, dynamic>>()
            .map(Category.fromJson)
            .toList(growable: false),
    isActive: parseBool(json['is_active'], fallback: true),
    isFeatured: parseBool(json['is_featured']),
  );
}

/// Mirrors `core.serializers.NoticeSerializer`.
class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.message,
    required this.noticeType,
    this.isActive = true,
    this.isFeatured = false,
    this.startAt,
    this.endAt,
  });

  final int id;
  final String title;
  final String message;
  final String noticeType;
  final bool isActive;
  final bool isFeatured;
  final DateTime? startAt;
  final DateTime? endAt;

  /// `Notice.start_at` / `end_at` are nullable and the backend does not filter
  /// on them, so the window is enforced here before showing a banner.
  bool get isLive {
    if (!isActive) return false;
    final now = DateTime.now().toUtc();
    if (startAt != null && now.isBefore(startAt!.toUtc())) return false;
    if (endAt != null && now.isAfter(endAt!.toUtc())) return false;
    return true;
  }

  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
    id: parseInt(json['id']),
    title: (json['title'] ?? '') as String,
    message: (json['message'] ?? '') as String,
    noticeType: (json['notice_type'] ?? 'general') as String,
    isActive: parseBool(json['is_active'], fallback: true),
    isFeatured: parseBool(json['is_featured']),
    startAt: parseDate(json['start_at']),
    endAt: parseDate(json['end_at']),
  );
}
