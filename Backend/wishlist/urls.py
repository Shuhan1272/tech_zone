from django.urls import path

from .views import (
    WishlistView,
    WishlistAddView,
    WishlistRemoveView,
    WishlistShareView,
    PublicWishlistView,
    WishlistDownloadView,
)

urlpatterns = [
    path('', WishlistView.as_view(), name='wishlist'),
    path('items/', WishlistAddView.as_view(), name='wishlist-add'),
    path(
        'items/<int:pk>/',
        WishlistRemoveView.as_view(),
        name='wishlist-remove'
    ),
    path('share/', WishlistShareView.as_view(), name='wishlist-share'),
    path(
        'shared/<uuid:token>/',
        PublicWishlistView.as_view(),
        name='wishlist-public'
    ),
    path(
        'download/',
        WishlistDownloadView.as_view(),
        name='wishlist-download'
    ),
]