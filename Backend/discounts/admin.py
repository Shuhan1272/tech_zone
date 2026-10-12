from django.contrib import admin

from .models import Discount


@admin.register(Discount)
class DiscountAdmin(admin.ModelAdmin):

    list_display = [
        'name',
        'discount_type',
        'code',
        'value_type',
        'value',
        'is_active',
        'start_date',
        'end_date',
    ]

    list_filter = [
        'discount_type',
        'value_type',
        'is_active',
    ]

    search_fields = [
        'name',
        'code',
    ]

    ordering = [
        '-created_at',
    ]