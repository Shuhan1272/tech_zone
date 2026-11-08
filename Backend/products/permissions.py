from rest_framework.permissions import BasePermission, SAFE_METHODS


# =========================================================
# ADMIN OR READ ONLY
# =========================================================

class IsAdminOrReadOnly(BasePermission):

    def has_permission(self, request, view):

        # Everyone can read.
        if request.method in SAFE_METHODS:
            return True

        # Only admins can create, update or delete.
        return (
            request.user.is_authenticated
            and getattr(request.user, 'role', None)
            in ['admin', 'super_admin']
        )


# =========================================================
# OWNER OR ADMIN OR READ ONLY
# =========================================================

class IsOwnerOrAdminOrReadOnly(BasePermission):

    def has_permission(self, request, view):

        # Everyone can view questions and reviews.
        if request.method in SAFE_METHODS:
            return True

        # Login required for creating or modifying.
        return request.user.is_authenticated

    def has_object_permission(self, request, view, obj):

        # Everyone can read.
        if request.method in SAFE_METHODS:
            return True

        # Admins can manage all questions and reviews.
        if (
            getattr(request.user, 'role', None)
            in ['admin', 'super_admin']
        ):
            return True

        # Regular users can modify only their own content.
        return (
            request.user.is_authenticated
            and obj.user_id == request.user.pk
        )