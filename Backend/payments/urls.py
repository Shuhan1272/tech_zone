
from django.urls import path

from .views import (
    # Payment views
    PaymentInitiateView,
    MyPaymentListView,
    PaymentDetailView,
    PaymentVerifyView,

    # Customer refund views
    RefundRequestView,
    OrderRefundStatusView,

    # Admin refund views
    AdminRefundListView,
    AdminRefundDetailView,
    AdminRefundApproveView,
    AdminRefundRejectView,
    AdminRefundProcessView,
    AdminRefundCheckView,

    # SSLCommerz callbacks
    PaymentSuccessView,
    PaymentFailView,
    PaymentCancelView,
    PaymentIPNView,
)


urlpatterns = [

    # =====================================================
    # PAYMENT
    # =====================================================

    path(
        'initiate/',
        PaymentInitiateView.as_view(),
        name='payment-initiate'
    ),

    path(
        '',
        MyPaymentListView.as_view(),
        name='my-payments'
    ),

    path(
        '<int:pk>/',
        PaymentDetailView.as_view(),
        name='payment-detail'
    ),

    path(
        '<int:pk>/verify/',
        PaymentVerifyView.as_view(),
        name='payment-verify'
    ),

    # =====================================================
    # CUSTOMER REFUND REQUESTS
    # =====================================================

    path(
        'refunds/request/',
        RefundRequestView.as_view(),
        name='refund-request'
    ),

    path(
        'refunds/order/<int:order_id>/',
        OrderRefundStatusView.as_view(),
        name='order-refund-status'
    ),

    # =====================================================
    # ADMIN REFUND MANAGEMENT
    # =====================================================

    path(
        'refunds/admin/',
        AdminRefundListView.as_view(),
        name='admin-refund-list'
    ),

    path(
        'refunds/admin/<int:pk>/',
        AdminRefundDetailView.as_view(),
        name='admin-refund-detail'
    ),

    path(
        'refunds/admin/<int:pk>/approve/',
        AdminRefundApproveView.as_view(),
        name='admin-refund-approve'
    ),

    path(
        'refunds/admin/<int:pk>/reject/',
        AdminRefundRejectView.as_view(),
        name='admin-refund-reject'
    ),

    path(
        'refunds/admin/<int:pk>/process/',
        AdminRefundProcessView.as_view(),
        name='admin-refund-process'
    ),

    path(
        'refunds/admin/<int:pk>/check/',
        AdminRefundCheckView.as_view(),
        name='admin-refund-check'
    ),

    # =====================================================
    # SSLCOMMERZ CALLBACKS
    # =====================================================

    path(
        'callback/success/',
        PaymentSuccessView.as_view(),
        name='payment-success'
    ),

    path(
        'callback/fail/',
        PaymentFailView.as_view(),
        name='payment-fail'
    ),

    path(
        'callback/cancel/',
        PaymentCancelView.as_view(),
        name='payment-cancel'
    ),

    path(
        'callback/ipn/',
        PaymentIPNView.as_view(),
        name='payment-ipn'
    ),

]
