from decimal import Decimal, InvalidOperation
from urllib.parse import urlencode

import requests

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from order.models import Order

from .models import Payment, PaymentRefund


# =========================================================
# GATEWAY ERROR
# =========================================================

class GatewayError(Exception):
    pass


# =========================================================
# GATEWAY CONFIGURATION
# =========================================================

def gateway_base_url():
    return (
        'https://sandbox.sslcommerz.com'
        if settings.SSLCOMMERZ_SANDBOX
        else 'https://securepay.sslcommerz.com'
    )


def gateway_credentials():
    if (
        not settings.SSLCOMMERZ_STORE_ID
        or not settings.SSLCOMMERZ_STORE_PASSWORD
    ):
        raise GatewayError(
            'SSLCommerz credentials are missing.'
        )

    return {
        'store_id': settings.SSLCOMMERZ_STORE_ID,
        'store_passwd': settings.SSLCOMMERZ_STORE_PASSWORD,
    }


def gateway_request(method, endpoint, data):
    url = gateway_base_url() + endpoint

    try:
        if method.upper() == 'POST':
            response = requests.post(
                url,
                data=data,
                timeout=(5, 20)
            )
        else:
            response = requests.get(
                url,
                params=data,
                timeout=(5, 20)
            )

        response.raise_for_status()
        result = response.json()

    except (requests.RequestException, ValueError) as exc:
        raise GatewayError(
            'Could not communicate with SSLCommerz.'
        ) from exc

    if not isinstance(result, dict):
        raise GatewayError(
            'Invalid response from SSLCommerz.'
        )

    return result


# =========================================================
# CREATE GATEWAY SESSION
# =========================================================

def create_gateway_session(payment):
    order = payment.order

    if order.payment_method != 'sslcommerz':
        raise GatewayError(
            'SSLCommerz is not available for COD orders.'
        )

    backend_url = settings.SSLCOMMERZ_BACKEND_URL.rstrip('/')

    local_sandbox = (
        settings.DEBUG
        and settings.SSLCOMMERZ_SANDBOX
        and backend_url.startswith((
            'http://localhost:',
            'http://127.0.0.1:',
        ))
    )

    if not backend_url.startswith('https://') and not local_sandbox:
        raise GatewayError(
            'SSLCommerz backend URL must use HTTPS.'
        )

    payload = {
        **gateway_credentials(),

        # Transaction
        'total_amount': str(payment.amount),
        'currency': 'BDT',
        'tran_id': payment.transaction_id,

        # Callbacks
        'success_url':
            f'{backend_url}/api/v1/payments/callback/success/',

        'fail_url':
            f'{backend_url}/api/v1/payments/callback/fail/',

        'cancel_url':
            f'{backend_url}/api/v1/payments/callback/cancel/',

        'ipn_url':
            f'{backend_url}/api/v1/payments/callback/ipn/',

        'emi_option': '0',

        # Customer
        'cus_name': order.shipping_name[:50],
        'cus_email': order.user.email[:50],
        'cus_phone': order.shipping_phone[:20],
        'cus_add1': order.shipping_address[:50],
        'cus_city': order.shipping_district[:50],
        'cus_state': order.get_shipping_division_display(),
        'cus_postcode': order.shipping_postal_code,
        'cus_country': 'Bangladesh',

        # Shipping
        'shipping_method': 'YES',
        'ship_name': order.shipping_name[:50],
        'ship_add1': order.shipping_address[:50],
        'ship_city': order.shipping_district[:50],
        'ship_state': order.get_shipping_division_display(),
        'ship_postcode': order.shipping_postal_code,
        'ship_country': 'Bangladesh',

        # Product
        'num_of_item': sum(
            item.quantity
            for item in order.items.all()
        ),
        'product_name': f'TechZone Order #{order.pk}',
        'product_category': 'Electronics',
        'product_profile': 'physical-goods',

        'value_a': str(order.pk),
    }

    result = gateway_request(
        'POST',
        '/gwprocess/v4/api.php',
        payload
    )

    if (
        result.get('status') != 'SUCCESS'
        or not result.get('GatewayPageURL')
    ):
        raise GatewayError(
            'SSLCommerz could not create a payment session.'
        )

    return result


# =========================================================
# VALIDATE GATEWAY TRANSACTION
# =========================================================

def validate_gateway_transaction(validation_id):
    return gateway_request(
        'GET',
        '/validator/api/validationserverAPI.php',
        {
            **gateway_credentials(),
            'val_id': validation_id,
            'format': 'json',
        }
    )


# =========================================================
# QUERY GATEWAY TRANSACTION
# =========================================================

