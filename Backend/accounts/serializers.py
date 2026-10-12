from datetime import timedelta
from django.contrib.auth import authenticate
from rest_framework import serializers
from rest_framework_simplejwt.serializers import (
    TokenObtainPairSerializer
)

from .models import User

from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import (
    validate_password
)
from django.utils import timezone


from .models import Address


User = get_user_model()


# =========================================================
# REGISTER
# =========================================================

class RegisterSerializer(
    serializers.ModelSerializer
):


    password = serializers.CharField(
        write_only=True
    )

    password2 = serializers.CharField(
        write_only=True
    )

    class Meta:

        model = User

        fields = [
            'email',
            'phone',
            'first_name',
            'last_name',
            'password',
            'password2',
        ]
        

    def validate_email(self, value):
        user = User.objects.filter(email=value).first()

        if user:
            if user.is_email_verified:
                raise serializers.ValidationError(
                    "A user with this email already exists."
                )
            user.delete()

        return value


    def validate(self, data):

        if data['password'] != data['password2']:

            raise serializers.ValidationError({
                'password2':
                    'Passwords do not match.'
            })

        user = User(
            email=data['email'],
            phone=data['phone'],
            first_name=data.get('first_name'),
            last_name=data.get('last_name'),
        )

        validate_password(
            data['password'],
            user=user
        )

        return data

    def create(self, validated_data):

        validated_data.pop(
            'password2'
        )

        password = validated_data.pop(
            'password'
        )

        user = User.objects.create_user(
            password=password,
            **validated_data
        )

        return user

# =========================================================
# VERIFY EMAIL OTP
# =========================================================

class VerifyEmailOTPSerializer(
    serializers.Serializer
):

    email = serializers.EmailField()

    otp = serializers.CharField(
        min_length=6,
        max_length=6
    )

    def validate(self, data):

        email = data['email']
        otp = data['otp']

        user = User.objects.filter(
            email=email
        ).first()

        if not user:

            raise serializers.ValidationError({
                'email':
                    'Invalid email or OTP.'
            })

        if user.is_email_verified:

            raise serializers.ValidationError({
                'email':
                    'Email is already verified.'
            })

        if not user.email_otp:

            raise serializers.ValidationError({
                'otp':
                    'No OTP found. Please request a new OTP.'
            })

        if not user.email_otp_created_at:

            raise serializers.ValidationError({
                'otp':
                    'Invalid OTP. Please request a new OTP.'
            })

        expiry_time = (
            user.email_otp_created_at
            + timedelta(minutes=10)
        )

        if timezone.now() > expiry_time:

            raise serializers.ValidationError({
                'otp':
                    'OTP has expired. Please request a new OTP.'
            })

        if user.email_otp != otp:

            raise serializers.ValidationError({
                'otp':
                    'Invalid OTP.'
            })

        data['user'] = user

        return data

    
# =========================================================
# LOGIN
# =========================================================

class LoginSerializer(TokenObtainPairSerializer):

    def validate(self, attrs):

        email = attrs.get("email")
        password = attrs.get("password")

        # Check email
        if not email:
            raise serializers.ValidationError({
                "email": "Email is required."
            })

        # Check password
        if not password:
            raise serializers.ValidationError({
                "password": "Password is required."
            })

        # Find and authenticate user
        user = authenticate(
            request=self.context.get("request"),
            email=email,
            password=password
        )

        # Wrong email or password
        if user is None:
            print("Authentication failed for email:", email)  # Debugging line
            raise serializers.ValidationError({
                "detail": "Invalid email or password."
            })

        # Email verification check
        if not user.is_email_verified:

            raise serializers.ValidationError({
                "email":
                    "Please verify your email before logging in."
            })

        # Store authenticated user
        self.user = user

        # Generate JWT tokens
        refresh = self.get_token(user)

        return {
            "refresh": str(refresh),
            "access": str(refresh.access_token),
        }


# =========================================================
# FORGOT PASSWORD
# =========================================================

class ForgotPasswordSerializer(
    serializers.Serializer
):

    email = serializers.EmailField()

    def validate_email(self, value):
        user = User.objects.filter(
            email=value
        ).first()

        if not user:
            raise serializers.ValidationError({
                'email':
                    'No user found with this email address.'
            })

        return value

# =========================================================
# VERIFY FORGET PASSWORD EMAIL OTP
# =========================================================


