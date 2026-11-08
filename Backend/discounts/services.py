
from decimal import Decimal, ROUND_HALF_UP

from django.utils import timezone
from rest_framework.exceptions import ValidationError

from .models import Discount


# =========================================================
# STAFF ELIGIBILITY
# =========================================================

def is_staff_eligible(user):

    return (
        user is not None
        and user.is_authenticated
        and getattr(user, 'is_active', False)
        and getattr(user, 'is_staff', False)
    )


# =========================================================
# NEW CUSTOMER ELIGIBILITY
# =========================================================

def is_new_customer(user):

    if user is None or not user.is_authenticated:
        return False

    from order.models import Order

    return not Order.objects.filter(
        user=user
    ).exclude(
        status='cancelled'
    ).exists()


# =========================================================
# VALIDATE DISCOUNT
# =========================================================

def validate_checkout_discount(
    user,
    discount_type=None,
    code='',
    subtotal=Decimal('0.00')
):

    code = (code or '').strip().upper()
    subtotal = Decimal(str(subtotal))

    # No discount selected
    if not discount_type and not code:
        return None

    # =====================================================
    # FIND DISCOUNT
    # =====================================================

    if code:

        # Support all three discount types using codes.

        discount = Discount.objects.filter(
            code__iexact=code,
            is_active=True
        ).order_by('-created_at', '-id').first()

        if discount is None:
            raise ValidationError({
                'discount_code': 'Discount not found.'
            })

    else:

        if discount_type == 'promo':
            raise ValidationError({
                'discount_code': 'Promo code is required.'
            })

        if discount_type not in [
            'staff',
            'new_customer'
        ]:
            raise ValidationError({
                'discount_type': 'Invalid discount type.'
            })

        discount = Discount.objects.filter(
            discount_type=discount_type,
            is_active=True
        ).order_by('-created_at', '-id').first()

        if discount is None:
            raise ValidationError({
                'discount_type':
                    'No active discount found.'
            })

    # =====================================================
    # CHECK DISCOUNT TYPE
    # =====================================================

    if discount.discount_type not in [
        'promo',
        'staff',
        'new_customer'
    ]:
        raise ValidationError({
            'discount_type': 'Unsupported discount type.'
        })

    # =====================================================
    # CHECK STAFF ELIGIBILITY
    # =====================================================

    if discount.discount_type == 'staff':

        if not is_staff_eligible(user):
            raise ValidationError({
                'discount_type':
                    'You are not eligible for staff discount.'
            })

    # =====================================================
    # CHECK NEW CUSTOMER ELIGIBILITY
    # =====================================================

    if discount.discount_type == 'new_customer':

        if not is_new_customer(user):
            raise ValidationError({
                'discount_type':
                    'This discount is only for new customers.'
            })

    # =====================================================
    # CHECK DISCOUNT DATES
    # =====================================================

    now = timezone.now()

    if discount.start_date is not None:

        if now < discount.start_date:
            raise ValidationError({
                'discount_type':
                    'Discount has not started yet.'
            })

    if discount.end_date is not None:

        if now > discount.end_date:
            raise ValidationError({
                'discount_type':
                    'Discount has expired.'
            })

    # =====================================================
    # CHECK USAGE LIMIT
    # =====================================================

    if discount.usage_limit is not None:

        if discount.used_count >= discount.usage_limit:
            raise ValidationError({
                'discount_type':
                    'Discount usage limit reached.'
            })

    # =====================================================
    # CHECK MINIMUM ORDER AMOUNT
    # =====================================================

    minimum = discount.minimum_order_amount

    if minimum is not None and subtotal < minimum:
        raise ValidationError({
            'discount_type':
                f'Minimum order amount is {minimum}.'
        })

    # =====================================================
    # CHECK DISCOUNT CONFIGURATION
    # =====================================================

    if discount.value_type not in [
        'percentage',
        'fixed'
    ]:
        raise ValidationError({
            'discount_type':
                'Invalid discount value type.'
        })

    if discount.value <= 0:
        raise ValidationError({
            'discount_type':
                'Discount value must be greater than zero.'
        })

    if (
        discount.value_type == 'percentage'
        and discount.value > 100
    ):
        raise ValidationError({
            'discount_type':
                'Percentage discount cannot exceed 100.'
        })

    if discount.max_discount is not None:

        if discount.max_discount <= 0:
            raise ValidationError({
                'discount_type':
                    'Invalid maximum discount.'
            })

        if discount.value_type != 'percentage':
            raise ValidationError({
                'discount_type':
                    'Maximum discount is only for percentages.'
            })

    return discount


# =========================================================
# CALCULATE DISCOUNT
# =========================================================

def calculate_discount(discount, subtotal):

    if discount is None:
        return Decimal('0.00')

    subtotal = Decimal(str(subtotal))

    if discount.value_type == 'percentage':

        amount = (
            subtotal
            * Decimal(str(discount.value))
            / Decimal('100')
        )

        if discount.max_discount is not None:
            amount = min(
                amount,
                Decimal(str(discount.max_discount))
            )

    elif discount.value_type == 'fixed':

        amount = Decimal(str(discount.value))

    else:

        raise ValidationError({
            'discount_type': 'Invalid discount value type.'
        })

    # Prevent negative totals
    amount = max(
        Decimal('0.00'),
        min(amount, subtotal)
    )

    return amount.quantize(
        Decimal('0.01'),
        rounding=ROUND_HALF_UP
    )
