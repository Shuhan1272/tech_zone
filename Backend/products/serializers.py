
from rest_framework import serializers

from .models import (
    Category,
    Brand,
    Product,
    ProductVariant,
    ProductImage,
    ProductQuestion,
    ProductReview,
    Color,
)


# =========================================================
# Brand
# =========================================================

class BrandSerializer(serializers.ModelSerializer):

    class Meta:
        model = Brand

        fields = [
            'id',
            'name',
            'description',
            'slug',
            'is_active',
            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'slug',
            'created_at',
            'updated_at',
        ]


# =========================================================
# Category
# =========================================================

class CategorySerializer(serializers.ModelSerializer):

    brands = BrandSerializer(
        many=True,
        read_only=True
    )

    sub_categories = serializers.SerializerMethodField()

    class Meta:
        model = Category

        fields = [
            'id',
            'name',
            'description',
            'filters',
            'slug',
            'image',
            'brands',
            'sub_categories',
            'is_active',
            'is_featured',
            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'slug',
            'brands',
            'sub_categories',
            'created_at',
            'updated_at',
        ]

    def get_sub_categories(self, obj):

        sub_categories = Category.objects.filter(
            parent=obj,
            is_active=True
        )

        return CategorySerializer(
            sub_categories,
            many=True,
            context=self.context
        ).data


# =========================================================
# Color
# =========================================================

class ColorSerializer(serializers.ModelSerializer):

    class Meta:
        model = Color

        fields = [
            'id',
            'name',
            'hex_code',
        ]

        read_only_fields = [
            'id',
            'name',
            'hex_code',
        ]


# =========================================================
# Product Image
# =========================================================

class ProductImageSerializer(serializers.ModelSerializer):

    class Meta:
        model = ProductImage

        fields = [
            'id',
            'product',
            'image',
            'alt_text',
            'is_primary',
            'display_order',
            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'alt_text',
            'created_at',
            'updated_at',
        ]


# =========================================================
# Product Variant
# =========================================================

class ProductVariantSerializer(serializers.ModelSerializer):

    color = ColorSerializer(
        read_only=True
    )

    class Meta:
        model = ProductVariant

        fields = [
            'id',
            'product',
            'sku',
            'price',
            'ram',
            'storage',
            'color',
            'discount_percentage',
            'discounted_price',
            'saved_price',
            'stock',
            'is_default',
            'is_active',
            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'sku',
            'discounted_price',
            'saved_price',
            'created_at',
            'updated_at',
        ]

    def validate_price(self, value):

        if value <= 0:
            raise serializers.ValidationError(
                'Price must be greater than 0.'
            )

        return value

    def validate_discount_percentage(self, value):

        if value < 0 or value > 100:
            raise serializers.ValidationError(
                'Discount must be between 0 and 100%.'
            )

        return value


# =========================================================
# Product List Serializer
# =========================================================

class ProductListSerializer(serializers.ModelSerializer):

    brand = serializers.StringRelatedField()
    category = serializers.StringRelatedField()

    default_variant = serializers.SerializerMethodField()

    class Meta:
        model = Product

        fields = [
            'id',
            'name',
            'slug',
            'category',
            'brand',
            'key_feature',
            'specification',
            'is_active',
            'is_featured',
            'default_variant',
        ]

    def get_default_variant(self, obj):

        variants = obj.variants.all()

        if not variants:
            return None

        for variant in variants:
            if variant.is_active and variant.is_default:
                return ProductVariantSerializer(
                    variant,
                    context=self.context
                ).data

        for variant in variants:
            if variant.is_active:
                return ProductVariantSerializer(
                    variant,
                    context=self.context
                ).data

        return None


# =========================================================
# Product Detail Serializer
# =========================================================

class ProductSerializer(serializers.ModelSerializer):

    category = serializers.StringRelatedField()
    brand = serializers.StringRelatedField()

    variants = ProductVariantSerializer(
        many=True,
        read_only=True
    )

    class Meta:
        model = Product

        fields = [
            'id',
            'category',
            'brand',
            'name',
            'slug',
            'description',
            'key_feature',
            'specification',
            'is_active',
            'is_featured',
            'variants',
            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'slug',
            'variants',
            'created_at',
            'updated_at',
        ]

    def validate_name(self, value):

        if not value.strip():
            raise serializers.ValidationError(
                'Product name cannot be empty.'
            )

        return value


# =========================================================
# Product Question
# =========================================================

class ProductQuestionSerializer(serializers.ModelSerializer):

    user_name = serializers.SerializerMethodField()

    class Meta:
        model = ProductQuestion

        fields = [
            'id',
            'product',
            'user',
            'user_name',
            'question',
            'answer',
            'is_approved',
            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'user',
            'user_name',
            'answer',
            'is_approved',
            'created_at',
            'updated_at',
        ]

    def get_user_name(self, obj):

        user = obj.user

        full_name = (
            f"{user.first_name} {user.last_name}"
        ).strip()

        return full_name or "Customer"


# =========================================================
# Product Review
# =========================================================

class ProductReviewSerializer(serializers.ModelSerializer):

    user_name = serializers.SerializerMethodField()

    class Meta:
        model = ProductReview

        fields = [
            'id',
            'product',
            'user',
            'user_name',
            'rating',
            'review',
            'is_approved',
            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'user',
            'user_name',
            'is_approved',
            'created_at',
            'updated_at',
        ]

    def get_user_name(self, obj):

        user = obj.user

        full_name = (
            f"{user.first_name} {user.last_name}"
        ).strip()

        return full_name or "Customer"

    def validate_rating(self, value):

        if not 1 <= value <= 5:
            raise serializers.ValidationError(
                'Rating must be between 1 and 5.'
            )

        return value

    def validate_review(self, value):

        if not value.strip():
            raise serializers.ValidationError(
                'Review cannot be empty.'
            )

        return value
