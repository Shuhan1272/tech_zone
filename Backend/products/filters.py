import django_filters

from .models import ProductVariant

import django_filters

from .models import (
    Product, 
    Category, 
    Brand, 

)

from django.db.models import Q




class BrandFilter(
    django_filters.FilterSet
):
    #one brand can have many categories 
    categories = django_filters.CharFilter(
        method='filter_categories'
    )

    def filter_categories(self, queryset, name, value):

        return queryset.filter(
            Q(categories__slug=value)
    )

    class Meta:
    
            model = Brand
    
            fields = [
                'categories',
            ]

class CategoryFilter(
    django_filters.FilterSet
):

    parent = django_filters.CharFilter(
        method='filter_parent'
    )

    def filter_parent(self, queryset, name, value):

        return queryset.filter(
            Q(parent__slug=value)
    )

    is_featured = django_filters.BooleanFilter(
            field_name='is_featured'
    )

    class Meta:
    
            model = Category
    
            fields = [
                'parent',
                'is_featured'
            ]



class ProductFilter(django_filters.FilterSet):

    category = django_filters.CharFilter(
    method='filter_category'
    )

    def filter_category(self, queryset, name, value):
        return queryset.filter(
        Q(category__slug=value) |
        Q(category__parent__slug=value)
    )

    brand = django_filters.CharFilter(
        field_name='brand__slug',
        lookup_expr='exact'
    )

    is_active = django_filters.BooleanFilter(
        field_name='is_active'
    )

    is_featured = django_filters.BooleanFilter(
        field_name='is_featured'
    )

    def filter_queryset(self, queryset):

        # First apply declared filters
        queryset = super().filter_queryset(queryset)

        # Existing query parameters
        params = self.data

        # These are NOT keyFeatures
        reserved_params = {
            'category',
            'brand',
            'is_active',
            'is_featured',
            'ordering',
            'search',
            'page',
            'page_size',
            'limit'
        }

        # Dynamic keyFeatures filters
        for key in params.keys():

            if key in reserved_params:
                continue

            values = params.getlist(key)

            if not values:
                continue

            # Multiple values for the same key = OR
            value_query = Q()

            for value in values:
                value_query |= Q(
                    **{
                        f'specification__{key}__iexact': value
                    }
                )

            queryset = queryset.filter(value_query)

        return queryset

    class Meta:
        model = Product
        fields = [
        'category',
        'brand',
        'is_active',
        'is_featured',
        ]

