from django.core.exceptions import PermissionDenied

from django import forms
from django.contrib import admin
from django.utils.html import format_html

from .models import (
    Category,
    Brand,
    Color,
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

    list_filter = ("is_active",)

    search_fields = ("name",)

    prepopulated_fields = {"slug": ("name",)}


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

    list_filter = ("is_active",)

    search_fields = ("name",)

    prepopulated_fields = {"slug": ("name",)}


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

    readonly_fields = ("image_preview",)

    def image_preview(self, obj):

        if obj.image:
            return format_html(
                '<img src="{}" width="80" height="80" '
                'style="object-fit: cover; border-radius: 6px;" />',
                obj.image.url,
            )

        return "No image"

    image_preview.short_description = "Preview"


# =========================================================
# PRODUCT VARIANT FORM WITH PLACEHOLDERS
# =========================================================


class ProductVariantAdminForm(forms.ModelForm):

    class Meta:
        model = ProductVariant
        fields = "__all__"

        widgets = {
            "ram": forms.TextInput(
                attrs={
                    "placeholder": "e.g. 8GB, 16GB, 32GB",
                }
            ),
            "storage": forms.TextInput(
                attrs={
                    "placeholder": "e.g. 128GB, 256GB, 512GB",
                }
            ),
            "price": forms.NumberInput(
                attrs={
                    "placeholder": "e.g. 274999",
                    "min": "0",
                    "step": "0.01",
                }
            ),
            "discount_percentage": forms.NumberInput(
                attrs={
                    "placeholder": "e.g. 10",
                    "min": "0",
                    "max": "100",
                    "step": "0.01",
                }
            ),
            "stock": forms.NumberInput(
                attrs={
                    "placeholder": "e.g. 10",
                    "min": "0",
                }
            ),
        }


# =========================================================
# PRODUCT VARIANT INLINE
# =========================================================


class ProductVariantInline(admin.TabularInline):

    model = ProductVariant

    form = ProductVariantAdminForm

    extra = 1

    fields = (
        "ram",
        "storage",
        "color",
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

    prepopulated_fields = {"slug": ("name",)}

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

    list_filter = ("is_primary",)

    search_fields = ("product__name",)

    readonly_fields = ("image_preview",)

    def image_preview(self, obj):

        if obj.image:
            return format_html(
                '<img src="{}" width="80" height="80" '
                'style="object-fit: cover; border-radius: 6px;" />',
                obj.image.url,
            )

        return "No image"

    image_preview.short_description = "Preview"


# =========================================================
# PRODUCT VARIANT
# =========================================================


@admin.register(ProductVariant)
class ProductVariantAdmin(admin.ModelAdmin):

    form = ProductVariantAdminForm

    list_display = (
        "product",
        "price",
        "stock",
        "is_active",
        "created_at",
    )

    list_filter = ("is_active",)

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
        "question",
        "is_approved",
        "created_at",
    )

    search_fields = (
        "product__name",
        "user__email",
        "question",
    )

    list_filter = (
        "is_approved",
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
        "review",
        "review_status",
        "created_at",
    )

    list_filter = (
        "is_approved",
        "rating",
        "created_at",
    )

    search_fields = (
        "product__name",
        "user__email",
        "review",
    )

    readonly_fields = (
        "product",
        "user",
        "rating",
        "review",
        "created_at",
        "updated_at",
    )

    fields = (
        "product",
        "user",
        "rating",
        "review",
        "is_approved",
        "created_at",
        "updated_at",
    )

    actions = [
        "approve_reviews",
        "reject_reviews",
    ]

    list_per_page = 25

    @admin.display(description="Status")
    def review_status(self, obj):

        if obj.is_approved:
            return format_html(
                '<span style="color: green; ' 'font-weight: bold;">Approved</span>'
            )

        return format_html(
            '<span style="color: #d97706; ' 'font-weight: bold;">Pending</span>'
        )

    @admin.action(permissions=["change"], description="Approve selected reviews")
    def approve_reviews(self, request, queryset):
        if not (
            request.user.is_active
            and request.user.is_staff
            and self.has_change_permission(request)
        ):
            raise PermissionDenied

        updated = queryset.update(is_approved=True)

        self.message_user(request, f"{updated} review(s) approved successfully.")

    @admin.action(permissions=["change"], description="Reject selected reviews")
    def reject_reviews(self, request, queryset):
        if not (
            request.user.is_active
            and request.user.is_staff
            and self.has_change_permission(request)
        ):
            raise PermissionDenied

        updated = queryset.update(is_approved=False)

        self.message_user(request, f"{updated} review(s) marked as pending.")


# =========================================================
# COLOR
# =========================================================


@admin.register(Color)
class ColorAdmin(admin.ModelAdmin):

    list_display = (
        "name",
        "hex_code",
        "is_active",
        "created_at",
    )

    list_filter = ("is_active",)

    search_fields = (
        "name",
        "hex_code",
    )
