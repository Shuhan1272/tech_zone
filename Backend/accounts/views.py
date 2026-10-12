import secrets
from django.core import serializers
from rest_framework import generics
from .models import User
from django.utils import timezone
from rest_framework import status
from .throttles import LoginThrottle, RegisterThrottle

from rest_framework_simplejwt.tokens import RefreshToken

from rest_framework.permissions import (
    AllowAny,
    IsAuthenticated
)

from rest_framework.response import Response

from rest_framework_simplejwt.views import (
    TokenObtainPairView,
)
from rest_framework import viewsets

from .models import Address

from .serializers import (
    RegisterSerializer,
    LoginSerializer,
    UserSerializer,
    AddressSerializer,
    ChangePasswordSerializer,
    ForgotPasswordSerializer,
    ResetPasswordSerializer,
    VerifyEmailOTPSerializer,
    VerifyPasswordOTPSerializer
)

from .utils import (
    send_verification_otp,
    send_password_reset_otp
)




# =========================================================
# REGISTER
# =========================================================

class RegisterView(generics.GenericAPIView):

    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]
    #throttle_classes = [RegisterThrottle]

    def post(self, request):

        
        serializer = self.get_serializer(
            data=request.data
        )

        user = User.objects.filter(email=serializer.initial_data.get('email')).first()

        if user and not user.is_email_verified:
            user.delete()

        serializer.is_valid(
            raise_exception=True
        )

        user = serializer.save()

        send_verification_otp(user)

        return Response(
            serializer.data,
            status=status.HTTP_201_CREATED
        )

# =========================================================
# VERIFY REGISTER EMAIL OTP
# =========================================================

class VerifyEmailView(
    generics.GenericAPIView
):

    serializer_class = (
        VerifyEmailOTPSerializer
    )

    permission_classes = [
        AllowAny
    ]

    def post(
        self,
        request
    ):

        serializer = self.get_serializer(
            data=request.data
        )

        serializer.is_valid(
            raise_exception=True
        )

        user = serializer.validated_data[
            'user'
        ]


        # --------------------------------
        # Verify email
        # --------------------------------

        user.is_email_verified = True

        user.email_otp = None

        user.email_otp_created_at = None


        user.save(
            update_fields=[
                'is_email_verified',
                'email_otp',
                'email_otp_created_at'
            ]
        )


        # --------------------------------
        # Generate JWT
        # --------------------------------

        refresh = RefreshToken.for_user(
            user
        )

        access_token = refresh.access_token


        # --------------------------------
        # Return JWT + user
        # --------------------------------

        return Response({

            'message':
                'Email verified successfully.',

            'access':
                str(access_token),

            'refresh':
                str(refresh),

            'user': {

                'id':
                    user.id,

                'email':
                    user.email,

                'first_name':
                    user.first_name,

                'last_name':
                    user.last_name,

                'is_email_verified':
                    user.is_email_verified,
            }
        })


# =========================================================
# LOGIN
# =========================================================

class LoginView(
    TokenObtainPairView
):

    serializer_class = LoginSerializer
    #throttle_classes = [LoginThrottle]

# =========================================================
# FORGOT PASSWORD
# =========================================================

class ForgotPasswordView(
    generics.GenericAPIView
):

    serializer_class = (
        ForgotPasswordSerializer
    )

    permission_classes = [
        AllowAny
    ]

    #throttle_classes = [ForgotPasswordThrottle]    

    def post(
        self,
        request
    ):

        serializer = self.get_serializer(
            data=request.data
        )

        serializer.is_valid(
            raise_exception=True
        )


        # --------------------------------
        # Get email
        # --------------------------------

        email = serializer.validated_data[
            'email'
        ]


        # --------------------------------
        # Find user
        # --------------------------------

        user = User.objects.filter(
            email=email
        ).first()


        # --------------------------------
        # Send OTP if user exists
        # --------------------------------

        if user:

            send_password_reset_otp(
                user
            )


        # --------------------------------
        # Generic response
        # --------------------------------

        return Response({

            'message':
                'If an account exists with this email, '
                'a password reset OTP has been sent.'

        })


