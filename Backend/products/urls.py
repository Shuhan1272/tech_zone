
from django.urls import path
from rest_framework.routers import DefaultRouter

from .compare_views import ProductComparisonView

from .views import (
    CategoryViewSet,
    BrandViewSet,
    ProductViewSet,
    ProductVariantViewSet,
    ProductImageViewSet,
    ProductQuestionViewSet,
    ProductReviewViewSet,
)


router = DefaultRouter()


# =========================================================
# Category
# =========================================================

router.register(
    'categories',
    CategoryViewSet,
    basename='category'
)


# =========================================================
# Brand
# =========================================================

router.register(
    'brands',
    BrandViewSet,
    basename='brand'
)


# =========================================================
# Product
# =========================================================

router.register(
    'products',
    ProductViewSet,
    basename='product'
)


# =========================================================
# Product Variant
# =========================================================

router.register(
    'variants',
    ProductVariantViewSet,
    basename='product-variant'
)


# =========================================================
# Product Image
# =========================================================

router.register(
    'product-images',
    ProductImageViewSet,
    basename='product-image'
)


# =========================================================
# Product Question
# =========================================================

router.register(
    'questions',
    ProductQuestionViewSet,
    basename='product-question'
)


# =========================================================
# Product Review
# =========================================================

router.register(
    'reviews',
    ProductReviewViewSet,
    basename='product-review'
)


# =========================================================
# Product Comparison + Router URLs
# =========================================================

urlpatterns = [
    path(
        'products/compare/',
        ProductComparisonView.as_view(),
        name='product-compare'
    ),
] + router.urls
