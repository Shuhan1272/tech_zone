from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Cart, CartItem
from .serializers import CartSerializer, CartItemSerializer
from products.models import ProductVariant


class CartView(generics.RetrieveAPIView):
    serializer_class = CartSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        cart, created = Cart.objects.get_or_create(
            user=self.request.user
        )
        return cart


class CartItemCreateView(generics.CreateAPIView):
    serializer_class = CartItemSerializer
    permission_classes = [IsAuthenticated]

    def create(self, request, *args, **kwargs):
        variant_id = request.data.get('variant')
        quantity = request.data.get('quantity', 1)

        # Check variant
        try:
            variant = ProductVariant.objects.get(
                id=variant_id,
                is_active=True
            )
        except ProductVariant.DoesNotExist:
            return Response(
                {'detail': 'Product variant not found.'},
                status=status.HTTP_404_NOT_FOUND
            )

        # Check stock
        if variant.stock < int(quantity):
            return Response(
                {'detail': 'Not enough stock available.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Get or create user's cart
        cart, created = Cart.objects.get_or_create(
            user=request.user
        )

        # Check if variant already exists
        cart_item, item_created = CartItem.objects.get_or_create(
            cart=cart,
            variant=variant,
            defaults={'quantity': quantity}
        )

        if not item_created:
            new_quantity = cart_item.quantity + int(quantity)

            if new_quantity > variant.stock:
                return Response(
                    {'detail': 'Not enough stock available.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            cart_item.quantity = new_quantity
            cart_item.save()

        serializer = self.get_serializer(cart_item)

        return Response(
            serializer.data,
            status=status.HTTP_201_CREATED
        )


class CartItemDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CartItemSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return CartItem.objects.filter(
            cart__user=self.request.user
        )

    def perform_update(self, serializer):
        quantity = self.request.data.get('quantity')

        if quantity is None:
            from rest_framework.exceptions import ValidationError
            raise ValidationError({
                'quantity': 'Quantity is required.'
            })

        quantity = int(quantity)

        if quantity < 1:
            from rest_framework.exceptions import ValidationError
            raise ValidationError({
                'quantity': 'Quantity must be at least 1.'
            })

        if quantity > serializer.instance.variant.stock:
            from rest_framework.exceptions import ValidationError
            raise ValidationError({
                'quantity': 'Not enough stock available.'
            })

        serializer.save(quantity=quantity)