def query_gateway_transaction(transaction_id):
    return gateway_request(
        'GET',
        '/validator/api/merchantTransIDvalidationAPI.php',
        {
            **gateway_credentials(),
            'tran_id': transaction_id,
            'format': 'json',
        }
    )


# =========================================================
# CONFIRM GATEWAY PAYMENT
# =========================================================

def confirm_gateway_payment(transaction_id, validation_id):
    if not transaction_id or not validation_id:
        raise GatewayError(
            'Missing transaction information.'
        )

    payment = Payment.objects.filter(
        transaction_id=transaction_id
    ).first()

    if payment is None:
        raise GatewayError(
            'Unknown payment transaction.'
        )

    result = validate_gateway_transaction(validation_id)

    if (
        result.get('APIConnect') != 'DONE'
        or result.get('status') not in ('VALID', 'VALIDATED')
        or result.get('tran_id') != transaction_id
        or result.get('val_id') != validation_id
    ):
        raise GatewayError(
            'SSLCommerz did not verify this payment.'
        )

    if (
        result.get('currency') != 'BDT'
        or result.get('currency_type', 'BDT') != 'BDT'
    ):
        raise GatewayError(
            'Payment currency does not match.'
        )

    if (
        result.get('store_id')
        and result['store_id'] != settings.SSLCOMMERZ_STORE_ID
    ):
        raise GatewayError(
            'Store ID does not match.'
        )

    if (
        result.get('value_a')
        and str(result['value_a']) != str(payment.order_id)
    ):
        raise GatewayError(
            'Order reference does not match.'
        )

    try:
        amount = Decimal(str(result['amount']))
        original_amount = Decimal(
            str(result.get('currency_amount', result['amount']))
        )

    except (KeyError, InvalidOperation, TypeError) as exc:
        raise GatewayError(
            'Invalid payment amount.'
        ) from exc

    if (
        amount != payment.amount
        or original_amount != payment.amount
    ):
        raise GatewayError(
            'Payment amount does not match.'
        )

    with transaction.atomic():
        order = Order.objects.select_for_update().get(
            pk=payment.order_id
        )

        payment = Payment.objects.select_for_update().get(
            pk=payment.pk
        )

        if payment.status in ('paid', 'refunded', 'review'):
            return payment

        payment.validation_id = validation_id

        payment.bank_transaction_id = str(
            result.get('bank_tran_id') or ''
        )

        payment.payment_method = str(
            result.get('card_type') or ''
        )

        try:
            payment.risk_level = int(
                result.get('risk_level', 1)
            )
        except (TypeError, ValueError):
            payment.risk_level = 1

        if (
            order.payment_method != 'sslcommerz'
            or order.status == 'cancelled'
            or order.payment_status in ('paid', 'refunded')
            or order.total_amount != payment.amount
        ):
            payment.status = 'review'
            payment.review_reason = 'order_conflict'

        elif payment.risk_level != 0:
            payment.status = 'review'
            payment.review_reason = 'risk'

        else:
            payment.status = 'paid'
            payment.review_reason = ''

            order.payment_status = 'paid'
            order.save(
                update_fields=['payment_status', 'updated_at']
            )

        payment.save()

    return payment


# =========================================================
# RECONCILE GATEWAY PAYMENT
# =========================================================

def reconcile_gateway_payment(payment):
    if payment.status in ('paid', 'refunded', 'review'):
        return payment

    result = query_gateway_transaction(
        payment.transaction_id
    )

    if result.get('APIConnect') != 'DONE':
        raise GatewayError(
            'Could not query SSLCommerz transaction.'
        )

    records = result.get('element') or []

    if isinstance(records, dict):
        records = [records]

    if not isinstance(records, list):
        raise GatewayError(
            'Invalid gateway transaction response.'
        )

    for record in records:
        if (
            isinstance(record, dict)
            and record.get('tran_id') == payment.transaction_id
            and record.get('status') in ('VALID', 'VALIDATED')
            and record.get('val_id')
        ):
            return confirm_gateway_payment(
                payment.transaction_id,
                record['val_id']
            )

    statuses = [
        record.get('status')
        for record in records
        if (
            isinstance(record, dict)
            and record.get('tran_id') == payment.transaction_id
        )
    ]

    terminal = {
        'FAILED',
        'CANCELLED',
        'EXPIRED',
        'UNATTEMPTED',
    }

    if statuses and all(value in terminal for value in statuses):
        with transaction.atomic():
            order = Order.objects.select_for_update().get(
                pk=payment.order_id
            )

            payment = Payment.objects.select_for_update().get(
                pk=payment.pk
            )

            if payment.status in ('initiating', 'pending'):
                payment.status = (
                    'cancelled'
                    if all(s == 'CANCELLED' for s in statuses)
                    else 'failed'
                )

                payment.save(
                    update_fields=['status', 'updated_at']
                )

                if order.payment_status == 'pending':
                    order.payment_status = 'failed'
                    order.save(
                        update_fields=['payment_status', 'updated_at']
                    )

    payment.refresh_from_db()
    return payment