# =========================================================
#  VERIFY FORGOT PASSWORD OTP
# =========================================================

class VerifyPasswordOTPView(
    generics.GenericAPIView
):

    serializer_class = (
        VerifyPasswordOTPSerializer
    )

    permission_classes = [
        AllowAny
    ]

    def post(
        self,
        request
    ):

        # --------------------------------
        # Validate email + OTP
        # --------------------------------

        serializer = self.get_serializer(
            data=request.data
        )

        serializer.is_valid(
            raise_exception=True
        )


        # --------------------------------
        # Get user
        # --------------------------------

        user = serializer.validated_data[
            'user'
        ]


        # --------------------------------
        # Generate temporary reset token
        # --------------------------------

        reset_token = secrets.token_urlsafe(
            32
        )


        # --------------------------------
        # Save reset token
        # --------------------------------

        user.password_reset_token = (
            reset_token
        )

        user.password_reset_token_created_at = (
            timezone.now()
        )


        # --------------------------------
        # Clear OTP
        # --------------------------------

        user.email_otp = None

        user.email_otp_created_at = None


        # --------------------------------
        # Save user
        # --------------------------------

        user.save(
            update_fields=[
                'password_reset_token',
                'password_reset_token_created_at',
                'email_otp',
                'email_otp_created_at',
            ]
        )


        # --------------------------------
        # Response
        # --------------------------------

        return Response({

            'message':
                'OTP verified successfully.',

            'reset_token':
                reset_token,

        })

# =========================================================
# RESET PASSWORD FOR FORGOT PASSWORD
# =========================================================


class ResetPasswordView(
    generics.GenericAPIView
):

    serializer_class = (
        ResetPasswordSerializer
    )

    permission_classes = [
        AllowAny
    ]

    def post(
        self,
        request
    ):

        # --------------------------------
        # Validate reset token + password
        # --------------------------------

        serializer = self.get_serializer(
            data=request.data
        )

        serializer.is_valid(
            raise_exception=True
        )


        # --------------------------------
        # Get user
        # --------------------------------

        user = serializer.validated_data[
            'user'
        ]


        # --------------------------------
        # Get new password
        # --------------------------------

        password = serializer.validated_data[
            'password'
        ]


        # --------------------------------
        # Set new password
        # --------------------------------

        user.set_password(
            password
        )


        # --------------------------------
        # Invalidate reset token
        # --------------------------------

        user.password_reset_token = None

        user.password_reset_token_created_at = None


        # --------------------------------
        # Save user
        # --------------------------------

        user.save(
            update_fields=[
                'password',
                'password_reset_token',
                'password_reset_token_created_at',
            ]
        )


        # --------------------------------
        # Response
        # --------------------------------

        return Response({

            'message':
                'Password reset successfully.'

        })

# =========================================================
# CHANGE PASSWORD
# =========================================================

class ChangePasswordView(
    generics.GenericAPIView
):

    serializer_class = (
        ChangePasswordSerializer
    )

    permission_classes = [
        IsAuthenticated
    ]

    def post(
        self,
        request
    ):

        serializer = self.get_serializer(
            data=request.data
        )

        serializer.is_valid(
            raise_exception=True
        )

        user = request.user

        user.set_password(
            serializer.validated_data[
                'new_password'
            ]
        )

        user.save(
            update_fields=[
                'password'
            ]
        )

        return Response({
            'message':
                'Password changed successfully.'
        })



# =========================================================
# MY PROFILE
# =========================================================

class MeView(generics.RetrieveUpdateAPIView):

    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):

        return self.request.user



# =========================================================
# ADDRESS
# =========================================================


class AddressViewSet(viewsets.ModelViewSet):

    serializer_class = AddressSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):

        return Address.objects.filter(
            user=self.request.user
        )

    def perform_create(self, serializer):

        serializer.save(
            user=self.request.user
        )
