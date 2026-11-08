from django.urls import path

from .views import (
    CheckoutView,
    MyOrderListView,
    OrderDetailView,
    OrderCancelView,
)


urlpatterns = [

    path(
        'checkout/',
        CheckoutView.as_view(),
        name='order-checkout'
    ),

    path(
        '',
        MyOrderListView.as_view(),
        name='my-orders'
    ),

    path(
        '<int:pk>/cancel/',
        OrderCancelView.as_view(),
        name='order-cancel'
    ),

    path(
        '<int:pk>/',
        OrderDetailView.as_view(),
        name='order-detail'
    ),

]