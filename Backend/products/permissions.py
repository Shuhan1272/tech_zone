"""Public reads and explicit, model-scoped staff permissions."""

from rest_framework.permissions import BasePermission, SAFE_METHODS


def staff_can(user, model, action):
    if not user.is_authenticated or not user.is_active or not user.is_staff:
        return False
    opts = model._meta
    return user.has_perm(f"{opts.app_label}.{action}_{opts.model_name}")


def view_model(view):
    queryset = getattr(view, "queryset", None)
    if queryset is not None:
        return queryset.model
    return view.get_serializer_class().Meta.model


class IsAdminOrReadOnly(BasePermission):
    """A staff flag or legacy role string never grants catalog write access."""

    actions = {"POST": "add", "PUT": "change", "PATCH": "change", "DELETE": "delete"}

    def has_permission(self, request, view):
        if request.method in SAFE_METHODS:
            return True
        action = self.actions.get(request.method)
        return bool(action and staff_can(request.user, view_model(view), action))


class IsOwnerOrAdminOrReadOnly(BasePermission):
    def has_permission(self, request, view):
        return request.method in SAFE_METHODS or bool(
            request.user.is_authenticated and request.user.is_active
        )

    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True
        action = "delete" if request.method == "DELETE" else "change"
        return (
            staff_can(request.user, type(obj), action) or obj.user_id == request.user.pk
        )
