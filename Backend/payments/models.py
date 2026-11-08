
from django.conf import settings
from django.db import models


# =========================================================
# PAYMENT
# =========================================================

class Payment(models.Model):

    STATUS_CHOICES = [
        ('initiating', 'Initiating'),
        ('pending', 'Pending'),
        ('paid', 'Paid'),
        ('review', 'Requires Review'),
        ('failed', 'Failed'),
        ('cancelled', 'Cancelled'),
        ('refunded', 'Refunded'),
    ]

    order = models.ForeignKey(
        'order.Order',
        on_delete=models.PROTECT,
        related_name='payments'
    )

    transaction_id = models.CharField(
        max_length=30,
        unique=True
    )

    amount = models.DecimalField(
        max_digits=12,
        decimal_places=2
    )

    currency = models.CharField(
        max_length=3,
        default='BDT'
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='initiating'
    )

    gateway_session_key = models.CharField(
        max_length=100,
        blank=True
    )

    gateway_url = models.URLField(
        max_length=1500,
        blank=True
    )

    validation_id = models.CharField(
        max_length=100,
        blank=True
    )

    bank_transaction_id = models.CharField(
        max_length=100,
        blank=True
    )

    payment_method = models.CharField(
        max_length=100,
        blank=True
    )

    risk_level = models.PositiveSmallIntegerField(
        default=0
    )

    review_reason = models.CharField(
        max_length=100,
        blank=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.transaction_id} - {self.status}'


# =========================================================
# PAYMENT REFUND
# =========================================================

class PaymentRefund(models.Model):

    STATUS_CHOICES = [
        ('requested', 'Requested'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
        ('initiating', 'Initiating'),
        ('processing', 'Processing'),
        ('refunded', 'Refunded'),
        ('failed', 'Failed'),
    ]

    payment = models.OneToOneField(
        Payment,
        on_delete=models.PROTECT,
        related_name='refund'
    )

    amount = models.DecimalField(
        max_digits=12,
        decimal_places=2
    )

    reason = models.CharField(
        max_length=255
    )

    refund_reference_id = models.CharField(
        max_length=100,
        blank=True
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='requested'
    )

    # -----------------------------------------------------
    # ADMIN REVIEW
    # -----------------------------------------------------

    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='reviewed_payment_refunds'
    )

    reviewed_at = models.DateTimeField(
        null=True,
        blank=True
    )

    admin_note = models.TextField(
        blank=True,
        default=''
    )

    # -----------------------------------------------------
    # GATEWAY PROCESSING
    # -----------------------------------------------------

    processing_started_at = models.DateTimeField(
        null=True,
        blank=True
    )

    completed_at = models.DateTimeField(
        null=True,
        blank=True
    )

    failure_reason = models.TextField(
        blank=True,
        default=''
    )

    # -----------------------------------------------------
    # TIMESTAMPS
    # -----------------------------------------------------

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Refund #{self.pk} - {self.status}'
