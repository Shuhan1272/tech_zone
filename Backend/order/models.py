"""Order models.

An order is a financial record. Once it is placed, nothing about it may
change because the catalogue changed, so every price, product name and
address field is *copied* onto the order at placement time instead of being
read back through a relation.
"""

from decimal import Decimal
import secrets

from django.db import models, transaction
from django.db.models import F, Q
from django.utils import timezone

from accounts.models import User
from products.models import ProductVariant, TimeStampedModel


ZERO = Decimal('0.00')


def generate_order_number():
    """Human-quotable, non-sequential order number: ``TZ-261018-A4F9C2``.

    Non-sequential on purpose: a guessable number would invite customers to
    walk the order space. Uniqueness is enforced by the database.
    """
    stamp = timezone.localtime().strftime('%y%m%d')

    return f"TZ-{stamp}-{secrets.token_hex(3).upper()}"


# =========================================================
# ORDER
# =========================================================

class Order(TimeStampedModel):

    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        CONFIRMED = 'confirmed', 'Confirmed'
        PROCESSING = 'processing', 'Processing'
        SHIPPED = 'shipped', 'Shipped'
        DELIVERED = 'delivered', 'Delivered'
        CANCELLED = 'cancelled', 'Cancelled'

    class PaymentMethod(models.TextChoices):
        # Cash on delivery is the only method today. Online methods are added
        # here (bkash, card, ...) without touching anything else.
        COD = 'cod', 'Cash on Delivery'

    class PaymentStatus(models.TextChoices):
        UNPAID = 'unpaid', 'Unpaid'
        PAID = 'paid', 'Paid'
        REFUNDED = 'refunded', 'Refunded'

    user = models.ForeignKey(
        User,
        on_delete=models.PROTECT,
        related_name='orders'
    )

    order_number = models.CharField(
        max_length=32,
        unique=True,
        editable=False
    )

    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING
    )

    payment_method = models.CharField(
        max_length=20,
        choices=PaymentMethod.choices,
        default=PaymentMethod.COD
    )

    # A cash-on-delivery order is NOT paid when it is placed. It stays unpaid
    # until someone records the cash, which is a back-office action.
    payment_status = models.CharField(
        max_length=20,
        choices=PaymentStatus.choices,
        default=PaymentStatus.UNPAID
    )

    # ----- money: every figure below is computed on the server -----

    items_subtotal = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=ZERO
    )

    product_discount_total = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=ZERO
    )

    # Reserved for the discounts app. There is no coupon API yet, so these
    # stay empty / 0.00 and are never taken from the client.
    coupon_code = models.CharField(
        max_length=50,
        blank=True,
        default=''
    )

    coupon_discount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=ZERO
    )

    # No delivery charge is calculated anywhere in the system, so this is a
    # real 0.00 rather than an invented figure.
    shipping_fee = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=ZERO
    )

    grand_total = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=ZERO
    )

    # ----- shipping address snapshot (copied, not linked) -----

    ship_first_name = models.CharField(max_length=100)
    ship_last_name = models.CharField(max_length=100)
    ship_company = models.CharField(max_length=150, blank=True, default='')
    ship_phone = models.CharField(max_length=20, blank=True, default='')
    ship_address1 = models.CharField(max_length=255)
    ship_address2 = models.CharField(max_length=255, blank=True, default='')
    ship_city = models.CharField(max_length=100)
    ship_postal_code = models.CharField(max_length=20)
    ship_region = models.CharField(max_length=100)
    ship_country = models.CharField(max_length=100, default='Bangladesh')

    customer_note = models.TextField(blank=True, default='')

    # ----- bookkeeping -----

    # Set the moment stock is given back, and used as the "exactly once"
    # guard: the restore claims this column with a conditional UPDATE.
    stock_restored_at = models.DateTimeField(
        null=True,
        blank=True,
        editable=False
    )

    # Supplied by the client as the Idempotency-Key header. Two requests
    # carrying the same key can only ever produce one order.
    idempotency_key = models.CharField(
        max_length=64,
        blank=True,
        default='',
        editable=False
    )

    placed_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ['-placed_at', '-id']

        constraints = [
            models.UniqueConstraint(
                fields=['user', 'idempotency_key'],
                condition=~Q(idempotency_key=''),
                name='unique_user_idempotency_key'
            )
        ]

        indexes = [
            models.Index(fields=['user', '-placed_at']),
        ]

    def __str__(self):
        return f"{self.order_number} - {self.user.email}"

    # ----- derived -----

    @property
    def total_quantity(self):
        return sum(item.quantity for item in self.items.all())

    @property
    def ship_recipient(self):
        return f"{self.ship_first_name} {self.ship_last_name}".strip()

    @property
    def is_cancelled(self):
        return self.status == self.Status.CANCELLED

    # ----- persistence -----

    def save(self, *args, **kwargs):
        if not self.order_number:
            self.order_number = self._unique_order_number()

        # Read the stored status before writing, so a transition *into*
        # cancelled can be detected. None means the row is new.
        previous_status = None

        if self.pk:
            previous_status = (
                Order.objects
                .filter(pk=self.pk)
                .values_list('status', flat=True)
                .first()
            )

        super().save(*args, **kwargs)

        became_cancelled = (
            self.status == self.Status.CANCELLED
            and previous_status is not None
            and previous_status != self.Status.CANCELLED
        )

        if became_cancelled:
            self.restore_stock()

    @staticmethod
    def _unique_order_number(attempts=10):
        for _ in range(attempts):
            candidate = generate_order_number()

            if not Order.objects.filter(order_number=candidate).exists():
                return candidate

        # Astronomically unlikely; the unique constraint is the real backstop.
        raise RuntimeError('Could not allocate an order number.')

    def restore_stock(self):
        """Give the ordered quantities back to the catalogue.

        Safe to call any number of times: the first call claims
        ``stock_restored_at`` with a conditional UPDATE, and every later call
        sees the column already set and does nothing. Two concurrent calls
        cannot both win the claim, because the claim is a single atomic
        statement in the database.

        Returns True only for the call that actually restored stock.
        """
        with transaction.atomic():
            claimed = (
                Order.objects
                .filter(pk=self.pk, stock_restored_at__isnull=True)
                .update(stock_restored_at=timezone.now())
            )

            if not claimed:
                return False

            for item in self.items.all():
                if item.variant_id is None:
                    continue

                ProductVariant.objects.filter(
                    pk=item.variant_id
                ).update(
                    stock=F('stock') + item.quantity
                )

        self.refresh_from_db(fields=['stock_restored_at'])

        return True


# =========================================================
# ORDER ITEM
# =========================================================

class OrderItem(models.Model):

    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name='items'
    )

    # PROTECT: a variant that has been sold cannot be deleted out from under
    # its orders. The snapshot fields below mean the order still reads
    # correctly even if the product is later renamed or repriced.
    variant = models.ForeignKey(
        ProductVariant,
        on_delete=models.PROTECT,
        related_name='order_items'
    )

    product_name = models.CharField(max_length=200)
    variant_sku = models.CharField(max_length=100, blank=True, default='')
    options = models.JSONField(default=dict, blank=True)

    # List price at the time of the order.
    unit_price = models.DecimalField(max_digits=12, decimal_places=2)

    unit_discount_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=ZERO
    )

    # What the customer actually pays per unit.
    unit_price_paid = models.DecimalField(max_digits=12, decimal_places=2)

    quantity = models.PositiveIntegerField(default=1)

    line_total = models.DecimalField(max_digits=12, decimal_places=2)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['id']

    def __str__(self):
        return f"{self.product_name} x {self.quantity}"
