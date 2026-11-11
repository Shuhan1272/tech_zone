"""Keep account and role administration out of delegated staff permissions."""

from django.contrib import admin
from django.contrib.auth.admin import GroupAdmin
from django.contrib.auth.models import Group

from .models import Address, User


class OwnerOnlyAdminMixin:
    def has_module_permission(self, request):
        return bool(request.user.is_active and request.user.is_superuser)

    def has_view_permission(self, request, obj=None):
        return self.has_module_permission(request)

    def has_add_permission(self, request):
        return self.has_module_permission(request)

    def has_change_permission(self, request, obj=None):
        return self.has_module_permission(request)

    def has_delete_permission(self, request, obj=None):
        return self.has_module_permission(request)


@admin.register(User)
class AccountAdmin(OwnerOnlyAdminMixin, admin.ModelAdmin):
    list_display = ("email", "first_name", "last_name", "is_staff", "is_active")
    list_filter = ("is_active", "is_staff", "is_superuser")
    search_fields = ("email", "first_name", "last_name", "phone")
    readonly_fields = ("password", "last_login", "date_joined")
    exclude = (
        "email_otp",
        "email_otp_created_at",
        "password_reset_otp",
        "password_reset_otp_created_at",
        "password_reset_token",
        "password_reset_token_created_at",
    )

    def has_add_permission(self, request):
        # Staff creation in the console validates and hashes the initial password.
        return False

    def has_delete_permission(self, request, obj=None):
        return False


admin.site.unregister(Group)


@admin.register(Group)
class RoleAdmin(OwnerOnlyAdminMixin, GroupAdmin):
    pass


admin.site.register(Address)
