
from decimal import Decimal

from rest_framework import serializers

from .models import Discount
from .services import validate_checkout_discount


# =========================================================
# DISCOUNT SERIALIZER
# =========================================================

class DiscountSerializer(serializers.ModelSerializer):

    class Meta:
        model = Discount

        fields = [
            'id',
            'name',
            'discount_type',
            'code',
            'value_type',
            'value',
            'max_discount',
            'minimum_order_amount',
            'usage_limit',
            'used_count',
            'start_date',
            'end_date',
            'is_active',
            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'used_count',
            'created_at',
            'updated_at',
        ]

    def validate(self, attrs):

        def get_value(field, default=None):
            return attrs.get(
                field,
                getattr(self.instance, field, default)
            )

        discount_type = get_value('discount_type')
        code = get_value('code')
        value_type = get_value('value_type')
        value = get_value('value')
        max_discount = get_value('max_discount')
        minimum = get_value(
            'minimum_order_amount',
            Decimal('0.00')
        )
        usage_limit = get_value('usage_limit')
        start_date = get_value('start_date')
        end_date = get_value('end_date')

        # =================================================
        # DISCOUNT CODE
        # =================================================

        code = (code or '').strip().upper()

        if discount_type == 'promo' and not code:
            raise serializers.ValidationError({
                'code': 'Promo code is required.'
            })

        # Staff and new-customer discounts may have codes.
        attrs['code'] = code or None

        # =================================================
        # DISCOUNT VALUE
        # =================================================

        if value is not None and value <= 0:
            raise serializers.ValidationError({
                'value': 'Value must be greater than 0.'
            })

        if (
            value_type == 'percentage'
            and value is not None
            and value > 100
        ):
            raise serializers.ValidationError({
                'value': 'Percentage cannot exceed 100.'
            })

        # =================================================
        # MAXIMUM DISCOUNT
        # =================================================

        if (
            value_type == 'fixed'
            and max_discount is not None
        ):
            raise serializers.ValidationError({
                'max_discount':
                    'Maximum discount is only for percentage discounts.'
            })

        if (
            max_discount is not None
            and max_discount <= 0
        ):
            raise serializers.ValidationError({
                'max_discount':
                    'Maximum discount must be greater than 0.'
            })

        # =================================================
        # MINIMUM ORDER
        # =================================================

        if minimum is not None and minimum < 0:
            raise serializers.ValidationError({
                'minimum_order_amount':
                    'Minimum order cannot be negative.'
            })

        # =================================================
        # USAGE LIMIT
        # =================================================

        if usage_limit is not None and usage_limit < 1:
            raise serializers.ValidationError({
                'usage_limit':
                    'Usage limit must be at least 1.'
            })

        # =================================================
        # DATE VALIDATION
        # =================================================

        if (
            start_date
            and end_date
            and end_date <= start_date
        ):
            raise serializers.ValidationError({
                'end_date':
                    'End date must be after start date.'
            })

        return attrs


# =========================================================
# DISCOUNT VALIDATION SERIALIZER
# =========================================================

class DiscountValidationSerializer(serializers.Serializer):

    discount_type = serializers.ChoiceField(
        choices=[
            'promo',
            'staff',
            'new_customer'
        ],
        default='promo'
    )

    code = serializers.CharField(
        max_length=50,
        required=False,
        allow_blank=True,
        trim_whitespace=True
    )

    order_amount = serializers.DecimalField(
        max_digits=12,
        decimal_places=2,
        min_value=Decimal('0.01')
    )

    def validate(self, attrs):

        request = self.context.get('request')

        if request is None:
            raise serializers.ValidationError({
                'discount_type':
                    'Request context is required.'
            })

        user = request.user

        discount_type = attrs.get(
            'discount_type',
            'promo'
        )

        code = (
            attrs.get('code') or ''
        ).strip().upper()

        order_amount = attrs['order_amount']

        # =================================================
        # USE THE SAME VALIDATION AS CHECKOUT
        # =================================================

        discount = validate_checkout_discount(
            user=user,
            discount_type=discount_type,
            code=code,
            subtotal=order_amount
        )

        if discount is None:
            raise serializers.ValidationError({
                'code': 'No discount selected.'
            })

        # =================================================
        # RETURN VALIDATED DISCOUNT
        # =================================================

        attrs['code'] = code
        attrs['discount'] = discount

        # Store actual discount type.
        # For example, NEW20 is new_customer,
        # even if frontend sends discount_type=promo.

        attrs['discount_type'] = discount.discount_type

        return attrs
