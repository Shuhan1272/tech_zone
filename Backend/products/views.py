from decimal import Decimal

from django.db.models import (
    Min,
    Q,
    F,
    ExpressionWrapper,
    fields,
)

from django_filters.rest_framework import DjangoFilterBackend

from rest_framework import viewsets, filters

from rest_framework.permissions import (
    AllowAny,
    IsAuthenticated,
)

from .permissions import (
    IsAdminOrReadOnly,
    IsOwnerOrAdminOrReadOnly,
    staff_can,
)

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

from .filters import (
    ProductFilter,
    CategoryFilter,
    BrandFilter,
    ProductCodeSearchFilter,
)

from .pagination import ProductPagination

# =========================================================
# Category
# =========================================================


class CategoryViewSet(viewsets.ModelViewSet):

    queryset = Category.objects.prefetch_related("brands").filter(parent=None)

    serializer_class = CategorySerializer

    permission_classes = [IsAdminOrReadOnly]

    filter_backends = [
        DjangoFilterBackend,
    ]

    filterset_class = CategoryFilter

    lookup_field = "slug"


# =========================================================
# Brand
# =========================================================


class BrandViewSet(viewsets.ModelViewSet):

    queryset = Brand.objects.prefetch_related("categories")

    serializer_class = BrandSerializer

    permission_classes = [IsAdminOrReadOnly]

    filter_backends = [
        DjangoFilterBackend,
    ]

    filterset_class = BrandFilter

    lookup_field = "slug"


# =========================================================
# Product
# =========================================================


class ProductViewSet(viewsets.ModelViewSet):

    queryset = (
        Product.objects.select_related("brand", "category")
        .prefetch_related("variants")
        .annotate(
            price=Min(
                ExpressionWrapper(
                    F("variants__price")
                    - (
                        F("variants__price")
                        * F("variants__discount_percentage")
                        / Decimal("100.0")
                    ),
                    output_field=fields.DecimalField(max_digits=12, decimal_places=2),
                ),
                filter=Q(variants__is_active=True),
            )
        )
    )

    permission_classes = [IsAdminOrReadOnly]

    pagination_class = ProductPagination

    filter_backends = [
        DjangoFilterBackend,
        ProductCodeSearchFilter,
        filters.OrderingFilter,
    ]

    filterset_class = ProductFilter

    search_fields = [
        "name",
        "brand__name",
        "description",
    ]

    ordering_fields = [
        "name",
        "price",
        "created_at",
    ]

    ordering = ["-created_at"]

    lookup_field = "slug"

    def get_serializer_class(self):

        if self.action == "list":
            return ProductListSerializer

        return ProductSerializer


# =========================================================
# Product Variant
# =========================================================


class ProductVariantViewSet(viewsets.ModelViewSet):

    queryset = ProductVariant.objects.all()

    serializer_class = ProductVariantSerializer

    permission_classes = [IsAdminOrReadOnly]

    pagination_class = ProductPagination


# =========================================================
# Product Image
# =========================================================


class ProductImageViewSet(viewsets.ModelViewSet):

    queryset = ProductImage.objects.select_related("product")

    serializer_class = ProductImageSerializer

    permission_classes = [IsAdminOrReadOnly]

    filter_backends = [
        DjangoFilterBackend,
    ]

    filterset_fields = [
        "product",
    ]


# =========================================================
# Product Question
# =========================================================


class ProductQuestionViewSet(viewsets.ModelViewSet):

    serializer_class = ProductQuestionSerializer

    permission_classes = [IsOwnerOrAdminOrReadOnly]

    def get_queryset(self):

        queryset = ProductQuestion.objects.select_related("product", "user")

        user = self.request.user

        if staff_can(user, ProductQuestion, "view"):
            return queryset

        if user.is_authenticated:
            return queryset.filter(Q(is_approved=True) | Q(user=user))

        return queryset.filter(is_approved=True)

    def perform_create(self, serializer):

        serializer.save(user=self.request.user)


# =========================================================
# Product Review
# =========================================================


class ProductReviewViewSet(viewsets.ModelViewSet):

    serializer_class = ProductReviewSerializer

    filter_backends = [
        DjangoFilterBackend,
    ]

    filterset_fields = [
        "product",
    ]

    def get_permissions(self):

        # Everyone can view approved reviews.
        if self.action in ["list", "retrieve"]:
            permission_classes = [AllowAny]

        # Login required to submit reviews.
        elif self.action == "create":
            permission_classes = [IsAuthenticated]

        # Only admins can update or delete.
        else:
            permission_classes = [IsAdminOrReadOnly]

        return [permission() for permission in permission_classes]

    def get_queryset(self):

        # Only approved reviews are visible
        # through the API, for all users.
        return ProductReview.objects.select_related("product", "user").filter(
            is_approved=True
        )

    def perform_create(self, serializer):

        # Every new review requires admin approval.
        serializer.save(user=self.request.user, is_approved=False)