# =========================================================
# APPROVE REVIEWED PAYMENT
# =========================================================

def approve_reviewed_payment(payment_id):
    try:
        order_id = Payment.objects.values_list(
            'order_id',
            flat=True
        ).get(pk=payment_id)

    except Payment.DoesNotExist as exc:
        raise GatewayError(
            'Payment does not exist.'
        ) from exc

    with transaction.atomic():
        order = Order.objects.select_for_update().get(
            pk=order_id
        )

        payment = Payment.objects.select_for_update().get(
            pk=payment_id
        )

        if (
            payment.status != 'review'
            or payment.review_reason != 'risk'
            or not payment.validation_id
            or order.payment_method != 'sslcommerz'
            or order.status not in ('pending', 'confirmed')
            or order.payment_status not in ('pending', 'failed')
            or order.total_amount != payment.amount
        ):
            raise GatewayError(
                'Payment is not eligible for risk approval.'
            )

        payment.status = 'paid'
        payment.review_reason = ''

        payment.save(
            update_fields=[
                'status',
                'review_reason',
                'updated_at',
            ]
        )

        order.payment_status = 'paid'
        order.save(
            update_fields=['payment_status', 'updated_at']
        )

    return payment


# =========================================================
# LOCK PAYMENT AND ORDER
# =========================================================

def _locked_payment_and_order(payment_id):
    """
    Must be called inside transaction.atomic().
    Lock the order first, then the payment.
    """
    try:
        order_id = Payment.objects.values_list(
            'order_id',
            flat=True
        ).get(pk=payment_id)

    except Payment.DoesNotExist as exc:
        raise GatewayError(
            'Payment does not exist.'
        ) from exc

    order = Order.objects.select_for_update().get(
        pk=order_id
    )

    payment = Payment.objects.select_for_update().get(
        pk=payment_id
    )

    return order, payment


# =========================================================
# CUSTOMER REQUESTS FULL REFUND
# =========================================================

def request_full_refund(payment_id, reason, user=None):
    """
    Create a refund request.

    This function DOES NOT contact SSLCommerz.

    Pass the authenticated customer as user when called
    from a customer-facing API.
    """
    reason = (reason or '').strip()

    if not reason or len(reason) > 255:
        raise GatewayError(
            'Provide a refund reason of 1 to 255 characters.'
        )

    with transaction.atomic():
        order, payment = _locked_payment_and_order(payment_id)

        if user is not None and order.user_id != user.pk:
            raise GatewayError(
                'You cannot request a refund for this order.'
            )

        if (
            order.payment_method != 'sslcommerz'
            or order.status not in ('pending', 'confirmed')
            or order.payment_status != 'paid'
            or payment.status != 'paid'
            or payment.amount != order.total_amount
            or not payment.bank_transaction_id
        ):
            raise GatewayError(
                'This payment is not eligible for a refund request.'
            )

        if Payment.objects.filter(
            order=order,
            status='review'
        ).exists():
            raise GatewayError(
                'This order has a payment requiring manual review.'
            )

        refund = (
            PaymentRefund.objects
            .select_for_update()
            .filter(payment=payment)
            .first()
        )

        if refund:
            if refund.status != 'rejected':
                raise GatewayError(
                    'A refund request already exists for this payment.'
                )

            if (
                refund.refund_reference_id
                or refund.processing_started_at
            ):
                raise GatewayError(
                    'This refund requires manual review before resubmission.'
                )

            refund.reason = reason
            refund.status = 'requested'
            refund.reviewed_by = None
            refund.reviewed_at = None
            refund.admin_note = ''
            refund.failure_reason = ''

            refund.save(
                update_fields=[
                    'reason',
                    'status',
                    'reviewed_by',
                    'reviewed_at',
                    'admin_note',
                    'failure_reason',
                    'updated_at',
                ]
            )

        else:
            refund = PaymentRefund.objects.create(
                payment=payment,
                amount=payment.amount,
                reason=reason,
                status='requested',
            )

    return refund


# =========================================================
# ADMIN APPROVES REFUND REQUEST
# =========================================================

