from rest_framework import serializers

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
            many=True
        ).data


# =========================================================
# Product Image
# =========================================================

class ProductImageSerializer(
    serializers.ModelSerializer
):

    class Meta:

        model = ProductImage

        fields = [
            'id',
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

class ProductVariantSerializer(
    serializers.ModelSerializer
):


    class Meta:

        model = ProductVariant

        fields = [
            'id',
            'product',
            'sku',
            'options',
            'price',
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
            'price', 
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
            'id', 'name', 'slug', 'category', 'brand', 
            'key_feature','specification','colors','is_active', 'is_featured',
            'default_variant',
        ]

    def get_default_variant(self, obj):
        # obj.variants.all() is instant because of prefetch_related in the ViewSet
        variants = obj.variants.all()
        
        if not variants:
            return None

        # 1. Try to find the active, default variant
        for variant in variants:
            if variant.is_active and variant.is_default:
                return ProductVariantSerializer(variant, context=self.context).data
        
        # 2. Fallback: Just return the first active one if no default exists
        for variant in variants:
            if variant.is_active:
                return ProductVariantSerializer(variant, context=self.context).data
                
        return None


# =========================================================
# Product Detail Serializer
# =========================================================

class ProductSerializer(
    serializers.ModelSerializer
):

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

class ProductQuestionSerializer(
    serializers.ModelSerializer
):

    class Meta:

        model = ProductQuestion

        fields = [
            'id',
            'product',
            'user',
            'question',
            'answer',
            'is_approved',
            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'user',
            'answer',
            'is_approved',
            'created_at',
            'updated_at',
        ]


# =========================================================
# Product Review
# =========================================================

class ProductReviewSerializer(
    serializers.ModelSerializer
):

    class Meta:

        model = ProductReview

        fields = [
            'id',
            'product',
            'user',
            'rating',
            'review',
            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'user',
            'created_at',
            'updated_at',
        ]