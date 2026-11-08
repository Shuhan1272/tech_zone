
from django.db import transaction, IntegrityError

from rest_framework import generics, status
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Cart, CartItem
from .serializers import CartSerializer, CartItemSerializer
from products.models import ProductVariant


# =========================================================
# HELPER FUNCTIONS
# =========================================================

def validate_quantity(value):

    if isinstance(value, bool):
        raise ValidationError({
            'quantity': 'Quantity must be a positive integer.'
        })

    try:
        quantity = int(value)
    except (TypeError, ValueError, OverflowError):
        raise ValidationError({
            'quantity': 'Quantity must be a valid integer.'
        })

    if str(value).strip() != str(quantity):
        raise ValidationError({
            'quantity': 'Quantity must be a whole number.'
        })

    if quantity < 1:
        raise ValidationError({
            'quantity': 'Quantity must be at least 1.'
        })

    return quantity


def validate_variant_id(value):

    if isinstance(value, bool):
        raise ValidationError({
            'variant': 'A valid variant ID is required.'
        })

    try:
        variant_id = int(value)
    except (TypeError, ValueError, OverflowError):
        raise ValidationError({
            'variant': 'A valid variant ID is required.'
        })

    if str(value).strip() != str(variant_id) or variant_id < 1:
        raise ValidationError({
            'variant': 'A valid variant ID is required.'
        })

    return variant_id


def get_available_variant(variant_id):

    try:
        variant = (
            ProductVariant.objects
            .select_related('product', 'color')
            .get(
                pk=variant_id,
                is_active=True,
                product__is_active=True
            )
        )

    except ProductVariant.DoesNotExist:
        return None

    return variant


# =========================================================
# CART VIEW
# =========================================================

class CartView(generics.RetrieveAPIView):

    serializer_class = CartSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):

        cart, created = Cart.objects.get_or_create(
            user=self.request.user
        )

        return (
            Cart.objects
            .prefetch_related(
                'items__variant__product__images',
                'items__variant__color'
            )
            .get(pk=cart.pk)
        )


# =========================================================
# ADD ITEM TO CART
# =========================================================

class CartItemCreateView(generics.CreateAPIView):

    serializer_class = CartItemSerializer
    permission_classes = [IsAuthenticated]

    def create(self, request, *args, **kwargs):

        variant_id = validate_variant_id(
            request.data.get('variant')
        )

        quantity = validate_quantity(
            request.data.get('quantity', 1)
        )

        with transaction.atomic():

            variant = get_available_variant(variant_id)

            if variant is None:
                return Response(
                    {
                        'detail': 'Product variant not found or unavailable.'
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            if variant.stock < quantity:
                return Response(
                    {
                        'detail': 'Not enough stock available.',
                        'available_stock': variant.stock
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            cart, created = Cart.objects.get_or_create(
                user=request.user
            )

            # Lock the cart row on databases supporting
            # SELECT FOR UPDATE. SQLite serializes writes
            # differently and does not provide row locks.
            cart = (
                Cart.objects
                .select_for_update()
                .get(pk=cart.pk)
            )

            cart_item, item_created = (
                CartItem.objects.get_or_create(
                    cart=cart,
                    variant=variant,
                    defaults={
                        'quantity': quantity
                    }
                )
            )

            if not item_created:

                new_quantity = (
                    cart_item.quantity + quantity
                )

                if new_quantity > variant.stock:
                    return Response(
                        {
                            'detail': 'Not enough stock available.',
                            'available_stock': variant.stock,
                            'cart_quantity': cart_item.quantity
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )

                cart_item.quantity = new_quantity
                cart_item.save(
                    update_fields=[
                        'quantity',
                        'updated_at'
                    ]
                )

            serializer = self.get_serializer(
                cart_item,
                context={
                    'request': request
                }
            )

            return Response(
                serializer.data,
                status=(
                    status.HTTP_201_CREATED
                    if item_created
                    else status.HTTP_200_OK
                )
            )


# =========================================================
# CART ITEM DETAILS / UPDATE / DELETE
# =========================================================

class CartItemDetailView(
    generics.RetrieveUpdateDestroyAPIView
):

    serializer_class = CartItemSerializer
    permission_classes = [IsAuthenticated]

    http_method_names = [
        'get',
        'put',
        'patch',
        'delete',
        'head',
        'options'
    ]

    def get_queryset(self):

        return (
            CartItem.objects
            .filter(
                cart__user=self.request.user
            )
            .select_related(
                'variant',
                'variant__product',
                'variant__color'
            )
        )

    def update(self, request, *args, **kwargs):

        if 'variant' in request.data:
            raise ValidationError({
                'variant': (
                    'You cannot change the variant of an '
                    'existing cart item. Remove it and add '
                    'the desired variant instead.'
                )
            })

        quantity = validate_quantity(
            request.data.get('quantity')
        )

        with transaction.atomic():

            # Lock the cart row to coordinate cart updates
            # on databases supporting row-level locking.
            Cart.objects.select_for_update().get(
                user=request.user
            )

            cart_item = self.get_object()

            variant = get_available_variant(
                cart_item.variant_id
            )

            if variant is None:
                raise ValidationError({
                    'variant': (
                        'This product variant is no longer available.'
                    )
                })

            if quantity > variant.stock:
                raise ValidationError({
                    'quantity': 'Not enough stock available.',
                    'available_stock': variant.stock
                })

            cart_item.quantity = quantity
            cart_item.save(
                update_fields=[
                    'quantity',
                    'updated_at'
                ]
            )

            serializer = self.get_serializer(
                cart_item
            )

            return Response(
                serializer.data,
                status=status.HTTP_200_OK
            )
