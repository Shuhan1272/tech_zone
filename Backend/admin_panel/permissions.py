"""Permission gates shared by the operations console."""

from rest_framework.permissions import IsAdminUser


class IsActiveStaff(IsAdminUser):
    def has_permission(self, request, view):
        return bool(super().has_permission(request, view) and request.user.is_active)
