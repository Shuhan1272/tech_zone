from django.urls import path

from .views import (
    CartItemDetailView,
    CartView,
    CartItemCreateView,
    CartItemDetailView,
)


urlpatterns = [
    path('', CartView.as_view(), name='cart'),
    
    path(
        'items/',
        CartItemCreateView.as_view(),
        name='cart-item-create'
    ),

     path(
        'items/<int:pk>/',
        CartItemDetailView.as_view(),
        name='cart-item-detail'
    ),
]