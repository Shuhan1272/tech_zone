from django.contrib.auth.models import AbstractUser
from django.db import models
from .managers import UserManager


class User(AbstractUser):

    username = None

    email = models.EmailField(unique=True)

    phone = models.CharField(
        max_length=20,
    )

    role = models.CharField(
        max_length=20,
        choices=[
            ('customer', 'Customer'),
            ('admin', 'Admin'),
            ('super_admin', 'Super Admin'),
        ],
        default='customer'
    )

    # ==============================
    # Email verification OTP
    # ==============================

    email_otp = models.CharField(
        max_length=6,
        blank=True,
        null=True
    )

    email_otp_created_at = models.DateTimeField(
        blank=True,
        null=True
    )

    is_email_verified = models.BooleanField(
        default=False
    )

    # Password reset OTP

    password_reset_otp = models.CharField(
    max_length=6,
    blank=True,
    null=True
    )

    password_reset_otp_created_at = models.DateTimeField(
        blank=True,
        null=True
    )

    # ==========================================
    # PASSWORD RESET TEMPORARY TOKEN
    # ==========================================

    password_reset_token = models.CharField(
        max_length=64,
        blank=True,
        null=True
    )

    password_reset_token_created_at = models.DateTimeField(
        blank=True,
        null=True
    )

    USERNAME_FIELD = 'email'

    REQUIRED_FIELDS = []

    objects = UserManager()

    def __str__(self):
        return self.email



class Address(models.Model):

    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='address'
    )

    first_name = models.CharField(
        max_length=100
    )

    last_name = models.CharField(
        max_length=100
    )

    company = models.CharField(
        max_length=150,
        blank=True
    )

    address1 = models.CharField(
        max_length=255
    )

    address2 = models.CharField(
        max_length=255,
        blank=True
    )

    city = models.CharField(
        max_length=100
    )

    postal_code = models.CharField(
        max_length=20
    )

    country = models.CharField(
        max_length=100,
        default='Bangladesh'
    )

    region = models.CharField(
        max_length=100
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    def __str__(self):

        return (
            f"{self.first_name} "
            f"{self.last_name} - "
            f"{self.city}"
        )
