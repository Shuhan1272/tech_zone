from django.contrib import admin

from .models import Wishlist, WishlistItem


@admin.register(Wishlist)
class WishlistAdmin(admin.ModelAdmin):
    list_display = ['id', 'user', 'is_public', 'created_at']
    list_filter = ['is_public', 'created_at']
    search_fields = ['user__email']
    readonly_fields = [
        'user', 'is_public', 'share_token',
        'created_at', 'updated_at'
    ]

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(WishlistItem)
class WishlistItemAdmin(admin.ModelAdmin):
    list_display = ['id', 'wishlist', 'variant', 'created_at']
    search_fields = [
        'wishlist__user__email',
        'variant__sku',
        'variant__product__name'
    ]
    readonly_fields = ['wishlist', 'variant', 'created_at']

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False