def approve_refund_request(refund_id, admin_user, note=''):
    if not admin_user or not admin_user.is_staff:
        raise GatewayError(
            'Staff permission is required.'
        )

    with transaction.atomic():
        try:
            payment_id = PaymentRefund.objects.values_list(
                'payment_id',
                flat=True
            ).get(pk=refund_id)

        except PaymentRefund.DoesNotExist as exc:
            raise GatewayError(
                'Refund request does not exist.'
            ) from exc

        order, payment = _locked_payment_and_order(payment_id)

        refund = PaymentRefund.objects.select_for_update().get(
            pk=refund_id
        )

        if (
            refund.status != 'requested'
            or order.status not in ('pending', 'confirmed')
            or order.payment_status != 'paid'
            or payment.status != 'paid'
            or refund.amount != payment.amount
            or refund.refund_reference_id
        ):
            raise GatewayError(
                'This refund request cannot be approved.'
            )

        refund.status = 'approved'
        refund.reviewed_by = admin_user
        refund.reviewed_at = timezone.now()
        refund.admin_note = (note or '').strip()

        refund.save(
            update_fields=[
                'status',
                'reviewed_by',
                'reviewed_at',
                'admin_note',
                'updated_at',
            ]
        )

    return refund


# =========================================================
# ADMIN REJECTS REFUND REQUEST
# =========================================================

def reject_refund_request(refund_id, admin_user, note):
    if not admin_user or not admin_user.is_staff:
        raise GatewayError(
            'Staff permission is required.'
        )

    if not (note or '').strip():
        raise GatewayError(
            'Provide a reason for rejection.'
        )

    with transaction.atomic():
        try:
            payment_id = PaymentRefund.objects.values_list(
                'payment_id',
                flat=True
            ).get(pk=refund_id)

        except PaymentRefund.DoesNotExist as exc:
            raise GatewayError(
                'Refund request does not exist.'
            ) from exc

        _locked_payment_and_order(payment_id)

        refund = PaymentRefund.objects.select_for_update().get(
            pk=refund_id
        )

        if (
            refund.status not in ('requested', 'approved')
            or refund.processing_started_at
        ):
            raise GatewayError(
                'This refund request cannot be rejected.'
            )

        refund.status = 'rejected'
        refund.reviewed_by = admin_user
        refund.reviewed_at = timezone.now()
        refund.admin_note = note.strip()

        refund.save(
            update_fields=[
                'status',
                'reviewed_by',
                'reviewed_at',
                'admin_note',
                'updated_at',
            ]
        )

    return refund


# =========================================================
# INITIATE SSLCOMMERZ REFUND
# =========================================================

def initiate_gateway_refund(refund):
    """
    Low-level gateway request.

    Do not expose this function directly through
    a customer-facing endpoint.

    Use process_approved_refund() instead.
    """
    payment = refund.payment

    if not payment.bank_transaction_id:
        raise GatewayError(
            'Bank transaction ID is missing.'
        )

    return gateway_request(
        'GET',
        '/validator/api/merchantTransIDvalidationAPI.php',
        {
            **gateway_credentials(),

            'bank_tran_id': payment.bank_transaction_id,
            'refund_trans_id': f'RF{refund.pk}',
            'refund_amount': str(refund.amount),
            'refund_remarks': refund.reason,
            'refe_id': payment.transaction_id,
            'format': 'json',
        }
    )


# =========================================================
# PROCESS APPROVED REFUND
# =========================================================

