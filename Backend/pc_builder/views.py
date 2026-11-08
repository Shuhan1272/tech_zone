
from collections import defaultdict

from django.db import transaction
from django.db.models import Q
from django.shortcuts import get_object_or_404

from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.generics import ListAPIView
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import (
    AllowAny,
    IsAuthenticated,
)
from rest_framework.response import Response

from cart.models import Cart, CartItem
from products.models import Product, ProductVariant

from .models import (
    ComponentType,
    PCComponentCategory,
    PCBuild,
    PCBuildItem,
)

from .serializers import (
    PCComponentVariantSerializer,
    PCBuildSerializer,
    PCBuildItemInputSerializer,
)

from .services import check_compatibility


# =========================================================
# PC COMPONENT PAGINATION
# =========================================================

class PCComponentPagination(PageNumberPagination):

    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100


# =========================================================
# PC COMPONENT LIST
# =========================================================

class PCComponentListView(ListAPIView):

    serializer_class = PCComponentVariantSerializer
    permission_classes = [AllowAny]
    pagination_class = PCComponentPagination

    def get_queryset(self):

        # =================================================
        # GET COMPONENT TYPE
        # =================================================

        component_type = (
            self.request.query_params
            .get("type", "")
            .strip()
            .lower()
        )

        if component_type not in ComponentType.values:

            raise ValidationError({
                "type": "Select a valid PC component type."
            })

        # =================================================
        # GET MAPPED CATEGORIES
        # =================================================

        category_ids = list(
            PCComponentCategory.objects.filter(
                component_type=component_type
            ).values_list(
                "category_id",
                flat=True
            )
        )

        # If no categories are mapped,
        # return an empty queryset.

        if not category_ids:

            return ProductVariant.objects.none()

        # =================================================
        # FILTER PRODUCT VARIANTS
        # =================================================

        queryset = (
            ProductVariant.objects
            .filter(
                is_active=True,
                stock__gt=0,

                product__is_active=True,

                product__availability=(
                    Product.Availability.IN_STOCK
                ),

                product__category_id__in=category_ids
            )
            .select_related(
                "product",
                "product__category",
                "product__brand"
            )
            .prefetch_related(
                "product__images"
            )
            .order_by(
                "product__name",
                "id"
            )
        )

        # =================================================
        # SEARCH COMPONENTS
        # =================================================

        search = (
            self.request.query_params
            .get("search", "")
            .strip()
        )

        if search:

            queryset = queryset.filter(
                Q(
                    product__name__icontains=search
                )
                |
                Q(
                    product__brand__name__icontains=search
                )
                |
                Q(
                    sku__icontains=search
                )
            )

        return queryset


# =========================================================
# PC BUILD VIEWSET
# =========================================================

