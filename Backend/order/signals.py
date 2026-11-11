
import logging

from django.conf import settings
from django.core.mail import send_mail
from django.db import transaction
from django.db.models.signals import post_save, pre_save
from django.dispatch import receiver

from .models import Order


logger = logging.getLogger(__name__)


# =========================================================
# EMAIL HELPER
# =========================================================

def send_order_email(recipient, subject, message, order_id):
    try:
        send_mail(
            subject=subject,
            message=message,
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[recipient],
            fail_silently=False,
        )
    except Exception:
        logger.exception(
            "Failed to send email for order #%s",
            order_id
        )


# =========================================================
# TRACK PREVIOUS STATUS
# =========================================================

@receiver(pre_save, sender=Order)
def remember_previous_status(sender, instance, **kwargs):
    instance._previous_order_status = None

    if instance.pk:
        instance._previous_order_status = (
            Order.objects
            .filter(pk=instance.pk)
            .values_list("status", flat=True)
            .first()
        )


# =========================================================
# ORDER CREATED / STATUS CHANGED
# =========================================================

@receiver(post_save, sender=Order)
def order_email_notification(
    sender,
    instance,
    created,
    **kwargs
):
    order_id = instance.pk

    # Do not send an email if customer has no email.
    recipient = instance.user.email

    if not recipient:
        return

    # =====================================================
    # NEW ORDER CONFIRMATION
    # =====================================================

    if created:

        def send_confirmation():
            try:
                order = (
                    Order.objects
                    .prefetch_related("items")
                    .get(pk=order_id)
                )
            except Order.DoesNotExist:
                return

            products = "\n".join(
                (
                    f"- {item.product_name}"
                    f" ({item.ram or 'N/A'}, "
                    f"{item.storage or 'N/A'}, "
                    f"{item.color_name or 'N/A'})"
                    f" x {item.quantity}"
                    f" = BDT {item.line_total:,.2f}"
                )
                for item in order.items.all()
            )

            if order.payment_method == "cod":
                payment_note = (
                    "Payment Method: Cash on Delivery\n"
                    "Payment will be collected on delivery."
                )
            else:
                payment_note = (
                    "Payment Method: SSLCommerz\n"
                    "Please check your order page for "
                    "the latest payment status."
                )

            subject = (
                f"TechZone - Order #{order_id} Received"
            )

            message = (
                f"Hello {order.shipping_name},\n\n"
                f"Thank you for shopping with TechZone!\n\n"
                f"We have received your order.\n\n"
                f"Order ID: #{order_id}\n"
                f"Order Status: "
                f"{order.get_status_display()}\n\n"
                f"ORDER ITEMS\n"
                f"-----------------------------\n"
                f"{products}\n\n"
                f"Subtotal: BDT {order.subtotal:,.2f}\n"
                f"Discount: BDT {order.discount_amount:,.2f}\n"
                f"Total: BDT {order.total_amount:,.2f}\n\n"
                f"{payment_note}\n\n"
                f"Shipping Address:\n"
                f"{order.shipping_address}\n\n"
                f"Thank you,\n"
                f"TechZone Team"
            )

            send_order_email(
                recipient,
                subject,
                message,
                order_id
            )

        transaction.on_commit(
            send_confirmation,
            using=instance._state.db
        )
        return

    # =====================================================
    # ORDER STATUS CHANGE NOTIFICATION
    # =====================================================

    previous_status = getattr(
        instance,
        "_previous_order_status",
        None
    )

    if (
        previous_status is None
        or previous_status == instance.status
    ):
        return

    new_status = instance.get_status_display()

    def send_status_update():
        subject = (
            f"TechZone - Order #{order_id} "
            f"Status Updated"
        )

        message = (
            f"Hello {instance.shipping_name},\n\n"
            f"Your TechZone order #{order_id} "
            f"status has been updated.\n\n"
            f"New Status: {new_status}\n\n"
            f"Please log in to your TechZone account "
            f"to view your order details.\n\n"
            f"Thank you,\n"
            f"TechZone Team"
        )

        send_order_email(
            recipient,
            subject,
            message,
            order_id
        )

    transaction.on_commit(
        send_status_update,
        using=instance._state.db
    )
