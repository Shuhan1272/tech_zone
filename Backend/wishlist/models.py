from uuid import uuid4

from django.conf import settings
from django.db import models


class Wishlist(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='wishlist'
    )
    is_public = models.BooleanField(default=False)
    share_token = models.UUIDField(
        default=uuid4,
        unique=True,
        editable=False
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'{self.user} wishlist'


class WishlistItem(models.Model):
    wishlist = models.ForeignKey(
        Wishlist,
        on_delete=models.CASCADE,
        related_name='items'
    )
    variant = models.ForeignKey(
        'products.ProductVariant',
        on_delete=models.CASCADE
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        constraints = [
            models.UniqueConstraint(
                fields=['wishlist', 'variant'],
                name='unique_wishlist_variant'
            )
        ]

    def __str__(self):
        return f'{self.wishlist.user} - {self.variant}'