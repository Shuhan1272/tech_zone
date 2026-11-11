from django import forms
from django.contrib import admin, messages
from django.core.exceptions import (
    PermissionDenied,
    ValidationError as DjangoValidationError,
)
from django.db import transaction
from django.http import HttpResponseRedirect
from django.urls import reverse
from django.utils.html import format_html

from rest_framework.exceptions import ValidationError as DRFValidationError

from .models import Order, OrderItem
from .services import cancel_order, confirm_cod_payment

# =========================================================
# ERROR MESSAGE HELPER
# =========================================================


def readable_error(exc):
    """
    Convert DRF validation errors into readable messages.
    """

    detail = getattr(exc, "detail", None)

    if isinstance(detail, dict):
        messages_list = []

        for field, errors in detail.items():
            if not isinstance(errors, (list, tuple)):
                errors = [errors]

            for error in errors:
                messages_list.append(str(error))

        return " ".join(messages_list)

    if isinstance(detail, (list, tuple)):
        return " ".join(str(error) for error in detail)

    if detail is not None:
        return str(detail)

    return str(exc)


# =========================================================
# SAFE ORDER STATUS TRANSITION
# =========================================================


@transaction.atomic
def change_order_status(order_id, new_status):

    order = Order.objects.select_for_update().get(pk=order_id)

    current_status = order.status

    if new_status == current_status:
        return order

    allowed_transitions = {
        "pending": ["confirmed", "cancelled"],
        "confirmed": ["shipped", "cancelled"],
        "shipped": ["delivered"],
        "delivered": [],
        "cancelled": [],
    }

    allowed = allowed_transitions.get(current_status, [])

    if new_status not in allowed:
        raise DjangoValidationError(
            f"Cannot change order status from "
            f"{current_status.title()} to "
            f"{new_status.title()}."
        )

    # Cancellation must use the existing service.
    if new_status == "cancelled":
        return cancel_order(order_id)

    # Online orders must be paid.
    if order.payment_method == "sslcommerz":

        if order.payment_status != "paid":
            raise DjangoValidationError(
                "SSLCommerz payment must be completed "
                "before updating the order status."
            )

    # COD orders must have pending payment.
    elif order.payment_method == "cod":

        if order.payment_status != "pending":
            raise DjangoValidationError(
                "COD payment must be pending during "
                "confirmation, shipping and delivery."
            )

    else:
        raise DjangoValidationError("Unsupported payment method.")

    order.status = new_status

    order.save(
        update_fields=[
            "status",
            "updated_at",
        ]
    )

    return order


# =========================================================
# ORDER ADMIN FORM
# =========================================================


class OrderAdminForm(forms.ModelForm):

    # This is a separate field used to request a transition.
    # It does not directly overwrite Order.status.
    new_order_status = forms.ChoiceField(
        label="Change Order Status",
        required=False,
        choices=[],
        help_text=("Select the next permitted status and save."),
    )

    class Meta:
        model = Order
        fields = "__all__"

    def __init__(self, *args, **kwargs):

        super().__init__(*args, **kwargs)

        order = self.instance

        if not order or not order.pk:
            self.fields["new_order_status"].choices = [("", "No order selected")]
            return

        allowed_transitions = {
            "pending": ["confirmed", "cancelled"],
            "confirmed": ["shipped", "cancelled"],
            "shipped": ["delivered"],
            "delivered": [],
            "cancelled": [],
        }

        allowed = allowed_transitions.get(order.status, [])

        choices = [("", f"Keep current status ({order.get_status_display()})")]

        status_labels = dict(Order.STATUS_CHOICES)

        for value in allowed:
            choices.append((value, status_labels.get(value, value.title())))

        self.fields["new_order_status"].choices = choices

    def clean_new_order_status(self):

        new_status = self.cleaned_data.get("new_order_status")

        order = self.instance

        if not new_status or not order.pk:
            return new_status

        allowed_transitions = {
            "pending": ["confirmed", "cancelled"],
            "confirmed": ["shipped", "cancelled"],
            "shipped": ["delivered"],
            "delivered": [],
            "cancelled": [],
        }

        if new_status not in allowed_transitions.get(order.status, []):
            raise forms.ValidationError("This order status transition is not allowed.")

        return new_status