class PCBuildViewSet(viewsets.ModelViewSet):

    serializer_class = PCBuildSerializer
    permission_classes = [IsAuthenticated]

    # =====================================================
    # GET USER BUILDS
    # =====================================================

    def get_queryset(self):

        return (
            PCBuild.objects
            .filter(
                user=self.request.user
            )
            .prefetch_related(
                "items__variant__product__images",
                "items__variant__product__category",
                "items__variant__product__brand",
            )
        )

    # =====================================================
    # CREATE BUILD
    # =====================================================

    def perform_create(self, serializer):

        serializer.save(
            user=self.request.user
        )

    # =====================================================
    # ADD OR UPDATE COMPONENT
    # =====================================================

    @action(
        detail=True,
        methods=["post"],
        url_path="components"
    )
    def add_component(self, request, pk=None):

        build = self.get_object()

        serializer = PCBuildItemInputSerializer(
            data=request.data
        )

        serializer.is_valid(
            raise_exception=True
        )

        data = serializer.validated_data

        item, created = (
            PCBuildItem.objects.update_or_create(
                build=build,
                component_type=data["component_type"],
                defaults={
                    "variant": data["variant"],
                    "quantity": data["quantity"],
                }
            )
        )

        build.save(
            update_fields=["updated_at"]
        )

        updated_build = (
            self.get_queryset().get(
                pk=build.pk
            )
        )

        return Response(
            PCBuildSerializer(
                updated_build,
                context={
                    "request": request
                }
            ).data,

            status=(
                status.HTTP_201_CREATED
                if created
                else status.HTTP_200_OK
            )
        )

    # =====================================================
    # REMOVE COMPONENT
    # =====================================================

    @action(
        detail=True,
        methods=["delete"],
        url_path=r"components/(?P<item_id>[0-9]+)"
    )
    def remove_component(
        self,
        request,
        pk=None,
        item_id=None
    ):

        build = self.get_object()

        item = get_object_or_404(
            PCBuildItem,
            pk=item_id,
            build=build
        )

        item.delete()

        build.save(
            update_fields=["updated_at"]
        )

        return Response(
            status=status.HTTP_204_NO_CONTENT
        )

    # =====================================================
    # CHECK COMPATIBILITY
    # =====================================================

    @action(
        detail=True,
        methods=["get"],
        url_path="compatibility"
    )
    def compatibility(self, request, pk=None):

        build = self.get_object()

        items = list(
            build.items.all()
        )

        report = check_compatibility(
            items
        )

        return Response(
            report,
            status=status.HTTP_200_OK
        )

    # =====================================================
    # ADD COMPLETE PC BUILD TO CART
    # =====================================================

    @action(
        detail=True,
        methods=["post"],
        url_path="add-to-cart"
    )
    def add_to_cart(self, request, pk=None):

        build = self.get_object()

        items = list(
            build.items.all()
        )

        # =================================================
        # CHECK EMPTY BUILD
        # =================================================

        if not items:

            raise ValidationError({
                "detail": "Your PC build is empty."
            })

        # =================================================
        # CHECK COMPATIBILITY
        # =================================================

        report = check_compatibility(
            items
        )

        if report["missing_required"]:

            raise ValidationError({
                "detail": "Your PC build is incomplete.",
                "missing_required": (
                    report["missing_required"]
                )
            })

        if report["issues"]:

            raise ValidationError({
                "detail": "Resolve build issues first.",
                "issues": report["issues"]
            })

        # =================================================
        # COMBINE VARIANT QUANTITIES
        # =================================================

        quantities = defaultdict(int)

        for item in items:

            quantities[
                item.variant_id
            ] += item.quantity

        variant_ids = list(
            quantities.keys()
        )

        # =================================================
        # DATABASE TRANSACTION
        # =================================================

        with transaction.atomic():

            cart, _ = Cart.objects.get_or_create(
                user=request.user
            )

            # =============================================
            # LOCK PRODUCT VARIANTS
            # =============================================

            variants = {
                variant.id: variant

                for variant in (
                    ProductVariant.objects
                    .select_for_update()
                    .select_related("product")
                    .filter(
                        id__in=variant_ids
                    )
                )
            }

            # =============================================
            # GET EXISTING CART ITEMS
            # =============================================

            existing_items = {
                item.variant_id: item

                for item in (
                    CartItem.objects
                    .select_for_update()
                    .filter(
                        cart=cart,
                        variant_id__in=variant_ids
                    )
                )
            }

            # =============================================
            # VALIDATE ALL PRODUCTS
            # =============================================

            for variant_id, quantity in quantities.items():

                variant = variants.get(
                    variant_id
                )

                if (
                    variant is None
                    or not variant.is_active
                    or not variant.product.is_active
                    or variant.product.availability
                    != Product.Availability.IN_STOCK
                ):

                    raise ValidationError({
                        "detail": (
                            f"Variant {variant_id} "
                            f"is unavailable."
                        )
                    })

                existing = existing_items.get(
                    variant_id
                )

                current_quantity = (
                    existing.quantity
                    if existing
                    else 0
                )

                if (
                    current_quantity + quantity
                    > variant.stock
                ):

                    raise ValidationError({
                        "detail": (
                            f"Insufficient stock for "
                            f"{variant.product.name}."
                        )
                    })

            # =============================================
            # ADD COMPONENTS TO CART
            # =============================================

            for variant_id, quantity in quantities.items():

                existing = existing_items.get(
                    variant_id
                )

                if existing:

                    existing.quantity += quantity

                    existing.save(
                        update_fields=[
                            "quantity",
                            "updated_at"
                        ]
                    )

                else:

                    CartItem.objects.create(
                        cart=cart,
                        variant_id=variant_id,
                        quantity=quantity
                    )

        # =================================================
        # SUCCESS RESPONSE
        # =================================================

        return Response(
            {
                "detail": "PC build added to cart.",
                "cart_id": cart.id,
                "variant_count": len(quantities),
                "warnings": report["warnings"],
                "compatibility_note": report["note"],
            },
            status=status.HTTP_200_OK
        )
