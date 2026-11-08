
import json
import re
from collections import OrderedDict

from django.db.models import Avg, Count, Prefetch
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Product, ProductVariant, ProductImage


def normalize_specifications(specification):
    """
    Supports both grouped and flat specification JSON.
    """

    if not isinstance(specification, dict):
        return {}

    sections = OrderedDict()

    for key, value in specification.items():
        if isinstance(value, dict):
            sections[str(key)] = {
                str(field): field_value
                for field, field_value in value.items()
            }
        else:
            sections.setdefault(
                "Other Specifications", {}
            )[str(key)] = value

    return sections


class ProductComparisonView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        raw_ids = request.query_params.get("ids", "").strip()

        if not raw_ids:
            return Response(
                {"detail": "Please select products to compare."},
                status=status.HTTP_400_BAD_REQUEST
            )

        id_parts = [
            value.strip()
            for value in raw_ids.split(",")
        ]

        if not all(
            re.fullmatch(r"[0-9]+", value)
            for value in id_parts
        ):
            return Response(
                {"detail": "Product IDs must be valid integers."},
                status=status.HTTP_400_BAD_REQUEST
            )

        product_ids = [int(value) for value in id_parts]

        if any(product_id <= 0 for product_id in product_ids):
            return Response(
                {"detail": "Product IDs must be positive."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if len(product_ids) > 4:
            return Response(
                {"detail": "You can compare a maximum of 4 products."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if len(product_ids) != len(set(product_ids)):
            return Response(
                {"detail": "Duplicate products are not allowed."},
                status=status.HTTP_400_BAD_REQUEST
            )

        queryset = (
            Product.objects
            .filter(
                id__in=product_ids,
                is_active=True
            )
            .select_related("brand", "category")
            .prefetch_related(
                Prefetch(
                    "variants",
                    queryset=ProductVariant.objects.filter(
                        is_active=True
                    ).order_by("-is_default", "id"),
                    to_attr="comparison_variants"
                ),
                Prefetch(
                    "images",
                    queryset=ProductImage.objects.order_by(
                        "-is_primary",
                        "display_order",
                        "id"
                    ),
                    to_attr="comparison_images"
                )
            )
            .annotate(
                average_rating=Avg("reviews__rating"),
                review_count=Count("reviews", distinct=True)
            )
        )

        products_by_id = {
            product.id: product
            for product in queryset
        }

        missing_ids = [
            product_id
            for product_id in product_ids
            if product_id not in products_by_id
        ]

        if missing_ids:
            return Response(
                {
                    "detail": "Some products were not found or are inactive.",
                    "product_ids": missing_ids
                },
                status=status.HTTP_404_NOT_FOUND
            )

        products = [
            products_by_id[product_id]
            for product_id in product_ids
        ]

        result = []
        normalized_specs = {}

        for product in products:
            variants = product.comparison_variants

            variant = variants[0] if variants else None

            images = product.comparison_images
            image = images[0] if images else None

            image_url = None

            if image and image.image:
                image_url = request.build_absolute_uri(
                    image.image.url
                )

            variant_data = None

            if variant:
                variant_data = {
                    "id": variant.id,
                    "sku": variant.sku,
                    "ram" : variant.ram,
                    "storage" : variant.storage,
                    "price": str(variant.price),
                    "discount_percentage": str(
                        variant.discount_percentage
                    ),
                    "discounted_price": str(
                        variant.discounted_price
                    ),
                    "stock": variant.stock,
                    "is_default": variant.is_default
                }

            normalized_specs[product.id] = (
                normalize_specifications(product.specification)
            )

            result.append({
                "id": product.id,
                "name": product.name,
                "slug": product.slug,
                "brand": (
                    product.brand.name
                    if product.brand else None
                ),
                "category": product.category.name,
                "description": product.description,
                "key_feature": product.key_feature,
                "specification": product.specification,
                "availability": product.availability,
                "image": image_url,
                "rating": (
                    round(float(product.average_rating), 1)
                    if product.average_rating is not None
                    else None
                ),
                "review_count": product.review_count,
                "variant": variant_data
            })

        # Collect every specification field across products
        section_fields = OrderedDict()

        for product in products:
            for section_name, fields in (
                normalized_specs[product.id].items()
            ):
                section_fields.setdefault(
                    section_name, OrderedDict()
                )

                for field_name in fields:
                    section_fields[section_name][field_name] = True

        comparison_sections = []

        for section_name, fields in section_fields.items():
            rows = []

            for field_name in fields:
                values = [
                    normalized_specs[product.id]
                    .get(section_name, {})
                    .get(field_name)
                    for product in products
                ]

                different = len({
                    json.dumps(
                        value,
                        sort_keys=True,
                        default=str
                    )
                    for value in values
                }) > 1

                rows.append({
                    "label": field_name,
                    "values": values,
                    "different": different
                })

            comparison_sections.append({
                "name": section_name,
                "rows": rows
            })

        return Response(
            {
                "count": len(result),
                "max_products": 4,
                "products": result,
                "specification_sections": comparison_sections
            },
            status=status.HTTP_200_OK
        )