class VerifyPasswordOTPSerializer(
    serializers.Serializer
):

    email = serializers.EmailField()

    otp = serializers.CharField(
        min_length=6,
        max_length=6
    )

    def validate(self, data):

        email = data['email']
        otp = data['otp']

        # --------------------------------
        # Find user
        # --------------------------------

        user = User.objects.filter(
            email=email
        ).first()

        if not user:

            raise serializers.ValidationError({
                'email':
                    'Invalid email or OTP.'
            })


        # --------------------------------
        # Check OTP exists
        # --------------------------------

        if not user.password_reset_otp:

            raise serializers.ValidationError({
                'otp':
                    'No OTP found. Please request a new OTP.'
            })


        # --------------------------------
        # Check OTP creation time
        # --------------------------------

        if not user.password_reset_otp_created_at:

            raise serializers.ValidationError({
                'otp':
                    'Invalid OTP. Please request a new OTP.'
            })


        # --------------------------------
        # Check OTP expiry
        # --------------------------------

        expiry_time = (
            user.password_reset_otp_created_at
            + timedelta(minutes=10)
        )

        if timezone.now() > expiry_time:

            raise serializers.ValidationError({
                'otp':
                    'OTP has expired. Please request a new OTP.'
            })


        # --------------------------------
        # Check OTP
        # --------------------------------

        if user.password_reset_otp != otp:

            raise serializers.ValidationError({
                'otp':
                    'Invalid OTP.'
            })


        # --------------------------------
        # Store user
        # --------------------------------

        data['user'] = user

        return data

# =========================================================
# RESET PASSWORD FORGET PASSWORD
# =========================================================
class ResetPasswordSerializer(
    serializers.Serializer
):

    reset_token = serializers.CharField()

    password = serializers.CharField(
        write_only=True
    )

    password2 = serializers.CharField(
        write_only=True
    )


    def validate(self, data):

        reset_token = data['reset_token']

        password = data['password']

        password2 = data['password2']


        # =================================
        # Check password confirmation
        # =================================

        if password != password2:

            raise serializers.ValidationError({
                'password2':
                    'Passwords do not match.'
            })


        # =================================
        # Find user by reset token
        # =================================

        user = User.objects.filter(
            password_reset_token=reset_token
        ).first()


        if not user:

            raise serializers.ValidationError({
                'reset_token':
                    'Invalid or expired reset token.'
            })


        # =================================
        # Check token creation time
        # =================================

        if not user.password_reset_token_created_at:

            raise serializers.ValidationError({
                'reset_token':
                    'Invalid or expired reset token.'
            })


        # =================================
        # Token expires after 10 minutes
        # =================================

        expiry_time = (
            user.password_reset_token_created_at
            + timedelta(minutes=10)
        )


        if timezone.now() > expiry_time:

            raise serializers.ValidationError({
                'reset_token':
                    'Reset token has expired. Please request a new OTP.'
            })


        # =================================
        # Validate password
        # =================================

        validate_password(
            password,
            user=user
        )


        # =================================
        # Store user
        # =================================

        data['user'] = user

        return data

# =========================================================
# CHANGE PASSWORD
# =========================================================

class ChangePasswordSerializer(
    serializers.Serializer
):

    current_password = serializers.CharField(
        write_only=True
    )

    new_password = serializers.CharField(
        write_only=True
    )

    new_password2 = serializers.CharField(
        write_only=True
    )

    def validate_current_password(
        self,
        value
    ):

        user = self.context[
            'request'
        ].user

        if not user.check_password(value):

            raise serializers.ValidationError(
                'Current password is incorrect.'
            )

        return value

    def validate(self, data):

        if (
            data['new_password']
            != data['new_password2']
        ):

            raise serializers.ValidationError({
                'new_password2':
                    'Passwords do not match.'
            })

        validate_password(
            data['new_password'],
            user=self.context[
                'request'
            ].user
        )

        return data

# =========================================================
# USER
# =========================================================

class UserSerializer(serializers.ModelSerializer):

    class Meta:

        model = User

        fields = [
            'id',
            'email',
            'first_name',
            'last_name',
            'phone',
            'date_joined',
        ]

        read_only_fields = [
            'id',
            'email',
            'date_joined',
        ]


# =========================================================
# ADDRESS
# =========================================================


class AddressSerializer(serializers.ModelSerializer):

    class Meta:

        model = Address

        fields = [
            'id',
            'first_name',
            'last_name',
            'company',
            'address1',
            'address2',
            'city',
            'postal_code',
            'country',
            'region',
            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'created_at',
            'updated_at',
        ]   

    def create(self, validated_data):
        user = self.context['request'].user

        if Address.objects.filter(user=user).exists():
            raise serializers.ValidationError({
                "address": "You already have an address."
            })

        address = Address.objects.create(
            **validated_data
        )

        return address









