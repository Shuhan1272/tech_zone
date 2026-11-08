from decimal import Decimal

from rest_framework import status,generics 
from rest_framework.views import APIView
from rest_framework.viewsets import ModelViewSet
from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response

from .models import Discount
from .serializers import (
    DiscountSerializer,
    DiscountValidationSerializer,
)


class DiscountViewSet(ModelViewSet):
    queryset = Discount.objects.all()
    serializer_class = DiscountSerializer
    permission_classes = [IsAdminUser]


from .serializers import DiscountValidationSerializer


class DiscountValidationView(generics.GenericAPIView):

    serializer_class = DiscountValidationSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request):

        serializer = self.get_serializer(
            data=request.data
        )

        serializer.is_valid(raise_exception=True)

        discount = serializer.validated_data['discount']
        order_amount = serializer.validated_data['order_amount']

        # Calculate discount
        if discount.value_type == 'percentage':

            discount_amount = (
                order_amount * discount.value / Decimal('100')
            )

            if discount.max_discount is not None:
                discount_amount = min(
                    discount_amount,
                    discount.max_discount
                )

        else:
            discount_amount = discount.value

        discount_amount = min(
            discount_amount,
            order_amount
        )

        discount_amount = discount_amount.quantize(
            Decimal('0.01')
        )

        final_amount = order_amount - discount_amount

        return Response({
            'valid': True,
            'message': 'Discount applied successfully.',
            'discount_type': discount.discount_type,
            'discount_amount': str(discount_amount),
            'final_amount': str(final_amount),
        }, status=status.HTTP_200_OK)

