
from decimal import Decimal, ROUND_HALF_UP

from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import F, Q

from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError

from cart.models import Cart
from products.models import ProductVariant
from discounts.models import Discount

from discounts.services import (
    validate_checkout_discount,
    calculate_discount,
)

from .models import Order, OrderItem

from .serializers import (
    CheckoutSerializer,
    OrderSerializer,
)

from .services import cancel_order


# =========================================================
# CHECKOUT
# =========================================================

class CheckoutView(generics.GenericAPIView):

    serializer_class = CheckoutSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request):

        serializer = self.get_serializer(
            data=request.data
        )

        serializer.is_valid(
            raise_exception=True
        )

        data = serializer.validated_data

        payment_method = data['payment_method']

        with transaction.atomic():

            # =================================================
            # LOCK USER
            # =================================================

            user = (
                get_user_model()
                .objects
                .select_for_update()
                .get(pk=request.user.pk)
            )

            # =================================================
            # GET CART
            # =================================================

            try:
                cart = (
                    Cart.objects
                    .select_for_update()
                    .get(user=user)
                )

            except Cart.DoesNotExist:
                raise ValidationError({
                    'cart': 'Your cart is empty.'
                })

            cart_items = list(
                cart.items
                .select_related(
                    'variant__product',
                    'variant__color'
                )
                .select_for_update()
                .order_by('variant_id')
            )

            if not cart_items:
                raise ValidationError({
                    'cart': 'Your cart is empty.'
                })

            # =================================================
            # VALIDATE CART ITEMS
            # =================================================

            subtotal = Decimal('0.00')
            purchased_items = []

            for item in cart_items:

                variant = item.variant
                product = variant.product

                # Check product availability
                if not product.is_active:
                    raise ValidationError({
                        'cart': (
                            f'{product.name} is unavailable.'
                        )
                    })

                # Check variant availability
                if not variant.is_active:
                    raise ValidationError({
                        'cart': (
                            f'{product.name} variant is unavailable.'
                        )
                    })

                # Validate quantity
                if item.quantity < 1:
                    raise ValidationError({
                        'cart': (
                            f'Invalid quantity for {product.name}.'
                        )
                    })

                # Validate stock
                if variant.stock < item.quantity:
                    raise ValidationError({
                        'cart': (
                            f'Insufficient stock for {product.name}.'
                        )
                    })

                # Calculate actual selling price
                unit_price = Decimal(
                    str(variant.discounted_price)
                ).quantize(
                    Decimal('0.01'),
                    rounding=ROUND_HALF_UP
                )

                if unit_price < 0:
                    raise ValidationError({
                        'cart': 'Invalid product price.'
                    })

                line_total = (
                    unit_price * item.quantity
                )

                subtotal += line_total

                # Store all purchase information before
                # changing stock or creating the order.
                purchased_items.append({
                    'variant_id': variant.pk,
                    'product_name': product.name,
                    'sku': variant.sku,

                    # RAM, storage and color snapshots
                    'ram': variant.ram or '',
                    'storage': variant.storage or '',
                    'color_name': (
                        variant.color.name
                        if variant.color_id
                        else ''
                    ),

                    'quantity': item.quantity,
                    'unit_price': unit_price,
                    'line_total': line_total,
                })

            # =================================================
            # VALIDATE DISCOUNT
            # =================================================

            discount = validate_checkout_discount(
                user=user,
                discount_type=data.get(
                    'discount_type'
                ),
                code=data.get(
                    'discount_code',
                    ''
                ),
                subtotal=subtotal,
            )

            discount_amount = calculate_discount(
                discount,
                subtotal
            )

            total_amount = (
                subtotal - discount_amount
            )

            if total_amount < 0:
                raise ValidationError({
                    'discount': 'Invalid discount amount.'
                })

            # =================================================
            # REDUCE PRODUCT STOCK
            # =================================================

            for purchased in purchased_items:

                updated = (
                    ProductVariant.objects
                    .filter(
                        pk=purchased['variant_id'],
                        is_active=True,
                        product__is_active=True,
                        stock__gte=purchased['quantity']
                    )
                    .update(
                        stock=(
                            F('stock') -
                            purchased['quantity']
                        )
                    )
                )

                if not updated:
                    raise ValidationError({
                        'cart': (
                            'Insufficient stock or product '
                            'is no longer available.'
                        )
                    })

            # =================================================
            # UPDATE DISCOUNT USAGE
            # =================================================

            if discount:

                updated = (
                    Discount.objects
                    .filter(
                        pk=discount.pk,
                        is_active=True
                    )
                    .filter(
                        Q(usage_limit__isnull=True)
                        |
                        Q(
                            used_count__lt=F(
                                'usage_limit'
                            )
                        )
                    )
                    .update(
                        used_count=(
                            F('used_count') + 1
                        )
                    )
                )

                if not updated:
                    raise ValidationError({
                        'discount': (
                            'Discount is no longer available.'
                        )
                    })

            # =================================================
            # CREATE ORDER
            # =================================================

            order = Order.objects.create(

                user=user,

                # Customer information
                shipping_name=data[
                    'shipping_name'
                ],

                shipping_phone=data[
                    'shipping_phone'
                ],

                # Complete shipping address
                shipping_address=data[
                    'shipping_address'
                ],

                # Structured shipping address
                shipping_house=data[
                    'shipping_house'
                ],

                shipping_road=data[
                    'shipping_road'
                ],

                shipping_division=data[
                    'shipping_division'
                ],

                shipping_district=data[
                    'shipping_district'
                ],

                shipping_upazila=data[
                    'shipping_upazila'
                ],

                shipping_postal_code=data[
                    'shipping_postal_code'
                ],

                shipping_instructions=data.get(
                    'shipping_instructions',
                    ''
                ),

                # Pricing
                subtotal=subtotal,

                discount=discount,

                discount_code=(
                    discount.code or ''
                    if discount
                    else ''
                ),

                discount_amount=discount_amount,

                total_amount=total_amount,

                # Payment
                payment_method=payment_method,
                payment_status='pending',

                # Order status
                status='pending',
            )

            # =================================================
            # CREATE ORDER ITEMS WITH SNAPSHOTS
            # =================================================

            order_items = []

            for purchased in purchased_items:

                order_items.append(
                    OrderItem(
                        order=order,

                        variant_id=purchased[
                            'variant_id'
                        ],

                        product_name=purchased[
                            'product_name'
                        ],

                        sku=purchased['sku'],

                        # Purchased configuration
                        ram=purchased['ram'],

                        storage=purchased['storage'],

                        color_name=purchased[
                            'color_name'
                        ],

                        # Purchased price and quantity
                        unit_price=purchased[
                            'unit_price'
                        ],

                        quantity=purchased[
                            'quantity'
                        ],

                        line_total=purchased[
                            'line_total'
                        ],
                    )
                )

            OrderItem.objects.bulk_create(
                order_items
            )

            # =================================================
            # CLEAR PURCHASED CART ITEMS
            # =================================================

            cart.items.filter(
                id__in=[
                    item.id
                    for item in cart_items
                ]
            ).delete()

        # =====================================================
        # RETURN CREATED ORDER
        # =====================================================

        return Response(
            OrderSerializer(
                order,
                context={
                    'request': request
                }
            ).data,
            status=status.HTTP_201_CREATED
        )


# =========================================================
# MY ORDERS
# =========================================================

class MyOrderListView(generics.ListAPIView):

    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):

        return (
            Order.objects
            .filter(
                user=self.request.user
            )
            .prefetch_related(
                'items__variant__product__images'
            )
            .order_by('-created_at')
        )


# =========================================================
# ORDER DETAILS
# =========================================================

class OrderDetailView(generics.RetrieveAPIView):

    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):

        return (
            Order.objects
            .filter(
                user=self.request.user
            )
            .prefetch_related(
                'items__variant__product__images'
            )
        )


# =========================================================
# CANCEL ORDER
# =========================================================

class OrderCancelView(generics.GenericAPIView):

    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):

        return Order.objects.filter(
            user=self.request.user
        )

    def post(self, request, pk):

        order = self.get_object()

        order = cancel_order(
            order.pk
        )

        return Response(
            OrderSerializer(
                order,
                context={
                    'request': request
                }
            ).data,
            status=status.HTTP_200_OK
        )
