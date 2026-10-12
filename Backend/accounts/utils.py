import random

from django.conf import settings
from django.core.mail import send_mail


from datetime import timedelta

from django.utils import timezone


def generate_email_otp():

    return str(
        random.randint(100000, 999999)
    )


def send_verification_otp(user):

    otp = generate_email_otp()

    user.email_otp = otp

    from django.utils import timezone

    user.email_otp_created_at = timezone.now()

    user.save(
        update_fields=[
            'email_otp',
            'email_otp_created_at'
        ]
    )

    send_mail(
        subject='Email Verification OTP',

        message=(
            f'Your email verification OTP is: {otp}\n\n'
            'This OTP is valid for 10 minutes.\n\n'
            'If you did not create this account, '
            'you can ignore this email.'
        ),

        from_email=settings.DEFAULT_FROM_EMAIL,

        recipient_list=[
            user.email
        ],

        fail_silently=False
    )



def send_password_reset_otp(user):

    # --------------------------------
    # Generate OTP
    # --------------------------------

    otp = generate_email_otp()


    # --------------------------------
    # Save password reset OTP
    # --------------------------------

    user.password_reset_otp = otp

    user.password_reset_otp_created_at = (
        timezone.now()
    )

    user.save(
        update_fields=[
            'password_reset_otp',
            'password_reset_otp_created_at',
        ]
    )


    # --------------------------------
    # Send OTP to Gmail
    # --------------------------------

    send_mail(

        subject='FastKart Password Reset OTP',

        message=(
            f'Hello {user.first_name},\n\n'

            f'Your FastKart password reset OTP is:\n\n'

            f'{otp}\n\n'

            'This OTP is valid for 10 minutes.\n\n'

            'If you did not request a password reset, '
            'please ignore this email.\n\n'

            'Thank you,\n'
            'FastKart Team'
        ),

        from_email=settings.DEFAULT_FROM_EMAIL,

        recipient_list=[
            user.email
        ],

        fail_silently=False
    )




