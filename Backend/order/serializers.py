
import re

from rest_framework import serializers

from .models import Order, OrderItem
from products.models import ProductImage


# =========================================================
# ORDER ITEM
# =========================================================

class OrderItemSerializer(serializers.ModelSerializer):

    product_image = serializers.SerializerMethodField()

    class Meta:
        model = OrderItem

        fields = [
            'id',
            'variant',
            'product_name',
            'product_image',
            'sku',

            # Purchased configuration snapshots
            'ram',
            'storage',
            'color_name',

            'unit_price',
            'quantity',
            'line_total',
        ]

        read_only_fields = fields

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


# =========================================================
# ORDER DETAILS
# =========================================================

class OrderSerializer(serializers.ModelSerializer):

    items = OrderItemSerializer(
        many=True,
        read_only=True
    )

    payment_method_display = serializers.CharField(
        source='get_payment_method_display',
        read_only=True
    )

    class Meta:
        model = Order

        fields = [
            'id',
            'user',

            'shipping_name',
            'shipping_phone',
            'shipping_address',

            'shipping_house',
            'shipping_road',
            'shipping_division',
            'shipping_district',
            'shipping_upazila',
            'shipping_postal_code',
            'shipping_instructions',

            'items',

            'subtotal',
            'discount',
            'discount_code',
            'discount_amount',
            'total_amount',

            'status',

            'payment_method',
            'payment_method_display',
            'payment_status',

            'created_at',
            'updated_at',
        ]

        read_only_fields = fields


# =========================================================
# CHECKOUT
# =========================================================

class CheckoutSerializer(serializers.Serializer):

    # =====================================================
    # CUSTOMER INFORMATION
    # =====================================================

    shipping_name = serializers.CharField(
        max_length=150
    )

    shipping_phone = serializers.CharField(
        max_length=20
    )

    # =====================================================
    # SHIPPING ADDRESS
    # =====================================================

    shipping_house = serializers.CharField(
        max_length=200
    )

    shipping_road = serializers.CharField(
        max_length=200
    )

    shipping_division = serializers.ChoiceField(
        choices=Order.DIVISION_CHOICES
    )

    shipping_district = serializers.CharField(
        max_length=100
    )

    shipping_upazila = serializers.CharField(
        max_length=100
    )

    shipping_postal_code = serializers.CharField(
        max_length=4
    )

    shipping_instructions = serializers.CharField(
        required=False,
        allow_blank=True,
        default=''
    )

    # =====================================================
    # PAYMENT METHOD
    # =====================================================

    payment_method = serializers.ChoiceField(
        choices=Order.PAYMENT_METHOD_CHOICES,
        default='sslcommerz'
    )

    # =====================================================
    # DISCOUNT
    # =====================================================

    discount_type = serializers.ChoiceField(
        choices=[
            'promo',
            'staff',
            'new_customer'
        ],
        required=False,
        allow_null=True
    )

    discount_code = serializers.CharField(
        max_length=50,
        required=False,
        allow_blank=True,
        allow_null=True
    )

    # =====================================================
    # PHONE VALIDATION
    # =====================================================

    def validate_shipping_phone(self, value):

        value = re.sub(
            r'[\s-]+',
            '',
            value.strip()
        )

        # Accepted formats:
        # 01XXXXXXXXX
        # +8801XXXXXXXXX
        # 8801XXXXXXXXX

        if value.startswith('+880'):
            value = '0' + value[4:]

        elif value.startswith('880'):
            value = '0' + value[3:]

        if not re.fullmatch(
            r'01[3-9]\d{8}',
            value
        ):
            raise serializers.ValidationError(
                'Enter a valid Bangladesh mobile number.'
            )

        return value

    # =====================================================
    # POSTAL CODE VALIDATION
    # =====================================================

    def validate_shipping_postal_code(self, value):

        value = value.strip()

        if not re.fullmatch(
            r'\d{4}',
            value
        ):
            raise serializers.ValidationError(
                'Postal code must contain exactly 4 digits.'
            )

        return value

    # =====================================================
    # COMPLETE VALIDATION
    # =====================================================

    def validate(self, attrs):

        discount_type = attrs.get('discount_type')

        code = (
            attrs.get('discount_code') or ''
        ).strip().upper()

        # =================================================
        # DISCOUNT VALIDATION
        # =================================================

        # If a code is provided without a discount type,
        # let the checkout service identify its actual type.

        if code and not discount_type:
            discount_type = 'promo'

        # Promo discounts must have a code.
        if discount_type == 'promo' and not code:
            raise serializers.ValidationError({
                'discount_code':
                    'Discount code is required.'
            })

        # Staff and new-customer discounts may have codes.
        # Their eligibility is checked by discounts/services.py.

        attrs['discount_type'] = discount_type
        attrs['discount_code'] = code

        # =================================================
        # BUILD COMPLETE SHIPPING ADDRESS
        # =================================================

        division_labels = dict(
            Order.DIVISION_CHOICES
        )

        division = attrs['shipping_division']

        division_name = division_labels.get(
            division,
            division
        )

        address_parts = [
            attrs['shipping_house'],
            attrs['shipping_road'],
            attrs['shipping_upazila'],
            attrs['shipping_district'],
            division_name,
            attrs['shipping_postal_code'],
            'Bangladesh',
        ]

        attrs['shipping_address'] = ', '.join(
            str(part).strip()
            for part in address_parts
            if str(part).strip()
        )

        return attrs
