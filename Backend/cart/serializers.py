from rest_framework import serializers
from .models import Cart, CartItem


class CartItemSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(
        source='variant.product.name',
        read_only=True
    )
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

    class Meta:
        model = CartItem
        fields = [
            'id',
            'variant',
            'product_name',
            'variant_price',
            'discounted_price',
            'quantity',
        ]


class CartSerializer(serializers.ModelSerializer):
    items = CartItemSerializer(many=True, read_only=True)

    class Meta:
        model = Cart
        fields = [
            'id',
            'items',
            'created_at',
            'updated_at',
        ]