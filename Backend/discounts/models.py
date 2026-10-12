from django.db import models


class Discount(models.Model):

    DISCOUNT_TYPE_CHOICES = [
        ('promo', 'Promo Code'),
        ('staff', 'Staff Discount'),
        ('new_customer', 'New Customer Discount'),
    ]

    VALUE_TYPE_CHOICES = [
        ('percentage', 'Percentage'),
        ('fixed', 'Fixed Amount'),
    ]

    name = models.CharField(
        max_length=100
    )

    discount_type = models.CharField(
        max_length=20,
        choices=DISCOUNT_TYPE_CHOICES
    )

    code = models.CharField(
        max_length=50,
        unique=True,
        blank=True,
        null=True
    )

    value_type = models.CharField(
        max_length=20,
        choices=VALUE_TYPE_CHOICES
    )

    value = models.DecimalField(
        max_digits=10,
        decimal_places=2
    )

    max_discount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        blank=True,
        null=True
    )

    minimum_order_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0
    )

    usage_limit = models.PositiveIntegerField(
        blank=True,
        null=True
    )

    used_count = models.PositiveIntegerField(
        default=0
    )

    start_date = models.DateTimeField(
        blank=True,
        null=True
    )

    end_date = models.DateTimeField(
        blank=True,
        null=True
    )

    is_active = models.BooleanField(
        default=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    def __str__(self):
        return self.name