# =========================================================
# ORDER ITEM INLINE
# =========================================================


class OrderItemInline(admin.TabularInline):

    model = OrderItem

    extra = 0

    can_delete = False

    readonly_fields = [
        "variant",
        "product_name",
        "sku",
        "ram",
        "storage",
        "color_name",
        "unit_price",
        "quantity",
        "line_total",
    ]

    fields = readonly_fields

    verbose_name = "Purchased Product"
    verbose_name_plural = "Purchased Products"

    def has_add_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


# =========================================================
# ORDER ADMIN
# =========================================================


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):

    form = OrderAdminForm

    list_display = [
        "id",
        "user",
        "shipping_name",
        "shipping_phone",
        "payment_method",
        "formatted_total",
        "colored_status",
        "colored_payment_status",
        "created_at",
    ]

    list_display_links = [
        "id",
        "shipping_name",
    ]

    list_filter = [
        "status",
        "payment_method",
        "payment_status",
        "created_at",
    ]

    search_fields = [
        "=id",
        "user__email",
        "shipping_name",
        "shipping_phone",
        "items__product_name",
        "items__sku",
    ]

    ordering = [
        "-created_at",
    ]

    list_per_page = 25

    list_select_related = [
        "user",
    ]

    readonly_fields = [
        "user",
        "status",
        "payment_status",
        "shipping_name",
        "shipping_phone",
        "shipping_address",
        "shipping_house",
        "shipping_road",
        "shipping_division",
        "shipping_district",
        "shipping_upazila",
        "shipping_postal_code",
        "shipping_instructions",
        "payment_method",
        "subtotal",
        "discount",
        "discount_code",
        "discount_amount",
        "total_amount",
        "created_at",
        "updated_at",
    ]

    fieldsets = [
        (
            "Order Information",
            {
                "fields": [
                    "user",
                    "status",
                    "new_order_status",
                    "created_at",
                    "updated_at",
                ]
            },
        ),
        (
            "Customer Information",
            {
                "fields": [
                    "shipping_name",
                    "shipping_phone",
                ]
            },
        ),
        (
            "Delivery Address",
            {
                "fields": [
                    "shipping_address",
                    "shipping_house",
                    "shipping_road",
                    "shipping_division",
                    "shipping_district",
                    "shipping_upazila",
                    "shipping_postal_code",
                    "shipping_instructions",
                ]
            },
        ),
        (
            "Payment Information",
            {
                "fields": [
                    "payment_method",
                    "payment_status",
                ]
            },
        ),
        (
            "Order Pricing",
            {
                "fields": [
                    "subtotal",
                    "discount",
                    "discount_code",
                    "discount_amount",
                    "total_amount",
                ]
            },
        ),
    ]

    inlines = [OrderItemInline]

    actions = [
        "confirm_orders",
        "ship_orders",
        "deliver_orders",
        "confirm_cod_payments",
        "cancel_orders",
    ]

    # =====================================================
    # PERMISSIONS
    # =====================================================

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False

    # =====================================================
    # DISPLAY FORMATTING
    # =====================================================

    @admin.display(description="Total Amount")
    def formatted_total(self, obj):

        return format_html("<strong>৳{}</strong>", f"{obj.total_amount:,.2f}")

    @admin.display(description="Order Status")
    def colored_status(self, obj):

        colors = {
            "pending": "#f59e0b",
            "confirmed": "#2563eb",
            "shipped": "#7c3aed",
            "delivered": "#16a34a",
            "cancelled": "#dc2626",
        }

        color = colors.get(obj.status, "#6b7280")

        return format_html(
            '<span style="'
            "background:{};"
            "color:white;"
            "padding:5px 10px;"
            "border-radius:5px;"
            "font-weight:600;"
            "display:inline-block;"
            '">{}</span>',
            color,
            obj.get_status_display(),
        )

    @admin.display(description="Payment Status")
    def colored_payment_status(self, obj):

        colors = {
            "pending": "#f59e0b",
            "paid": "#16a34a",
            "failed": "#dc2626",
            "refunded": "#2563eb",
        }

        color = colors.get(obj.payment_status, "#6b7280")

        return format_html(
            '<span style="'
            "background:{};"
            "color:white;"
            "padding:5px 10px;"
            "border-radius:5px;"
            "font-weight:600;"
            "display:inline-block;"
            '">{}</span>',
            color,
            obj.get_payment_status_display(),
        )

    # =====================================================
    # SAVE ORDER STATUS
    # =====================================================

    def save_model(self, request, obj, form, change):

        if not change:
            super().save_model(request, obj, form, change)
            return

        new_status = form.cleaned_data.get("new_order_status")

        if not new_status:
            return

        try:

            updated_order = change_order_status(obj.pk, new_status)

            obj.status = updated_order.status
            obj.payment_status = updated_order.payment_status
            obj.updated_at = updated_order.updated_at

            self.message_user(
                request,
                (
                    f"Order #{obj.pk} status updated "
                    f"to {updated_order.get_status_display()}."
                ),
                messages.SUCCESS,
            )

        except (DjangoValidationError, DRFValidationError) as exc:

            self.message_user(request, readable_error(exc), messages.ERROR)

    # =====================================================
    # BULK ACTION HELPER
    # =====================================================

    def execute_bulk_action(
        self, request, queryset, new_status=None, special_action=None
    ):

        if not (
            request.user.is_active
            and request.user.is_staff
            and self.has_change_permission(request)
        ):
            raise PermissionDenied

        completed = 0
        skipped = 0

        for order_id in queryset.values_list("id", flat=True):

            try:

                if special_action == "confirm_cod":

                    if not request.user.is_superuser:
                        self.message_user(
                            request,
                            "Only superusers can confirm COD payments.",
                            messages.ERROR,
                        )
                        return

                    confirm_cod_payment(order_id)

                elif new_status:

                    change_order_status(order_id, new_status)

                completed += 1

            except (DjangoValidationError, DRFValidationError):

                skipped += 1

        self.message_user(
            request,
            (f"{completed} order(s) updated. " f"{skipped} skipped."),
            (messages.WARNING if skipped else messages.SUCCESS),
        )

    # =====================================================
    # BULK CONFIRM
    # =====================================================

    @admin.action(permissions=["change"], description="Confirm selected orders")
    def confirm_orders(self, request, queryset):

        self.execute_bulk_action(request, queryset, new_status="confirmed")

    # =====================================================
    # BULK SHIP
    # =====================================================

    @admin.action(permissions=["change"], description="Mark selected orders as shipped")
    def ship_orders(self, request, queryset):

        self.execute_bulk_action(request, queryset, new_status="shipped")

    # =====================================================
    # BULK DELIVER
    # =====================================================

    @admin.action(
        permissions=["change"], description="Mark selected orders as delivered"
    )
    def deliver_orders(self, request, queryset):

        self.execute_bulk_action(request, queryset, new_status="delivered")

    # =====================================================
    # BULK CONFIRM COD PAYMENT
    # =====================================================

    @admin.action(permissions=["change"], description="Confirm COD payments")
    def confirm_cod_payments(self, request, queryset):

        self.execute_bulk_action(request, queryset, special_action="confirm_cod")

    # =====================================================
    # BULK CANCEL
    # =====================================================

    @admin.action(permissions=["change"], description="Cancel selected orders")
    def cancel_orders(self, request, queryset):

        self.execute_bulk_action(request, queryset, new_status="cancelled")
