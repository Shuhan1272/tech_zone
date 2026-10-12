from django.contrib import admin
from django.utils.html import format_html

from .models import (
    Category,
    Brand,
    Product,
    ProductVariant,
    ProductImage,
    ProductQuestion,
    ProductReview,
)


# =========================================================
# CATEGORY
# =========================================================

@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = (
        "name",
        "parent",
        "is_active",
        "created_at",
    )

    list_filter = (
        "is_active",
    )

    search_fields = (
        "name",
    )

    prepopulated_fields = {
        "slug": ("name",)
    }


# =========================================================
# BRAND
# =========================================================

@admin.register(Brand)
class BrandAdmin(admin.ModelAdmin):
    list_display = (
        "name",
        "is_active",
        "created_at",
    )

    list_filter = (
        "is_active",
    )

    search_fields = (
        "name",
    )

    prepopulated_fields = {
        "slug": ("name",)
    }


# =========================================================
# PRODUCT IMAGE INLINE
# =========================================================

class ProductImageInline(admin.TabularInline):
    model = ProductImage
    extra = 1

    fields = (
        "image",
        "image_preview",
        "is_primary",
    )

    readonly_fields = (
        "image_preview",
    )

    def image_preview(self, obj):
        if obj.image:
            return format_html(
                '<img src="{}" width="80" height="80" '
                'style="object-fit: cover; border-radius: 6px;" />',
                obj.image.url
            )

        return "No image"

    image_preview.short_description = "Preview"


# =========================================================
# PRODUCT VARIANT INLINE
# =========================================================

class ProductVariantInline(admin.TabularInline):
    model = ProductVariant
    extra = 1

    fields = (
        "options",
        "price",
        "discount_percentage", 
        "stock",
        "is_active",
    )


# =========================================================
# PRODUCT
# =========================================================

@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = (
        "name",
        "brand",
        "category",
        "is_active",
        "created_at",
    )

    list_filter = (
        "is_active",
        "brand",
        "category",
    )

    search_fields = (
        "name",
        "brand__name",
        "category__name",
    )

    prepopulated_fields = {
        "slug": ("name",)
    }

    inlines = (
        ProductImageInline,
        ProductVariantInline,
    )


# =========================================================
# PRODUCT IMAGE
# =========================================================

@admin.register(ProductImage)
class ProductImageAdmin(admin.ModelAdmin):
    list_display = (
        "product",
        "image_preview",
        "is_primary",
    )

    list_filter = (
        "is_primary",
    )

    search_fields = (
        "product__name",
    )

    readonly_fields = (
        "image_preview",
    )

    def image_preview(self, obj):
        if obj.image:
            return format_html(
                '<img src="{}" width="80" height="80" '
                'style="object-fit: cover; border-radius: 6px;" />',
                obj.image.url
            )

        return "No image"

    image_preview.short_description = "Preview"


# =========================================================
# PRODUCT VARIANT
# =========================================================

@admin.register(ProductVariant)
class ProductVariantAdmin(admin.ModelAdmin):
    list_display = (
        "product",
        "price",
        "stock",
        "is_active",
        "created_at",
    )

    list_filter = (
        "is_active",
    )

    search_fields = (
        "product__name",
        "sku",
    )


# =========================================================
# PRODUCT QUESTION
# =========================================================

@admin.register(ProductQuestion)
class ProductQuestionAdmin(admin.ModelAdmin):
    list_display = (
        "product",
        "user",
        "created_at",
    )

    search_fields = (
        "product__name",
        "user__email",
        "question",
    )

    list_filter = (
        "created_at",
    )


# =========================================================
# PRODUCT REVIEW
# =========================================================

@admin.register(ProductReview)
class ProductReviewAdmin(admin.ModelAdmin):
    list_display = (
        "product",
        "user",
        "rating",
        "created_at",
    )

    list_filter = (
        "rating",
        "created_at",
    )

    search_fields = (
        "product__name",
        "user__email",
        "comment",
    )