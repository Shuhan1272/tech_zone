
from rest_framework import serializers

from .models import Payment, PaymentRefund


# =========================================================
# PAYMENT REFUND SERIALIZER
# =========================================================

class PaymentRefundSerializer(serializers.ModelSerializer):

    status_display = serializers.CharField(
        source='get_status_display',
        read_only=True
    )

    order_id = serializers.IntegerField(
        source='payment.order_id',
        read_only=True
    )

    currency = serializers.CharField(
        source='payment.currency',
        read_only=True
    )

    class Meta:
        model = PaymentRefund

        fields = [
            'id',
            'payment',
            'order_id',
            'amount',
            'currency',
            'reason',
            'refund_reference_id',
            'status',
            'status_display',

            # Admin review
            'reviewed_by',
            'reviewed_at',
            'admin_note',

            # Gateway processing
            'processing_started_at',
            'completed_at',
            'failure_reason',

            # Timestamps
            'created_at',
            'updated_at',
        ]

        read_only_fields = fields


# =========================================================
# PAYMENT SERIALIZER
# =========================================================

class PaymentSerializer(serializers.ModelSerializer):

    refund = PaymentRefundSerializer(
        read_only=True
    )

    status_display = serializers.CharField(
        source='get_status_display',
        read_only=True
    )

    order_id = serializers.IntegerField(
        read_only=True
    )

    class Meta:
        model = Payment

        fields = [
            'id',
            'order',
            'order_id',
            'transaction_id',
            'amount',
            'currency',
            'status',
            'status_display',
            'bank_transaction_id',
            'payment_method',
            'risk_level',
            'review_reason',
            'refund',
            'created_at',
            'updated_at',
        ]

        read_only_fields = fields


# =========================================================
# PAYMENT INITIATE SERIALIZER
# =========================================================

class PaymentInitiateSerializer(serializers.Serializer):

    order_id = serializers.IntegerField(
        min_value=1
    )


# =========================================================
# CUSTOMER REFUND REQUEST SERIALIZER
# =========================================================

class RefundRequestSerializer(serializers.Serializer):

    order_id = serializers.IntegerField(
        min_value=1
    )

    reason = serializers.CharField(
        min_length=1,
        max_length=255,
        trim_whitespace=True
    )


# =========================================================
# ADMIN REFUND REVIEW SERIALIZER
# =========================================================

class RefundReviewSerializer(serializers.Serializer):

    note = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=2000,
        trim_whitespace=True
    )


# =========================================================
# ADMIN REFUND REJECTION SERIALIZER
# =========================================================

class RefundRejectSerializer(serializers.Serializer):

    note = serializers.CharField(
        required=True,
        allow_blank=False,
        max_length=2000,
        trim_whitespace=True
    )
