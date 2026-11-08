from decimal import Decimal

from rest_framework import serializers

from products.models import ProductVariant
from .models import WishlistItem


class WishlistAddSerializer(serializers.Serializer):
    variant_id = serializers.PrimaryKeyRelatedField(
        source='variant',
        queryset=ProductVariant.objects.filter(
            is_active=True,
            product__is_active=True
        )
    )


class WishlistItemSerializer(serializers.ModelSerializer):
    variant_id = serializers.IntegerField(read_only=True)
    product_id = serializers.IntegerField(
        source='variant.product_id',
        read_only=True
    )
    product_name = serializers.CharField(
        source='variant.product.name',
        read_only=True
    )
    product_slug = serializers.CharField(
        source='variant.product.slug',
        read_only=True
    )
    category = serializers.CharField(
        source='variant.product.category.name',
        read_only=True
    )
    sku = serializers.CharField(
        source='variant.sku',
        read_only=True
    )
    options = serializers.JSONField(
        source='variant.options',
        read_only=True
    )
    price = serializers.DecimalField(
        source='variant.price',
        max_digits=12,
        decimal_places=2,
        read_only=True
    )
    discounted_price = serializers.SerializerMethodField()
    stock = serializers.IntegerField(
        source='variant.stock',
        read_only=True
    )
    image = serializers.SerializerMethodField()
    is_available = serializers.SerializerMethodField()

    class Meta:
        model = WishlistItem
        fields = [
            'id',
            'variant_id',
            'product_id',
            'product_name',
            'product_slug',
            'category',
            'sku',
            'options',
            'image',
            'price',
            'discounted_price',
            'stock',
            'is_available',
            'created_at',
        ]

    def get_discounted_price(self, obj):
        return str(
            Decimal(str(obj.variant.discounted_price)).quantize(
                Decimal('0.01')
            )
        )

    def get_image(self, obj):
        images = list(obj.variant.product.images.all())
        picture = next(
            (img for img in images if img.is_primary),
            images[0] if images else None
        )

        if not picture or not picture.image:
            return None

        url = picture.image.url
        request = self.context.get('request')
        return request.build_absolute_uri(url) if request else url

    def get_is_available(self, obj):
        variant = obj.variant
        return (
            variant.is_active
            and variant.product.is_active
            and variant.stock > 0
        )