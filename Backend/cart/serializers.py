
from rest_framework import serializers

from .models import Cart, CartItem
from products.models import ProductImage
from products.serializers import ColorSerializer


# =========================================================
# CART ITEM SERIALIZER
# =========================================================

class CartItemSerializer(serializers.ModelSerializer):

    product_name = serializers.CharField(
        source='variant.product.name',
        read_only=True
    )

    product_id = serializers.IntegerField(
        source='variant.product.id',
        read_only=True
    )

    sku = serializers.CharField(
        source='variant.sku',
        read_only=True
    )

    # =====================================================
    # RAM, STORAGE AND COLOR
    # =====================================================

    ram = serializers.CharField(
        source='variant.ram',
        read_only=True,
        allow_null=True
    )

    storage = serializers.CharField(
        source='variant.storage',
        read_only=True,
        allow_null=True
    )

    color = ColorSerializer(
        source='variant.color',
        read_only=True
    )

    # =====================================================
    # PRICE AND STOCK
    # =====================================================

    variant_price = serializers.DecimalField(
        source='variant.price',
        max_digits=12,
        decimal_places=2,
        read_only=True
    )

    discounted_price = serializers.DecimalField(
        source='variant.discounted_price',
        max_digits=12,
        decimal_places=2,
        read_only=True
    )

    discount_percentage = serializers.DecimalField(
        source='variant.discount_percentage',
        max_digits=5,
        decimal_places=2,
        read_only=True
    )

    stock = serializers.IntegerField(
        source='variant.stock',
        read_only=True
    )

    # =====================================================
    # PRODUCT IMAGE
    # =====================================================

    product_image = serializers.SerializerMethodField()

    # =====================================================
    # SUBTOTAL
    # =====================================================

    subtotal = serializers.SerializerMethodField()

    class Meta:
        model = CartItem

        fields = [
            'id',
            'variant',
            'product_id',
            'product_name',
            'product_image',
            'sku',
            'ram',
            'storage',
            'color',
            'variant_price',
            'discount_percentage',
            'discounted_price',
            'stock',
            'quantity',
            'subtotal',
        ]

        read_only_fields = [
            'id',
            'product_id',
            'product_name',
            'product_image',
            'sku',
            'ram',
            'storage',
            'color',
            'variant_price',
            'discount_percentage',
            'discounted_price',
            'stock',
            'subtotal',
        ]

    # =====================================================
    # GET PRODUCT IMAGE
    # =====================================================

    def get_product_image(self, obj):

        product = obj.variant.product

        image = (
            ProductImage.objects
            .filter(
                product=product,
                is_primary=True
            )
            .first()
        )

        if image is None:
            image = (
                ProductImage.objects
                .filter(product=product)
                .first()
            )

        if image is None or not image.image:
            return None

        request = self.context.get('request')

        if request:
            return request.build_absolute_uri(
                image.image.url
            )

        return image.image.url

    # =====================================================
    # GET SUBTOTAL
    # =====================================================

    def get_subtotal(self, obj):

        subtotal = (
            obj.variant.discounted_price *
            obj.quantity
        )

        return str(round(subtotal, 2))


# =========================================================
# CART SERIALIZER
# =========================================================

class CartSerializer(serializers.ModelSerializer):

    items = CartItemSerializer(
        many=True,
        read_only=True
    )

    total_items = serializers.SerializerMethodField()

    total_price = serializers.SerializerMethodField()

    class Meta:
        model = Cart

        fields = [
            'id',
            'items',
            'total_items',
            'total_price',
            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'items',
            'total_items',
            'total_price',
            'created_at',
            'updated_at',
        ]

    # =====================================================
    # TOTAL ITEMS
    # =====================================================

    def get_total_items(self, obj):

        return sum(
            item.quantity
            for item in obj.items.all()
        )

    # =====================================================
    # TOTAL PRICE
    # =====================================================

    def get_total_price(self, obj):

        total = sum(
            (
                item.variant.discounted_price *
                item.quantity
            )
            for item in obj.items.all()
        )

        return str(round(total, 2))
