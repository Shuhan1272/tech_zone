from rest_framework import serializers

from .models import Discount


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

        discount_type = attrs.get(
            'discount_type',
            getattr(self.instance, 'discount_type', None)
        )

        code = attrs.get(
            'code',
            getattr(self.instance, 'code', None)
        )

        value_type = attrs.get(
            'value_type',
            getattr(self.instance, 'value_type', None)
        )

        value = attrs.get(
            'value',
            getattr(self.instance, 'value', None)
        )

        max_discount = attrs.get(
            'max_discount',
            getattr(self.instance, 'max_discount', None)
        )

        start_date = attrs.get(
            'start_date',
            getattr(self.instance, 'start_date', None)
        )

        end_date = attrs.get(
            'end_date',
            getattr(self.instance, 'end_date', None)
        )

        usage_limit = attrs.get(
            'usage_limit',
            getattr(self.instance, 'usage_limit', None)
        )

        minimum_order_amount = attrs.get(
            'minimum_order_amount',
            getattr(self.instance, 'minimum_order_amount', 0)
        )

        # Promo code must have a code
        if discount_type == 'promo':

            if not code:
                raise serializers.ValidationError({
                    'code': 'Promo code is required.'
                })

            attrs['code'] = code.strip().upper()

        # Staff and new customer discounts do not need a code
        else:
            attrs['code'] = None

        # Discount value must be greater than 0
        if value is not None and value <= 0:
            raise serializers.ValidationError({
                'value': 'Value must be greater than 0.'
            })

        # Percentage cannot exceed 100
        if (
            value_type == 'percentage'
            and value is not None
            and value > 100
        ):
            raise serializers.ValidationError({
                'value': 'Percentage cannot be greater than 100.'
            })

        # Maximum discount only applies to percentage discounts
        if (
            value_type == 'fixed'
            and max_discount is not None
        ):
            raise serializers.ValidationError({
                'max_discount':
                    'Maximum discount is only used for percentage discounts.'
            })

        # Minimum order cannot be negative
        if minimum_order_amount < 0:
            raise serializers.ValidationError({
                'minimum_order_amount':
                    'Minimum order amount cannot be negative.'
            })

        # Usage limit must be at least 1
        if usage_limit is not None and usage_limit < 1:
            raise serializers.ValidationError({
                'usage_limit':
                    'Usage limit must be at least 1.'
            })

        # End date must be after start date
        if start_date and end_date and end_date <= start_date:
            raise serializers.ValidationError({
                'end_date':
                    'End date must be after start date.'
            })

        return attrs