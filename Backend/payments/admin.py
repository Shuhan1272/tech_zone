from django.contrib import admin, messages
from django import forms
from django.core.exceptions import PermissionDenied
from django.http import HttpResponseRedirect
from django.shortcuts import get_object_or_404, render
from django.urls import path, reverse
from django.utils.html import format_html

from .models import Payment, PaymentRefund
from .services import (
    GatewayError,
    approve_reviewed_payment,
    reconcile_gateway_payment,
    request_full_refund,
    approve_refund_request,
    reject_refund_request,
    process_approved_refund,
    check_gateway_refund,
)

# =========================================================
# REFUND REVIEW FORM
# =========================================================


class RefundReviewForm(forms.Form):

    note = forms.CharField(
        label="Administrator note",
        required=False,
        max_length=2000,
        widget=forms.Textarea(
            attrs={
                "rows": 4,
                "style": "width:100%;max-width:650px;",
                "placeholder": "Enter a review note...",
            }
        ),
    )


class RefundRejectForm(forms.Form):

    note = forms.CharField(
        label="Reason for rejection",
        required=True,
        max_length=2000,
        widget=forms.Textarea(
            attrs={
                "rows": 4,
                "style": "width:100%;max-width:650px;",
                "placeholder": "Explain why the refund is rejected...",
            }
        ),
    )


# =========================================================
# PAYMENT ADMIN
# =========================================================


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):

    list_display = [
        "id",
        "order",
        "transaction_id",
        "amount",
        "currency",
        "payment_status_display",
        "payment_method",
        "risk_level",
        "created_at",
    ]

    list_filter = [
        "status",
        "currency",
        "created_at",
    ]

    search_fields = [
        "transaction_id",
        "bank_transaction_id",
        "order__user__email",
    ]

    ordering = ["-created_at"]

    readonly_fields = [
        "order",
        "transaction_id",
        "amount",
        "currency",
        "status",
        "gateway_session_key",
        "gateway_url",
        "validation_id",
        "bank_transaction_id",
        "payment_method",
        "risk_level",
        "review_reason",
        "created_at",
        "updated_at",
    ]

    actions = [
        "verify_payments",
        "approve_payments",
        "request_refund",
    ]

    list_per_page = 25

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False

    @admin.display(description="Status")
    def payment_status_display(self, obj):

        colors = {
            "initiating": "#64748b",
            "pending": "#d97706",
            "paid": "#16a34a",
            "review": "#9333ea",
            "failed": "#dc2626",
            "cancelled": "#64748b",
            "refunded": "#0891b2",
        }

        return format_html(
            '<span style="color:{};font-weight:600;">{}</span>',
            colors.get(obj.status, "#64748b"),
            obj.get_status_display(),
        )

    @admin.action(
        permissions=["change"], description="Verify selected payments with SSLCommerz"
    )
    def verify_payments(self, request, queryset):

        if not (
            request.user.is_active
            and request.user.is_staff
            and self.has_change_permission(request)
        ):
            raise PermissionDenied

        checked = 0
        failed = 0

        for payment in queryset:

            try:
                reconcile_gateway_payment(payment)
                checked += 1

            except GatewayError:
                failed += 1

        self.message_user(
            request,
            f"{checked} checked, {failed} failed.",
            messages.WARNING if failed else messages.SUCCESS,
        )

    @admin.action(
        permissions=["change"], description="Approve selected risk-reviewed payments"
    )
    def approve_payments(self, request, queryset):

        if not (
            request.user.is_active
            and request.user.is_staff
            and self.has_change_permission(request)
        ):
            raise PermissionDenied

        approved = 0
        skipped = 0

        for payment_id in queryset.values_list("pk", flat=True):

            try:
                approve_reviewed_payment(payment_id)
                approved += 1

            except GatewayError:
                skipped += 1

        self.message_user(
            request,
            f"{approved} approved, {skipped} skipped.",
            messages.WARNING if skipped else messages.SUCCESS,
        )

    @admin.action(
        permissions=["change"],
        description="Create refund request for ONE selected payment",
    )
    def request_refund(self, request, queryset):

        if not (
            request.user.is_active
            and request.user.is_staff
            and self.has_change_permission(request)
        ):
            raise PermissionDenied

        if queryset.count() != 1:

            self.message_user(
                request,
                "Select exactly one payment.",
                messages.ERROR,
            )
            return

        payment = queryset.first()

        try:
            refund = request_full_refund(
                payment_id=payment.pk,
                reason=(
                    f"Refund requested by Django Admin " f"user #{request.user.pk}"
                ),
                user=None,
            )

            self.message_user(
                request,
                f"Refund #{refund.pk} created successfully.",
                messages.SUCCESS,
            )

        except GatewayError as exc:
            self.message_user(
                request,
                str(exc),
                messages.ERROR,
            )


