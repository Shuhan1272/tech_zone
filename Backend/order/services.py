
from django.db import transaction
from django.db.models import F

from rest_framework.exceptions import ValidationError

from products.models import ProductVariant
from discounts.models import Discount

from .models import Order


# =========================================================
# CANCEL ORDER
# =========================================================

@transaction.atomic
def cancel_order(order_id):

    # =====================================================
    # LOCK ORDER
    # =====================================================

    order = (
        Order.objects
        .select_for_update()
        .get(pk=order_id)
    )

    # =====================================================
    # VALIDATE ORDER STATUS
    # =====================================================

    if order.status == 'cancelled':
        raise ValidationError({
            'status': 'This order is already cancelled.'
        })

    if order.status not in ['pending', 'confirmed']:
        raise ValidationError({
            'status': 'This order cannot be cancelled.'
        })

    # =====================================================
    # VALIDATE PAYMENT STATUS
    # =====================================================

    if order.payment_status == 'paid':
        raise ValidationError({
            'payment_status': (
                'This order has already been paid. '
                'Request a refund before cancelling.'
            )
        })

    # =====================================================
    # CHECK ACTIVE PAYMENT TRANSACTIONS
    # =====================================================

    if order.payments.filter(
        status__in=[
            'initiating',
            'pending',
            'review',
        ]
    ).exists():
        raise ValidationError({
            'payment': (
                'This order has an active payment transaction. '
                'Resolve it before cancelling.'
            )
        })

    # =====================================================
    # CHECK REFUND STATUS
    # =====================================================

    if order.payment_status == 'refunded':

        if order.payment_method != 'sslcommerz':
            raise ValidationError({
                'payment_method': (
                    'Refunded Cash on Delivery orders '
                    'require manual review.'
                )
            })

        # A refunded order must have a verified
        # SSLCommerz payment and refund record.
        verified_refund_exists = (
            order.payments.filter(
                status='refunded',
                refund__status='refunded',
                refund__completed_at__isnull=False,
            ).exists()
        )

        if not verified_refund_exists:
            raise ValidationError({
                'payment_status': (
                    'Refund verification is incomplete. '
                    'This order cannot be cancelled.'
                )
            })

    # =====================================================
    # CHECK REFUND REQUESTS
    # =====================================================

    # Prevent cancellation while a refund is awaiting
    # approval or being processed.
    if order.payments.filter(
        refund__status__in=[
            'requested',
            'approved',
            'initiating',
            'processing',
        ]
    ).exists():
        raise ValidationError({
            'refund': (
                'A refund request is currently active. '
                'Wait until it is resolved.'
            )
        })

    # =====================================================
    # CHECK PAYMENT CONSISTENCY
    # =====================================================

    # A payment marked paid must never be cancelled
    # without a completed refund, even if the order's
    # payment_status field is inconsistent.
    if order.payments.filter(
        status='paid'
    ).exists():
        raise ValidationError({
            'payment': (
                'A completed payment exists for this order. '
                'The refund must be verified first.'
            )
        })

    if (
        order.payment_method == 'sslcommerz'
        and order.payment_status == 'refunded'
        and order.payments.exclude(
            status__in=[
                'failed',
                'cancelled',
                'refunded',
            ]
        ).exists()
    ):
        raise ValidationError({
            'payment': (
                'Conflicting payment records require '
                'manual review before cancellation.'
            )
        })

    # =====================================================
    # RESTORE STOCK TO EXACT PRODUCT VARIANT
    # =====================================================

    order_items = list(
        order.items
        .select_related('variant')
        .order_by('variant_id')
    )

    for item in order_items:

        updated = (
            ProductVariant.objects
            .filter(pk=item.variant_id)
            .update(
                stock=F('stock') + item.quantity
            )
        )

        if not updated:
            raise ValidationError({
                'stock': (
                    f'Unable to restore stock for '
                    f'{item.product_name}.'
                )
            })

    # =====================================================
    # RESTORE DISCOUNT USAGE
    # =====================================================

    if order.discount_id:

        updated = (
            Discount.objects
            .filter(
                pk=order.discount_id,
                used_count__gt=0
            )
            .update(
                used_count=F('used_count') - 1
            )
        )

        if not updated:
            raise ValidationError({
                'discount': (
                    'Unable to restore discount usage.'
                )
            })

    # =====================================================
    # UPDATE ORDER STATUS
    # =====================================================

    order.status = 'cancelled'

    order.save(
        update_fields=[
            'status',
            'updated_at',
        ]
    )

    return order


# =========================================================
# CONFIRM CASH ON DELIVERY PAYMENT
# =========================================================

@transaction.atomic
def confirm_cod_payment(order_id):

    # =====================================================
    # LOCK ORDER
    # =====================================================

    order = (
        Order.objects
        .select_for_update()
        .get(pk=order_id)
    )

    # =====================================================
    # VALIDATE PAYMENT METHOD
    # =====================================================

    if order.payment_method != 'cod':
        raise ValidationError({
            'payment_method': (
                'This is not a Cash on Delivery order.'
            )
        })

    # =====================================================
    # VALIDATE ORDER STATUS
    # =====================================================

    if order.status != 'delivered':
        raise ValidationError({
            'status': (
                'The order must be delivered before '
                'confirming COD payment.'
            )
        })

    # =====================================================
    # VALIDATE PAYMENT STATUS
    # =====================================================

    if order.payment_status == 'paid':
        raise ValidationError({
            'payment_status': (
                'This order has already been paid.'
            )
        })

    if order.payment_status != 'pending':
        raise ValidationError({
            'payment_status': (
                'This order is not eligible for '
                'COD payment confirmation.'
            )
        })

    # =====================================================
    # CHECK GATEWAY PAYMENT RECORDS
    # =====================================================

    if order.payments.exists():
        raise ValidationError({
            'payment': (
                'This order has gateway payment records '
                'and requires manual review.'
            )
        })

    # =====================================================
    # CONFIRM PAYMENT
    # =====================================================

    order.payment_status = 'paid'

    order.save(
        update_fields=[
            'payment_status',
            'updated_at',
        ]
    )

    return order
