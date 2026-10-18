"""Order placement.

All of the money and all of the stock arithmetic lives here, deliberately
away from the view: the view may not compute a total, and nothing a client
sends is ever used as a price.

The whole placement runs in one transaction. If any part of it fails -- a
variant sold out between the stock check and the deduction, say -- the order,
its items, the stock changes and the cart emptying all disappear together.
"""

from decimal import Decimal, ROUND_HALF_UP

from django.db import transaction
from django.db.models import F
from rest_framework.exceptions import ValidationError

from accounts.models import Address, User
from cart.models import Cart
from products.models import ProductVariant

from .models import Order, OrderItem


CENTS = Decimal('0.01')

ZERO = Decimal('0.00')

# Fields an address must actually contain before anything can be delivered
# to it. ``address2`` and ``company`` are genuinely optional.
REQUIRED_ADDRESS_FIELDS = (
    ('first_name', 'first name'),
    ('last_name', 'last name'),
    ('address1', 'street address'),
    ('city', 'city'),
    ('postal_code', 'postal code'),
    ('region', 'region'),
)


def money(value):
    """Round to two decimal places the way an invoice would."""
    return Decimal(value).quantize(CENTS, rounding=ROUND_HALF_UP)


class OutOfStock(ValidationError):
    """Raised when the catalogue cannot satisfy the cart."""


def address_snapshot(user):
    """Copy the customer's address onto a plain dict for the order.

    A copy, not a foreign key: ``Address`` is a single mutable row per user,
    so linking to it would silently rewrite the delivery details of every
    past order the next time the customer moves house.
    """
    # Queried rather than read through ``user.address``: the reverse
    # one-to-one descriptor caches, and a cached address could outlive the
    # row it came from.
    address = Address.objects.filter(user=user).first()

    if address is None:
        raise ValidationError({
            'shipping_address': (
                'Add a delivery address to your account before '
                'placing an order.'
            )
        })

    missing = [
        label
        for field, label in REQUIRED_ADDRESS_FIELDS
        if not (getattr(address, field, '') or '').strip()
    ]

    if missing:
        raise ValidationError({
            'shipping_address': (
                'Your delivery address is incomplete. '
                f"Please add your {', '.join(missing)}."
            )
        })

    return {
        'ship_first_name': address.first_name,
        'ship_last_name': address.last_name,
        'ship_company': address.company or '',
        'ship_phone': user.phone or '',
        'ship_address1': address.address1,
        'ship_address2': address.address2 or '',
        'ship_city': address.city,
        'ship_postal_code': address.postal_code,
        'ship_region': address.region,
        'ship_country': address.country or 'Bangladesh',
    }


@transaction.atomic
def place_order(
    user,
    payment_method=Order.PaymentMethod.COD,
    customer_note='',
    idempotency_key='',
):
    """Turn the customer's cart into an order.

    Returns ``(order, created)``. ``created`` is False when the idempotency
    key matched an order this customer had already placed, which is how a
    double submission ends up returning the first order instead of a second
    one.

    Raises ``rest_framework.exceptions.ValidationError`` with a
    customer-readable message for every expected failure: empty cart,
    missing address, inactive product, not enough stock.
    """

    # Serialise this customer's checkout. Two taps on "Place order" now run
    # one after the other instead of side by side, so the second one finds
    # the cart already empty. (On SQLite this is a no-op, which is why the
    # idempotency key and the conditional stock UPDATE below both exist.)
    User.objects.select_for_update().filter(pk=user.pk).first()

    if idempotency_key:
        already = Order.objects.filter(
            user=user,
            idempotency_key=idempotency_key
        ).first()

        if already is not None:
            return already, False

    cart = Cart.objects.filter(user=user).first()

    cart_items = (
        list(cart.items.select_related('variant__product'))
        if cart is not None
        else []
    )

    if not cart_items:
        raise ValidationError({'cart': 'Your cart is empty.'})

    snapshot = address_snapshot(user)

    # Lock the variants in a stable order so two concurrent checkouts that
    # share products cannot deadlock against each other.
    variant_ids = sorted(item.variant_id for item in cart_items)

    locked = {
        variant.pk: variant
        for variant in ProductVariant.objects
        .select_for_update()
        .select_related('product')
        .filter(pk__in=variant_ids)
    }

    unavailable = []
    short = []
    lines = []

    items_subtotal = ZERO
    items_payable = ZERO

    for cart_item in cart_items:
        variant = locked.get(cart_item.variant_id)

        if variant is None or not variant.is_active or not variant.product.is_active:
            name = cart_item.variant.product.name
            unavailable.append(name)
            continue

        quantity = cart_item.quantity

        if variant.stock < quantity:
            short.append(
                f"{variant.product.name} "
                f"({variant.stock} left, {quantity} requested)"
                if variant.stock
                else f"{variant.product.name} (out of stock)"
            )
            continue

        unit_price = money(variant.price)
        unit_paid = money(variant.discounted_price)
        line_total = money(unit_paid * quantity)

        items_subtotal += money(unit_price * quantity)
        items_payable += line_total

        lines.append(
            OrderItem(
                variant=variant,
                product_name=variant.product.name,
                variant_sku=variant.sku or '',
                options=variant.options or {},
                unit_price=unit_price,
                unit_discount_percentage=variant.discount_percentage,
                unit_price_paid=unit_paid,
                quantity=quantity,
                line_total=line_total,
            )
        )

    if unavailable:
        raise ValidationError({
            'items': (
                'These items are no longer available: '
                f"{', '.join(unavailable)}. "
                'Please remove them from your cart.'
            )
        })

    if short:
        raise OutOfStock({
            'items': (
                'Not enough stock for: '
                f"{'; '.join(short)}. "
                'Please reduce the quantity and try again.'
            )
        })

    # No coupon API exists yet, and no delivery charge is calculated
    # anywhere, so both of these are real zeroes rather than guesses.
    coupon_discount = ZERO
    shipping_fee = ZERO

    product_discount_total = money(items_subtotal - items_payable)
    grand_total = money(items_payable - coupon_discount + shipping_fee)

    order = Order(
        user=user,
        payment_method=payment_method,
        payment_status=Order.PaymentStatus.UNPAID,
        status=Order.Status.PENDING,
        items_subtotal=items_subtotal,
        product_discount_total=product_discount_total,
        coupon_discount=coupon_discount,
        shipping_fee=shipping_fee,
        grand_total=grand_total,
        customer_note=(customer_note or '').strip(),
        idempotency_key=idempotency_key or '',
        **snapshot,
    )

    order.save()

    for line in lines:
        line.order = order

    OrderItem.objects.bulk_create(lines)

    # Deduct stock with a conditional UPDATE. ``stock__gte`` makes the check
    # and the write a single atomic statement, so even without row locks two
    # customers cannot both take the last unit. Zero rows updated means
    # somebody got there first: raise, and the transaction unwinds the order,
    # its items and every deduction made so far.
    for line in lines:
        deducted = (
            ProductVariant.objects
            .filter(pk=line.variant_id, stock__gte=line.quantity)
            .update(stock=F('stock') - line.quantity)
        )

        if not deducted:
            raise OutOfStock({
                'items': (
                    f"{line.product_name} sold out while you were checking "
                    'out. Your order was not placed and nothing was charged.'
                )
            })

    # Only now, with the order safely written, is the cart emptied.
    cart.items.all().delete()

    return order, True
