from django.urls import path

from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView

from .views import (
    RegisterView,
    LoginView,
    VerifyEmailView,
    MeView,
    ChangePasswordView,
    ForgotPasswordView,
    ResetPasswordView,
    VerifyPasswordOTPView,
    AddressViewSet,
)


# ==========================================
# Address Router
# ==========================================

router = DefaultRouter()

router.register(
    'address',
    AddressViewSet,
    basename='address'
)


# ==========================================
# Other Account URLs
# ==========================================

urlpatterns = [

    # Registration
    path(
        'register/',
        RegisterView.as_view(),
        name='register'
    ),

    # Login
    path(
        'token/',
        LoginView.as_view(),
        name='login'
    ),

    # Refresh JWT
    path(
        'token/refresh/',
        TokenRefreshView.as_view(),
        name='token-refresh'
    ),

    # Email verification
    path(
        'verify-email/',
        VerifyEmailView.as_view(),
        name='verify-email'
    ),

    # Profile
    path(
        'me/',
        MeView.as_view(),
        name='me'
    ),

    # Change password
    path(
        'change-password/',
        ChangePasswordView.as_view(),
        name='change-password'
    ),

    # Forgot password
    path(
        'forgot-password/',
        ForgotPasswordView.as_view(),
        name='forgot-password'
    ),

    # Reset password
    path(
        'reset-password/',
        ResetPasswordView.as_view(),
        name='reset-password'
    ),

    # Verify password OTP
    path(
        'verify-password-otp/',
        VerifyPasswordOTPView.as_view(),
        name='verify-password-otp'
    ),
]


# Add router URLs
urlpatterns += router.urls