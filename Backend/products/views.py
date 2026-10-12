from django_filters.rest_framework import (
    DjangoFilterBackend
)

from rest_framework import viewsets,filters
from rest_framework.permissions import (
    IsAuthenticated
)

from decimal import Decimal
from django.db.models import Min, Q, F, ExpressionWrapper, fields

from .permissions import IsAdminOrReadOnly

from .models import (
    Category,
    Brand,
    Product,
    ProductVariant,
    ProductImage,
    ProductQuestion,
    ProductReview,
)

from .serializers import (
    CategorySerializer,
    BrandSerializer,
    ProductSerializer,
    ProductListSerializer,
    ProductVariantSerializer,
    ProductImageSerializer,
    ProductQuestionSerializer,
    ProductReviewSerializer,
)

from .filters import ProductFilter,CategoryFilter,BrandFilter
from .pagination import ProductPagination


# =========================================================
# Category
# =========================================================

class CategoryViewSet(viewsets.ModelViewSet):

    queryset = Category.objects.prefetch_related("brands").filter(parent=None)

    serializer_class = CategorySerializer

    permission_classes = [
        IsAdminOrReadOnly
    ]

    filter_backends = [
        DjangoFilterBackend,
    ]

    filterset_class = CategoryFilter

    lookup_field = 'slug'




# =========================================================
# Brand
# =========================================================

class BrandViewSet(viewsets.ModelViewSet):

    queryset = Brand.objects.prefetch_related('categories')

    serializer_class = BrandSerializer

    permission_classes = [
        IsAdminOrReadOnly
    ]

    filter_backends = [
            DjangoFilterBackend,
    ]
    
    filterset_class = BrandFilter
    
    lookup_field = 'slug'


# =========================================================
# Product
# =========================================================

class ProductViewSet(viewsets.ModelViewSet):

    queryset = Product.objects.select_related('brand', 'category').prefetch_related('variants').annotate(
        price=Min(
            ExpressionWrapper(
                F('variants__price') - (F('variants__price') * F('variants__discount_percentage') / Decimal('100.0')),
                output_field=fields.DecimalField()
            ),
            filter=Q(variants__is_active=True)
        ) 
    ) #adding temporary price column #due to relationship and property in model. 

    permission_classes = [
        IsAdminOrReadOnly
    ]

    pagination_class = ProductPagination

    filter_backends = [
        DjangoFilterBackend,
        filters.SearchFilter,
        filters.OrderingFilter,
    ]

    filterset_class = ProductFilter

    search_fields = [
        'name',
        'brand__name',
        'description',
    ]

    ordering_fields = [
        'name',
        'price', 
        'created_at',
    ]

    ordering = [
        '-created_at'
    ]

    lookup_field = 'slug'

    def get_serializer_class(self):

        if self.action == 'list':
            return ProductListSerializer

        return ProductSerializer


# =========================================================
# Product Variant
# =========================================================

class ProductVariantViewSet(
    viewsets.ModelViewSet
):

    queryset = ProductVariant.objects.all()

    serializer_class = ProductVariantSerializer

    permission_classes = [
        IsAdminOrReadOnly
    ]

    pagination_class = ProductPagination



# =========================================================
# Product Image
# =========================================================

class ProductImageViewSet(
    viewsets.ModelViewSet
):

    queryset = ProductImage.objects.select_related('product')

    serializer_class = ProductImageSerializer

    permission_classes = [
        IsAdminOrReadOnly
    ]


# =========================================================
# Product Question
# =========================================================

class ProductQuestionViewSet(
    viewsets.ModelViewSet
):

    serializer_class = ProductQuestionSerializer

    permission_classes = [
        IsAuthenticated
    ]

    def get_queryset(self):

        return ProductQuestion.objects.all()

    def perform_create(self, serializer):

        serializer.save(
            user=self.request.user
        )


# =========================================================
# Product Review
# =========================================================

class ProductReviewViewSet(
    viewsets.ModelViewSet
):

    serializer_class = ProductReviewSerializer

    permission_classes = [
        IsAuthenticated
    ]

    def get_queryset(self):

        return ProductReview.objects.all()

    def perform_create(self, serializer):

        serializer.save(
            user=self.request.user
        )
