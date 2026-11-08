
import re

import django_filters

from django.db.models import Q, Exists, OuterRef
from rest_framework.exceptions import ValidationError
from rest_framework.filters import SearchFilter

from .models import (
    Product,
    ProductVariant,
    Category,
    Brand,
)


# =========================================================
# Product Code Search Filter
# =========================================================

class ProductCodeSearchFilter(SearchFilter):

    def filter_queryset(self, request, queryset, view):

        search = request.query_params.get(
            self.search_param,
            ''
        ).strip()

        # Examples:
        # TZ-P000075 -> Product ID 75
        # tz-p000075 -> Product ID 75

        match = re.fullmatch(
            r'TZ-P(\d+)',
            search,
            flags=re.IGNORECASE
        )

        if match:

            product_id = int(match.group(1))

            return queryset.filter(
                pk=product_id
            )

        # Normal searching by product name,
        # description, brand, etc.

        return super().filter_queryset(
            request,
            queryset,
            view
        )


# =========================================================
# Brand Filter
# =========================================================

class BrandFilter(django_filters.FilterSet):

    categories = django_filters.CharFilter(
        method='filter_categories'
    )

    def filter_categories(self, queryset, name, value):

        return queryset.filter(
            categories__slug=value
        ).distinct()

    class Meta:

        model = Brand

        fields = [
            'categories',
        ]


# =========================================================
# Category Filter
# =========================================================

class CategoryFilter(django_filters.FilterSet):

    parent = django_filters.CharFilter(
        method='filter_parent'
    )

    is_featured = django_filters.BooleanFilter(
        field_name='is_featured'
    )

    def filter_parent(self, queryset, name, value):

        return queryset.filter(
            parent__slug=value
        )

    class Meta:

        model = Category

        fields = [
            'parent',
            'is_featured',
        ]


# =========================================================
# Product Filter
# =========================================================

class ProductFilter(django_filters.FilterSet):

    category = django_filters.CharFilter(
        method='filter_category'
    )

    brand = django_filters.CharFilter(
        method='filter_brand'
    )

    is_active = django_filters.BooleanFilter(
        field_name='is_active'
    )

    is_featured = django_filters.BooleanFilter(
        field_name='is_featured'
    )

    availability = django_filters.CharFilter(
        method='filter_availability'
    )

    in_stock = django_filters.BooleanFilter(
        method='filter_in_stock'
    )

    on_sale = django_filters.BooleanFilter(
        method='filter_on_sale'
    )

    min_price = django_filters.NumberFilter(
        method='filter_min_price'
    )

    max_price = django_filters.NumberFilter(
        method='filter_max_price'
    )

    # =====================================================
    # Category Filter
    # =====================================================

    def filter_category(self, queryset, name, value):

        return queryset.filter(
            Q(category__slug=value) |
            Q(category__parent__slug=value)
        ).distinct()

    # =====================================================
    # Brand Filter
    # =====================================================

    def filter_brand(self, queryset, name, value):

        brands = [
            brand.strip()
            for brand in value.split(',')
            if brand.strip()
        ]

        if not brands:
            return queryset

        return queryset.filter(
            brand__slug__in=brands
        )

    # =====================================================
    # Availability Filter
    # =====================================================

    def filter_availability(self, queryset, name, value):

        selected = {
            item.strip().lower()
            for item in value.split(',')
            if item.strip()
        }

        if not selected:
            return queryset

        valid = {
            Product.Availability.IN_STOCK,
            Product.Availability.OUT_OF_STOCK,
            Product.Availability.COMING_SOON,
            Product.Availability.PRE_ORDER,
        }

        invalid = selected - valid

        if invalid:

            raise ValidationError({
                'availability':
                    'Invalid availability: '
                    + ', '.join(sorted(invalid))
            })

        available_variants = ProductVariant.objects.filter(
            product_id=OuterRef('pk'),
            is_active=True,
            stock__gt=0
        )

        queryset = queryset.annotate(
            _has_stock=Exists(available_variants)
        )

        conditions = Q()

        # In stock
        if Product.Availability.IN_STOCK in selected:

            conditions |= Q(
                availability=Product.Availability.IN_STOCK,
                _has_stock=True
            )

        # Out of stock
        if Product.Availability.OUT_OF_STOCK in selected:

            conditions |= (
                Q(
                    availability=Product.Availability.OUT_OF_STOCK
                )
                |
                Q(
                    availability=Product.Availability.IN_STOCK,
                    _has_stock=False
                )
            )

        # Coming soon
        if Product.Availability.COMING_SOON in selected:

            conditions |= Q(
                availability=Product.Availability.COMING_SOON
            )

        # Pre-order
        if Product.Availability.PRE_ORDER in selected:

            conditions |= Q(
                availability=Product.Availability.PRE_ORDER
            )

        return queryset.filter(conditions)

    # =====================================================
    # In Stock Filter
    # =====================================================

    def filter_in_stock(self, queryset, name, value):

        available_variants = ProductVariant.objects.filter(
            product_id=OuterRef('pk'),
            is_active=True,
            stock__gt=0
        )

        queryset = queryset.annotate(
            _has_stock_filter=Exists(available_variants)
        )

        if value:

            return queryset.filter(
                availability=Product.Availability.IN_STOCK,
                _has_stock_filter=True
            )

        return queryset.exclude(
            availability=Product.Availability.IN_STOCK,
            _has_stock_filter=True
        )

    # =====================================================
    # On Sale Filter
    # =====================================================

    def filter_on_sale(self, queryset, name, value):

        discounted_variants = ProductVariant.objects.filter(
            product_id=OuterRef('pk'),
            is_active=True,
            discount_percentage__gt=0
        )

        queryset = queryset.annotate(
            _has_discount=Exists(discounted_variants)
        )

        return queryset.filter(
            _has_discount=value
        )

    # =====================================================
    # Minimum Price
    # =====================================================

    def filter_min_price(self, queryset, name, value):

        if value is None:
            return queryset

        if value < 0:

            raise ValidationError({
                'min_price':
                    'Minimum price cannot be negative.'
            })

        return queryset.filter(
            price__gte=value
        )

    # =====================================================
    # Maximum Price
    # =====================================================

    def filter_max_price(self, queryset, name, value):

        if value is None:
            return queryset

        if value < 0:

            raise ValidationError({
                'max_price':
                    'Maximum price cannot be negative.'
            })

        return queryset.filter(
            price__lte=value
        )

    # =====================================================
    # Dynamic Specification Filters
    # =====================================================

    def filter_queryset(self, queryset):

        queryset = super().filter_queryset(queryset)

        params = self.data

        reserved_params = {
            'category',
            'brand',
            'is_active',
            'is_featured',
            'availability',
            'in_stock',
            'on_sale',
            'min_price',
            'max_price',
            'ordering',
            'search',
            'page',
            'page_size',
            'limit',
            'featured',
        }

        for key in params.keys():

            if key in reserved_params:
                continue

            values = []

            for raw_value in params.getlist(key):

                values.extend([
                    value.strip()
                    for value in raw_value.split(',')
                    if value.strip()
                ])

            if not values:
                continue

            value_query = Q()

            for value in values:

                value_query |= Q(
                    **{
                        f'specification__{key}__iexact':
                            value
                    }
                )

            queryset = queryset.filter(
                value_query
            )

        return queryset

    # =====================================================
    # Meta
    # =====================================================

    class Meta:

        model = Product

        fields = [
            'category',
            'brand',
            'is_active',
            'is_featured',
            'availability',
            'in_stock',
            'on_sale',
            'min_price',
            'max_price',
        ]
