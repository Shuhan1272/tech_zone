
from django.conf import settings
from django.db import models
from django.core.validators import MinValueValidator


# =========================================================
# ORDER
# =========================================================

class Order(models.Model):

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('confirmed', 'Confirmed'),
        ('shipped', 'Shipped'),
        ('delivered', 'Delivered'),
        ('cancelled', 'Cancelled'),
    ]

    PAYMENT_STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('paid', 'Paid'),
        ('failed', 'Failed'),
        ('refunded', 'Refunded'),
    ]

    PAYMENT_METHOD_CHOICES = [
        ('sslcommerz', 'SSLCommerz'),
        ('cod', 'Cash on Delivery'),
    ]

    DIVISION_CHOICES = [
        ('dhaka', 'Dhaka'),
        ('chattogram', 'Chattogram'),
        ('rajshahi', 'Rajshahi'),
        ('khulna', 'Khulna'),
        ('barishal', 'Barishal'),
        ('sylhet', 'Sylhet'),
        ('rangpur', 'Rangpur'),
        ('mymensingh', 'Mymensingh'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='orders'
    )

    # =====================================================
    # CUSTOMER INFORMATION
    # =====================================================

    shipping_name = models.CharField(
        max_length=150
    )

    shipping_phone = models.CharField(
        max_length=20
    )

    shipping_address = models.TextField()

    # =====================================================
    # STRUCTURED SHIPPING ADDRESS
    # =====================================================

    shipping_house = models.CharField(
        max_length=200,
        blank=True,
        default=''
    )

    shipping_road = models.CharField(
        max_length=200,
        blank=True,
        default=''
    )

    shipping_division = models.CharField(
        max_length=30,
        choices=DIVISION_CHOICES,
        blank=True,
        default=''
    )

    shipping_district = models.CharField(
        max_length=100,
        blank=True,
        default=''
    )

    shipping_upazila = models.CharField(
        max_length=100,
        blank=True,
        default=''
    )

    shipping_postal_code = models.CharField(
        max_length=4,
        blank=True,
        default=''
    )

    shipping_instructions = models.TextField(
        blank=True,
        default=''
    )

    # =====================================================
    # PAYMENT
    # =====================================================

    payment_method = models.CharField(
        max_length=20,
        choices=PAYMENT_METHOD_CHOICES,
        default='sslcommerz'
    )

    payment_status = models.CharField(
        max_length=20,
        choices=PAYMENT_STATUS_CHOICES,
        default='pending'
    )

    # =====================================================
    # PRICING
    # =====================================================

    subtotal = models.DecimalField(
        max_digits=12,
        decimal_places=2
    )

    discount = models.ForeignKey(
        'discounts.Discount',
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name='orders'
    )

    discount_code = models.CharField(
        max_length=50,
        blank=True
    )

    discount_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0
    )

    total_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2
    )

    # =====================================================
    # ORDER STATUS
    # =====================================================

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending'
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    def __str__(self):
        return f'Order #{self.id} - {self.user}'


# =========================================================
# ORDER ITEM
# =========================================================

class OrderItem(models.Model):

    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name='items'
    )

    variant = models.ForeignKey(
        'products.ProductVariant',
        on_delete=models.PROTECT,
        related_name='order_items'
    )

    # =====================================================
    # PRODUCT SNAPSHOT
    # =====================================================

    product_name = models.CharField(
        max_length=255
    )

    sku = models.CharField(
        max_length=100
    )

    # =====================================================
    # RAM, STORAGE AND COLOR SNAPSHOT
    # =====================================================

    ram = models.CharField(
        max_length=50,
        blank=True,
        default=''
    )

    storage = models.CharField(
        max_length=50,
        blank=True,
        default=''
    )

    color_name = models.CharField(
        max_length=50,
        blank=True,
        default=''
    )

    # =====================================================
    # PRICE AND QUANTITY
    # =====================================================

    unit_price = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[
            MinValueValidator(0)
        ]
    )

    quantity = models.PositiveIntegerField(
        validators=[
            MinValueValidator(1)
        ]
    )

    line_total = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[
            MinValueValidator(0)
        ]
    )

    def __str__(self):

        details = []

        if self.ram:
            details.append(self.ram)

        if self.storage:
            details.append(self.storage)

        if self.color_name:
            details.append(self.color_name)

        configuration = (
            f" ({', '.join(details)})"
            if details
            else ""
        )

        return (
            f"{self.product_name}"
            f"{configuration} x {self.quantity}"
        )