def process_approved_refund(refund_id, admin_user):
    """
    Initiate an approved refund exactly once.

    A timeout or uncertain response must be manually
    reconciled before any retry.
    """
    if not admin_user or not admin_user.is_staff:
        raise GatewayError(
            'Staff permission is required.'
        )

    with transaction.atomic():
        try:
            payment_id = PaymentRefund.objects.values_list(
                'payment_id',
                flat=True
            ).get(pk=refund_id)

        except PaymentRefund.DoesNotExist as exc:
            raise GatewayError(
                'Refund request does not exist.'
            ) from exc

        order, payment = _locked_payment_and_order(payment_id)

        refund = PaymentRefund.objects.select_for_update().get(
            pk=refund_id
        )

        if (
            refund.status != 'approved'
            or refund.processing_started_at is not None
            or order.payment_status != 'paid'
            or payment.status != 'paid'
            or order.status not in ('pending', 'confirmed')
            or refund.amount != payment.amount
            or refund.refund_reference_id
        ):
            raise GatewayError(
                'This refund is not eligible for gateway processing.'
            )

        refund.status = 'initiating'
        refund.processing_started_at = timezone.now()

        refund.save(
            update_fields=[
                'status',
                'processing_started_at',
                'updated_at',
            ]
        )

    # External request is intentionally outside the
    # database transaction.
    #
    # Do not retry automatically if the gateway times out.
    result = initiate_gateway_refund(refund)

    if (
        result.get('APIConnect') != 'DONE'
        or (
            result.get('bank_tran_id')
            and result['bank_tran_id']
            != payment.bank_transaction_id
        )
        or (
            result.get('trans_id')
            and result['trans_id']
            != payment.transaction_id
        )
    ):
        raise GatewayError(
            'Refund outcome uncertain. Reconcile in merchant dashboard.'
        )

    gateway_status = str(
        result.get('status') or ''
    ).lower()

    reference = str(
        result.get('refund_ref_id') or ''
    )

    with transaction.atomic():
        _locked_payment_and_order(payment_id)

        refund = PaymentRefund.objects.select_for_update().get(
            pk=refund_id
        )

        if refund.status != 'initiating':
            return refund

        if (
            gateway_status in ('success', 'processing')
            and reference
        ):
            refund.refund_reference_id = reference
            refund.status = 'processing'

            refund.save(
                update_fields=[
                    'refund_reference_id',
                    'status',
                    'updated_at',
                ]
            )

        elif gateway_status == 'failed':
            refund.status = 'failed'
            refund.failure_reason = str(
                result.get('errorReason')
                or 'Gateway rejected refund.'
            )

            refund.save(
                update_fields=[
                    'status',
                    'failure_reason',
                    'updated_at',
                ]
            )

        else:
            raise GatewayError(
                'Refund outcome uncertain. Reconcile in merchant dashboard.'
            )

    return refund


# =========================================================
# CHECK GATEWAY REFUND
# =========================================================

def check_gateway_refund(refund):
    """
    Verify the refund status with SSLCommerz.

    This updates payment/refund records but does not
    cancel the order or restore stock.
    """
    if refund.status == 'refunded':
        return refund

    if (
        refund.status != 'processing'
        or not refund.refund_reference_id
    ):
        raise GatewayError(
            'No processing refund reference is available.'
        )

    result = gateway_request(
        'GET',
        '/validator/api/merchantTransIDvalidationAPI.php',
        {
            **gateway_credentials(),
            'refund_ref_id': refund.refund_reference_id,
            'format': 'json',
        }
    )

    if (
        result.get('APIConnect') != 'DONE'
        or result.get('refund_ref_id')
        != refund.refund_reference_id
        or result.get('bank_tran_id')
        != refund.payment.bank_transaction_id
        or result.get('tran_id')
        != refund.payment.transaction_id
    ):
        raise GatewayError(
            'Could not securely verify refund status.'
        )

    gateway_status = str(
        result.get('status') or ''
    ).lower()

    with transaction.atomic():
        order, payment = _locked_payment_and_order(
            refund.payment_id
        )

        refund = PaymentRefund.objects.select_for_update().get(
            pk=refund.pk
        )

        if refund.status == 'refunded':
            return refund

        if refund.status != 'processing':
            raise GatewayError(
                'Refund state changed during verification.'
            )

        if gateway_status == 'refunded':
            if (
                payment.status != 'paid'
                or order.payment_status != 'paid'
            ):
                raise GatewayError(
                    'Payment state conflicts with verified refund.'
                )

            refund.status = 'refunded'
            refund.completed_at = timezone.now()

            payment.status = 'refunded'
            order.payment_status = 'refunded'

            refund.save(
                update_fields=[
                    'status',
                    'completed_at',
                    'updated_at',
                ]
            )

            payment.save(
                update_fields=[
                    'status',
                    'updated_at',
                ]
            )

            order.save(
                update_fields=[
                    'payment_status',
                    'updated_at',
                ]
            )

        elif gateway_status == 'processing':
            pass

        elif gateway_status in ('cancelled', 'failed'):
            refund.status = 'failed'
            refund.failure_reason = (
                f'Gateway refund status: {gateway_status}'
            )

            refund.save(
                update_fields=[
                    'status',
                    'failure_reason',
                    'updated_at',
                ]
            )

        else:
            raise GatewayError(
                'Unknown gateway refund status. Manual review required.'
            )

    return refund


# =========================================================
# FRONTEND RESULT URL
# =========================================================

def frontend_result_url(transaction_id, result):
    query = urlencode({
        'transaction_id': transaction_id,
        'result': result,
    })

    return (
        f'{settings.SSLCOMMERZ_FRONTEND_URL.rstrip("/")}'
        f'/payment-result/?{query}'
    )