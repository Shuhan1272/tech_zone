from rest_framework import viewsets
from .models import Notice
from .serializers import NoticeSerializer
from django_filters.rest_framework import DjangoFilterBackend
from products.permissions import IsAdminOrReadOnly


class NoticeViewSet(viewsets.ModelViewSet):

    queryset = Notice.objects.all()
    serializer_class = NoticeSerializer
    permission_classes = [IsAdminOrReadOnly]

    filter_backends = [
        DjangoFilterBackend
    ]

    filterset_fields = [
        'notice_type',
        'is_active',
        'is_featured',
    ]