from rest_framework.viewsets import ModelViewSet

from .models import Discount
from .serializers import DiscountSerializer


class DiscountViewSet(ModelViewSet):

    queryset = Discount.objects.all()

    serializer_class = DiscountSerializer