# =========================================================
# PAYMENT REFUND ADMIN
# =========================================================


@admin.register(PaymentRefund)
class PaymentRefundAdmin(admin.ModelAdmin):

    list_display = [
        "id",
        "payment",
        "order_id_display",
        "amount",
        "refund_status_display",
        "reviewed_by",
        "refund_reference_id",
        "refund_actions",
        "created_at",
    ]

    list_filter = [
        "status",
        "created_at",
        "reviewed_at",
        "completed_at",
    ]

    search_fields = [
        "payment__transaction_id",
        "payment__bank_transaction_id",
        "payment__order__user__email",
        "refund_reference_id",
    ]

    ordering = ["-created_at"]

    readonly_fields = [
        "payment",
        "amount",
        "reason",
        "refund_reference_id",
        "status",
        "reviewed_by",
        "reviewed_at",
        "admin_note",
        "processing_started_at",
        "completed_at",
        "failure_reason",
        "created_at",
        "updated_at",
        "refund_action_buttons",
    ]

    fieldsets = [
        (
            "Refund Information",
            {
                "fields": [
                    "payment",
                    "amount",
                    "reason",
                    "status",
                    "refund_reference_id",
                ]
            },
        ),
        (
            "Admin Review",
            {
                "fields": [
                    "reviewed_by",
                    "reviewed_at",
                    "admin_note",
                ]
            },
        ),
        (
            "Gateway Processing",
            {
                "fields": [
                    "processing_started_at",
                    "completed_at",
                    "failure_reason",
                ]
            },
        ),
        (
            "Refund Management",
            {
                "fields": [
                    "refund_action_buttons",
                ]
            },
        ),
        (
            "Timestamps",
            {
                "fields": [
                    "created_at",
                    "updated_at",
                ]
            },
        ),
    ]

    actions = [
        "approve_refunds",
        "reject_refunds",
        "process_refunds",
        "check_refunds",
    ]

    list_per_page = 25

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .select_related(
                "payment",
                "payment__order",
                "reviewed_by",
            )
        )

    # =====================================================
    # CUSTOM ADMIN URLS
    # =====================================================

    def get_urls(self):

        custom_urls = [
            path(
                "<int:refund_id>/manage/<str:action>/",
                self.admin_site.admin_view(self.manage_refund_view),
                name="payments_paymentrefund_manage",
            ),
        ]

        return custom_urls + super().get_urls()

    # =====================================================
    # PERMISSIONS
    # =====================================================

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False

    def has_change_permission(self, request, obj=None):
        return bool(
            request.user.is_active
            and request.user.is_staff
            and super().has_change_permission(request, obj)
        )

    def _can_manage(self, request, refund):

        return (
            request.user.is_active
            and request.user.is_staff
            and self.has_change_permission(
                request,
                refund,
            )
        )

    # =====================================================
    # STATUS DISPLAY
    # =====================================================

    @admin.display(description="Order ID")
    def order_id_display(self, obj):
        return obj.payment.order_id

    @admin.display(description="Refund Status")
    def refund_status_display(self, obj):

        colors = {
            "requested": "#d97706",
            "approved": "#2563eb",
            "rejected": "#dc2626",
            "initiating": "#9333ea",
            "processing": "#0891b2",
            "refunded": "#16a34a",
            "failed": "#dc2626",
        }

        return format_html(
            '<span style="color:{};font-weight:600;">{}</span>',
            colors.get(obj.status, "#64748b"),
            obj.get_status_display(),
        )

    # =====================================================
    # ACTION BUTTON HELPERS
    # =====================================================

    def _action_url(self, refund, action):

        return reverse(
            "admin:payments_paymentrefund_manage",
            args=[refund.pk, action],
        )

    def _button(self, refund, action, label, color):

        return format_html(
            '<a href="{}" style="'
            "display:inline-block;"
            "padding:7px 12px;"
            "margin:3px;"
            "border-radius:5px;"
            "background:{};"
            "color:white;"
            "text-decoration:none;"
            "font-weight:600;"
            "font-size:12px;"
            "white-space:nowrap;"
            '">{}</a>',
            self._action_url(refund, action),
            color,
            label,
        )

    def _buttons_html(self, refund):

        buttons = []

        if refund.status == "requested":

            buttons.append(
                self._button(
                    refund,
                    "approve",
                    "Approve",
                    "#16a34a",
                )
            )

            buttons.append(
                self._button(
                    refund,
                    "reject",
                    "Reject",
                    "#dc2626",
                )
            )

        elif refund.status == "approved":

            buttons.append(
                self._button(
                    refund,
                    "process",
                    "Process Refund",
                    "#2563eb",
                )
            )

            buttons.append(
                self._button(
                    refund,
                    "reject",
                    "Reject",
                    "#dc2626",
                )
            )

        elif refund.status in [
            "initiating",
            "processing",
        ]:

            buttons.append(
                self._button(
                    refund,
                    "check",
                    "Check Status",
                    "#0891b2",
                )
            )

        if not buttons:
            return format_html(
                '<span style="color:#64748b;">No actions available</span>'
            )

        return format_html(
            "{}",
            format_html(
                "{}",
                *buttons,
            ),
        )

    @admin.display(description="Actions")
    def refund_actions(self, obj):

        return self._buttons_html(obj)

    @admin.display(description="Refund Actions")
    def refund_action_buttons(self, obj):

        if not obj or not obj.pk:
            return "Save the refund first."

        return self._buttons_html(obj)

    # =====================================================
    # CONFIRM ACTION VIEW
    # =====================================================

    def manage_refund_view(
        self,
        request,
        refund_id,
        action,
    ):

        refund = get_object_or_404(
            PaymentRefund.objects.select_related(
                "payment",
                "payment__order",
            ),
            pk=refund_id,
        )

        if not self._can_manage(request, refund):
            raise PermissionDenied

        allowed_actions = {
            "approve": ["requested"],
            "reject": ["requested", "approved"],
            "process": ["approved"],
            "check": ["initiating", "processing"],
        }

        change_url = reverse(
            "admin:payments_paymentrefund_change",
            args=[refund.pk],
        )

        if action not in allowed_actions or refund.status not in allowed_actions.get(
            action, []
        ):
            self.message_user(
                request,
                "This action is not available for the current refund status.",
                messages.ERROR,
            )
            return HttpResponseRedirect(change_url)

        action_titles = {
            "approve": "Approve Refund Request",
            "reject": "Reject Refund Request",
            "process": "Process Refund Through SSLCommerz",
            "check": "Check Refund Status",
        }

        if action == "reject":
            form_class = RefundRejectForm
        else:
            form_class = RefundReviewForm

        form = form_class(request.POST if request.method == "POST" else None)

        if request.method == "POST" and form.is_valid():

            note = form.cleaned_data.get("note", "")

            try:

                if action == "approve":

                    approve_refund_request(
                        refund_id=refund.pk,
                        admin_user=request.user,
                        note=note,
                    )

                    success_message = f"Refund #{refund.pk} approved successfully."

                elif action == "reject":

                    reject_refund_request(
                        refund_id=refund.pk,
                        admin_user=request.user,
                        note=note,
                    )

                    success_message = f"Refund #{refund.pk} rejected."

                elif action == "process":

                    updated_refund = process_approved_refund(
                        refund_id=refund.pk,
                        admin_user=request.user,
                    )

                    success_message = (
                        f"Refund #{refund.pk} processing result: "
                        f"{updated_refund.status}. "
                        "Verify the gateway result before cancellation."
                    )

                elif action == "check":

                    updated_refund = check_gateway_refund(refund)

                    success_message = f"Refund #{refund.pk} checked with SSLCommerz."

                self.message_user(
                    request,
                    success_message,
                    messages.SUCCESS,
                )

            except GatewayError as exc:

                self.message_user(
                    request,
                    str(exc),
                    messages.ERROR,
                )

            return HttpResponseRedirect(change_url)

        context = {
            **self.admin_site.each_context(request),
            "title": action_titles[action],
            "opts": self.model._meta,
            "original": refund,
            "refund": refund,
            "action_name": action,
            "form": form,
            "change_url": change_url,
            "is_popup": False,
            "has_view_permission": True,
            "has_change_permission": True,
            "has_add_permission": False,
            "has_delete_permission": False,
        }

        return render(
            request,
            "admin/payments/refund_action.html",
            context,
        )

    # =====================================================
    # EXISTING BULK ACTIONS
    # =====================================================

    @admin.action(
        permissions=["change"], description="Approve selected refund requests"
    )
    def approve_refunds(self, request, queryset):

        if not (
            request.user.is_active
            and request.user.is_staff
            and self.has_change_permission(request)
        ):
            raise PermissionDenied

        approved = 0
        skipped = 0

        for refund_id in queryset.values_list(
            "pk",
            flat=True,
        ):

            try:
                approve_refund_request(
                    refund_id=refund_id,
                    admin_user=request.user,
                    note="Approved from Django Admin.",
                )
                approved += 1

            except GatewayError:
                skipped += 1

        self.message_user(
            request,
            f"{approved} approved, {skipped} skipped.",
            messages.WARNING if skipped else messages.SUCCESS,
        )

    @admin.action(permissions=["change"], description="Reject selected refund requests")
    def reject_refunds(self, request, queryset):

        if not (
            request.user.is_active
            and request.user.is_staff
            and self.has_change_permission(request)
        ):
            raise PermissionDenied

        rejected = 0
        skipped = 0

        for refund_id in queryset.values_list(
            "pk",
            flat=True,
        ):

            try:
                reject_refund_request(
                    refund_id=refund_id,
                    admin_user=request.user,
                    note="Rejected by administrator.",
                )
                rejected += 1

            except GatewayError:
                skipped += 1

        self.message_user(
            request,
            f"{rejected} rejected, {skipped} skipped.",
            messages.WARNING if skipped else messages.SUCCESS,
        )

    @admin.action(
        permissions=["change"],
        description="Process approved refunds through SSLCommerz",
    )
    def process_refunds(self, request, queryset):

        if not (
            request.user.is_active
            and request.user.is_staff
            and self.has_change_permission(request)
        ):
            raise PermissionDenied

        if queryset.count() != 1:

            self.message_user(
                request,
                "Select exactly one approved refund.",
                messages.ERROR,
            )
            return

        refund_id = queryset.first().pk

        try:
            refund = process_approved_refund(
                refund_id=refund_id,
                admin_user=request.user,
            )

            self.message_user(
                request,
                f"Refund #{refund.pk}: {refund.status}.",
                messages.SUCCESS,
            )

        except GatewayError as exc:

            self.message_user(
                request,
                (
                    f"{exc} Do not retry automatically. "
                    "Check the SSLCommerz merchant dashboard."
                ),
                messages.ERROR,
            )

    @admin.action(
        permissions=["change"], description="Check selected refunds with SSLCommerz"
    )
    def check_refunds(self, request, queryset):

        if not (
            request.user.is_active
            and request.user.is_staff
            and self.has_change_permission(request)
        ):
            raise PermissionDenied

        checked = 0
        skipped = 0

        for refund in queryset.select_related("payment"):

            try:
                check_gateway_refund(refund)
                checked += 1

            except GatewayError:
                skipped += 1

        self.message_user(
            request,
            f"{checked} checked, {skipped} require manual review.",
            messages.WARNING if skipped else messages.SUCCESS,
        )
