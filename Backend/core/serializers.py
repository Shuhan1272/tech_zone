from rest_framework import serializers
from .models import Notice


class NoticeSerializer(serializers.ModelSerializer):

    class Meta:
        model = Notice
        fields = [
            'id',
            'title',
            'message',
            'notice_type',
            'is_active',
            'is_featured',
            'start_at',
            'end_at',
            'created_at',
            'updated_at',
        ]
        read_only_fields = [
            'id',
            'created_at',
            'updated_at',
        ]