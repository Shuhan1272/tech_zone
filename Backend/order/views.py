import logging

from django.db import IntegrityError
from rest_framework import generics, status
from rest_framework.exceptions import ValidationError
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Order
from .serializers import (
    OrderCreateSerializer,
    OrderDetailSerializer,
    OrderListSerializer,
)
from .services import place_order


logger = logging.getLogger(__name__)

# What the customer sees when something unexpected breaks. Technical detail
# goes to the log, never to the browser.
GENERIC_FAILURE = (
    'We could not place your order right now. '
    'Nothing has been charged. Please try again in a moment.'
)


class OrderPagination(PageNumberPagination):
    page_size = 10
    page_size_query_param = 'limit'
    max_page_size = 50


class OrderListCreateView(generics.ListCreateAPIView):
    """``GET`` the signed-in customer's orders, ``POST`` to place a new one."""

    permission_classes = [IsAuthenticated]
    pagination_class = OrderPagination

    def get_queryset(self):
        # Ownership is enforced here, in one place. There is no code path
        # that can return an order belonging to somebody else.
        return (
            Order.objects
            .filter(user=self.request.user)
            .prefetch_related('items')
        )

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return OrderCreateSerializer

        return OrderListSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        # Optional but strongly recommended: the client generates one key per
        # checkout attempt and resends it on retry, so a double tap, a flaky
        # connection or a refreshed tab can only ever produce one order.
        #
        # The header is the usual carrier; the body field is the fallback for
        # any client or proxy that cannot send the header.
        idempotency_key = (
            request.headers.get('Idempotency-Key')
            or serializer.validated_data.get('idempotency_key')
            or ''
        ).strip()[:64]

        try:
            order, created = place_order(
                user=request.user,
                payment_method=serializer.validated_data['payment_method'],
                customer_note=serializer.validated_data.get(
                    'customer_note', ''
                ),
                idempotency_key=idempotency_key,
            )

        except ValidationError:
            # Empty cart, missing address, out of stock: already phrased for
            # the customer by the service.
            raise

        except IntegrityError:
            # Two requests raced on the same idempotency key. The loser's
            # transaction rolled back, so hand back the order the winner
            # wrote rather than reporting a failure.
            order = (
                Order.objects.filter(
                    user=request.user,
                    idempotency_key=idempotency_key
                ).first()
                if idempotency_key
                else None
            )

            if order is None:
                logger.exception(
                    'Order placement failed for user %s', request.user.pk
                )

                return Response(
                    {'detail': GENERIC_FAILURE},
                    status=status.HTTP_503_SERVICE_UNAVAILABLE
                )

            created = False

        except Exception:
            logger.exception(
                'Unexpected error placing order for user %s', request.user.pk
            )

            return Response(
                {'detail': GENERIC_FAILURE},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        body = OrderDetailSerializer(order).data

        return Response(
            body,
            status=(
                status.HTTP_201_CREATED
                if created
                else status.HTTP_200_OK
            )
        )


class OrderDetailView(generics.RetrieveAPIView):
    """One order, looked up by its order number -- owner only."""

    serializer_class = OrderDetailSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = 'order_number'

    def get_queryset(self):
        # Someone else's order number returns 404, not 403: a 403 would
        # confirm that the order exists.
        return (
            Order.objects
            .filter(user=self.request.user)
            .prefetch_related('items__variant__product')
        )
