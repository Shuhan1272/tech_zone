from urllib.parse import urlsplit
from uuid import uuid4

from django.db import transaction
from django.shortcuts import get_object_or_404, redirect

from rest_framework import generics, status
from rest_framework.exceptions import ValidationError
from rest_framework.pagination import PageNumberPagination
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import (
    AllowAny,
    BasePermission,
    IsAuthenticated,
    SAFE_METHODS,
)
from rest_framework.response import Response
from rest_framework.views import APIView

from order.models import Order
from .models import Payment, PaymentRefund
from .serializers import PaymentInitiateSerializer, PaymentSerializer
from .services import (
    GatewayError,
    create_gateway_session,
    confirm_gateway_payment,
    reconcile_gateway_payment,
    frontend_result_url,
    request_full_refund,
    approve_refund_request,
    reject_refund_request,
    process_approved_refund,
    check_gateway_refund,
)


class RefundStaffPermission(BasePermission):
    """Apply the same model permissions as the operations console."""

    def has_permission(self, request, view):
        user = request.user
        if not (user.is_authenticated and user.is_active and user.is_staff):
            return False
        required = ["payments.view_paymentrefund"]
        if request.method not in SAFE_METHODS:
            required.append("payments.change_paymentrefund")
        return user.has_perms(required)


# =========================================================
# PAGINATION
# =========================================================


class PaymentPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100


# =========================================================
# ERROR RESPONSES
# =========================================================


def gateway_error_response(error):
    return Response(
        {"detail": str(error)},
        status=status.HTTP_503_SERVICE_UNAVAILABLE,
    )


def refund_error_response(error):
    return Response(
        {"detail": str(error)},
        status=status.HTTP_400_BAD_REQUEST,
    )


# =========================================================
# REFUND RESPONSE DATA
# =========================================================


def refund_response_data(refund):
    return {
        "id": refund.pk,
        "payment_id": refund.payment_id,
        "order_id": refund.payment.order_id,
        "amount": str(refund.amount),
        "currency": refund.payment.currency,
        "reason": refund.reason,
        "status": refund.status,
        "status_display": refund.get_status_display(),
        "refund_reference_id": refund.refund_reference_id,
        "admin_note": refund.admin_note,
        "reviewed_at": (refund.reviewed_at.isoformat() if refund.reviewed_at else None),
        "processing_started_at": (
            refund.processing_started_at.isoformat()
            if refund.processing_started_at
            else None
        ),
        "completed_at": (
            refund.completed_at.isoformat() if refund.completed_at else None
        ),
        "failure_reason": refund.failure_reason,
        "created_at": refund.created_at.isoformat(),
        "updated_at": refund.updated_at.isoformat(),
    }


# =========================================================
# PAYMENT INITIATION
# =========================================================


class PaymentInitiateView(generics.GenericAPIView):
    serializer_class = PaymentInitiateSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        with transaction.atomic():
            order = get_object_or_404(
                Order.objects.select_for_update(),
                pk=serializer.validated_data["order_id"],
                user=request.user,
            )

            if order.payment_method != "sslcommerz":
                raise ValidationError(
                    {
                        "payment_method": "Online payment is not available for Cash on Delivery orders."
                    }
                )

            # Order must still be active.
            if order.status not in ("pending", "confirmed"):
                raise ValidationError(
                    {"order": "This order is not eligible for payment."}
                )

            # Never initiate another payment for an already
            # paid or refunded order.
            if order.payment_status in ("paid", "refunded"):
                return Response(
                    {
                        "detail": (
                            "This order has already been paid."
                            if order.payment_status == "paid"
                            else "This order has already been refunded."
                        ),
                        "order_id": order.pk,
                        "payment_status": order.payment_status,
                    },
                    status=status.HTTP_409_CONFLICT,
                )

            if order.total_amount <= 0:
                raise ValidationError({"order": "Invalid order amount."})

            # Check existing completed payments as an extra
            # safeguard against duplicate charges.
            paid_payment = (
                Payment.objects.filter(order=order, status="paid")
                .order_by("-id")
                .first()
            )

            if paid_payment:
                return Response(
                    {
                        "detail": (
                            "A completed payment already exists "
                            "for this order. Please refresh "
                            "the order status."
                        ),
                        "order_id": order.pk,
                        "payment_status": "paid",
                        "payment_id": paid_payment.pk,
                        "transaction_id": paid_payment.transaction_id,
                    },
                    status=status.HTTP_409_CONFLICT,
                )

            # Reuse a pending gateway session when possible.
            existing = (
                Payment.objects.filter(
                    order=order,
                    status__in=[
                        "initiating",
                        "pending",
                        "review",
                    ],
                )
                .order_by("-id")
                .first()
            )

            if existing:
                if existing.status == "pending" and existing.gateway_url:
                    return Response(
                        {
                            "transaction_id": existing.transaction_id,
                            "payment_url": existing.gateway_url,
                            "amount": str(existing.amount),
                            "currency": existing.currency,
                            "payment_status": "pending",
                        }
                    )

                raise ValidationError(
                    {
                        "payment": (
                            "A payment is already being processed. "
                            "Verify its status before retrying."
                        )
                    }
                )

            payment = Payment.objects.create(
                order=order,
                transaction_id=uuid4().hex[:30],
                amount=order.total_amount,
                currency="BDT",
                status="initiating",
            )

        # External gateway request happens outside
        # the database transaction.
        try:
            result = create_gateway_session(payment)

            gateway_url = result["GatewayPageURL"]
            parsed = urlsplit(gateway_url)

            if (
                parsed.scheme != "https"
                or not parsed.hostname
                or not (
                    parsed.hostname == "sslcommerz.com"
                    or parsed.hostname.endswith(".sslcommerz.com")
                )
            ):
                raise GatewayError("SSLCommerz returned an invalid payment URL.")

        except GatewayError as exc:
            Payment.objects.filter(
                pk=payment.pk,
                status="initiating",
            ).update(
                status="review",
                review_reason="initiation_uncertain",
            )

            return gateway_error_response(exc)

        updated = Payment.objects.filter(
            pk=payment.pk,
            status="initiating",
        ).update(
            gateway_session_key=str(result.get("sessionkey") or ""),
            gateway_url=gateway_url,
            status="pending",
        )

        if not updated:
            payment.refresh_from_db()

            if payment.status == "paid":
                return Response(
                    {
                        "transaction_id": payment.transaction_id,
                        "payment_status": "paid",
                        "amount": str(payment.amount),
                        "currency": payment.currency,
                    }
                )

            return Response(
                {
                    "detail": (
                        "Payment status changed during initiation. "
                        "Verify the transaction."
                    )
                },
                status=status.HTTP_409_CONFLICT,
            )

        return Response(
            {
                "transaction_id": payment.transaction_id,
                "payment_url": gateway_url,
                "amount": str(payment.amount),
                "currency": payment.currency,
                "payment_status": "pending",
            },
            status=status.HTTP_201_CREATED,
        )


# =========================================================
# MY PAYMENT HISTORY
# =========================================================


class MyPaymentListView(generics.ListAPIView):
    serializer_class = PaymentSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = PaymentPagination

    def get_queryset(self):
        return (
            Payment.objects.filter(order__user=self.request.user)
            .select_related("order", "refund")
            .order_by("-created_at")
        )


# =========================================================
# PAYMENT DETAILS
# =========================================================


class PaymentDetailView(generics.RetrieveAPIView):
    serializer_class = PaymentSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Payment.objects.filter(order__user=self.request.user).select_related(
            "order", "refund"
        )


# =========================================================
# VERIFY PAYMENT
# =========================================================


class PaymentVerifyView(generics.GenericAPIView):
    serializer_class = PaymentSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Payment.objects.filter(order__user=self.request.user)

    def post(self, request, pk):
        payment = self.get_object()

        try:
            payment = reconcile_gateway_payment(payment)
        except GatewayError as exc:
            return gateway_error_response(exc)

        return Response(PaymentSerializer(payment).data)


# =========================================================
# CUSTOMER REFUND REQUEST
# =========================================================


class RefundRequestView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        order_id = request.data.get("order_id")
        reason = request.data.get("reason", "")

        try:
            order_id = int(order_id)
        except (TypeError, ValueError):
            raise ValidationError({"order_id": "A valid order ID is required."})

        order = get_object_or_404(
            Order,
            pk=order_id,
            user=request.user,
        )

        if (
            order.payment_method != "sslcommerz"
            or order.payment_status != "paid"
            or order.status not in ("pending", "confirmed")
        ):
            raise ValidationError(
                {"order": ("This order is not eligible " "for a refund request.")}
            )

        payment = (
            Payment.objects.filter(
                order=order,
                status="paid",
            )
            .order_by("-created_at")
            .first()
        )

        if payment is None:
            raise ValidationError({"payment": "No completed online payment was found."})

        try:
            refund = request_full_refund(
                payment_id=payment.pk,
                reason=reason,
                user=request.user,
            )
        except GatewayError as exc:
            return refund_error_response(exc)

        refund = PaymentRefund.objects.select_related("payment").get(pk=refund.pk)

        return Response(
            {
                "message": "Your refund request has been submitted.",
                "refund": refund_response_data(refund),
            },
            status=status.HTTP_201_CREATED,
        )


# =========================================================
# CUSTOMER ORDER REFUND STATUS
# =========================================================


class OrderRefundStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, order_id):
        order = get_object_or_404(
            Order,
            pk=order_id,
            user=request.user,
        )

        refund = (
            PaymentRefund.objects.select_related("payment")
            .filter(payment__order=order)
            .order_by("-created_at")
            .first()
        )

        if refund is None:
            return Response(
                {
                    "has_refund": False,
                    "refund": None,
                }
            )

        return Response(
            {
                "has_refund": True,
                "refund": refund_response_data(refund),
            }
        )


# =========================================================
# STAFF REFUND LIST
# =========================================================


class AdminRefundListView(generics.ListAPIView):
    permission_classes = [RefundStaffPermission]
    pagination_class = PaymentPagination

    def get_queryset(self):
        queryset = PaymentRefund.objects.select_related(
            "payment",
            "payment__order",
            "reviewed_by",
        ).order_by("-created_at")

        refund_status = self.request.query_params.get("status")

        if refund_status:
            queryset = queryset.filter(status=refund_status)

        return queryset

    def list(self, request, *args, **kwargs):
        queryset = self.filter_queryset(self.get_queryset())

        page = self.paginate_queryset(queryset)

        if page is not None:
            data = [refund_response_data(refund) for refund in page]
            return self.get_paginated_response(data)

        return Response([refund_response_data(refund) for refund in queryset])


# =========================================================
# STAFF REFUND DETAILS
# =========================================================


class AdminRefundDetailView(APIView):
    permission_classes = [RefundStaffPermission]

    def get(self, request, pk):
        refund = get_object_or_404(
            PaymentRefund.objects.select_related(
                "payment",
                "payment__order",
                "reviewed_by",
            ),
            pk=pk,
        )

        return Response(refund_response_data(refund))


# =========================================================
# STAFF APPROVES REFUND
# =========================================================


class AdminRefundApproveView(APIView):
    permission_classes = [RefundStaffPermission]

    def post(self, request, pk):
        note = request.data.get("note", "")

        try:
            refund = approve_refund_request(
                refund_id=pk,
                admin_user=request.user,
                note=note,
            )
        except GatewayError as exc:
            return refund_error_response(exc)

        refund = PaymentRefund.objects.select_related("payment").get(pk=refund.pk)

        return Response(
            {
                "message": "Refund request approved.",
                "refund": refund_response_data(refund),
            }
        )


# =========================================================
# STAFF REJECTS REFUND
# =========================================================


class AdminRefundRejectView(APIView):
    permission_classes = [RefundStaffPermission]

    def post(self, request, pk):
        note = request.data.get("note", "")

        try:
            refund = reject_refund_request(
                refund_id=pk,
                admin_user=request.user,
                note=note,
            )
        except GatewayError as exc:
            return refund_error_response(exc)

        refund = PaymentRefund.objects.select_related("payment").get(pk=refund.pk)

        return Response(
            {
                "message": "Refund request rejected.",
                "refund": refund_response_data(refund),
            }
        )


# =========================================================
# STAFF PROCESSES APPROVED REFUND
# =========================================================


class AdminRefundProcessView(APIView):
    permission_classes = [RefundStaffPermission]

    def post(self, request, pk):
        try:
            refund = process_approved_refund(
                refund_id=pk,
                admin_user=request.user,
            )
        except GatewayError as exc:
            return gateway_error_response(exc)

        refund = PaymentRefund.objects.select_related("payment").get(pk=refund.pk)

        return Response(
            {
                "message": ("Refund processing request " "has been submitted."),
                "refund": refund_response_data(refund),
            }
        )


# =========================================================
# STAFF CHECKS REFUND STATUS
# =========================================================


class AdminRefundCheckView(APIView):
    permission_classes = [RefundStaffPermission]

    def post(self, request, pk):
        refund = get_object_or_404(
            PaymentRefund.objects.select_related("payment"),
            pk=pk,
        )

        try:
            refund = check_gateway_refund(refund)
        except GatewayError as exc:
            return gateway_error_response(exc)

        refund = PaymentRefund.objects.select_related("payment").get(pk=refund.pk)

        return Response(
            {
                "message": "Refund status checked.",
                "refund": refund_response_data(refund),
            }
        )


# =========================================================
# GATEWAY CALLBACK BASE
# =========================================================


class GatewayCallbackView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    parser_classes = [
        FormParser,
        MultiPartParser,
        JSONParser,
    ]


# =========================================================
# PAYMENT SUCCESS CALLBACK
# =========================================================


class PaymentSuccessView(GatewayCallbackView):

    def handle(self, data):
        transaction_id = data.get("tran_id", "")
        validation_id = data.get("val_id", "")

        result = "pending"

        if transaction_id and validation_id:
            try:
                payment = confirm_gateway_payment(
                    transaction_id,
                    validation_id,
                )

                if payment.status == "paid":
                    result = "success"

                elif payment.status == "review":
                    result = "review"

            except GatewayError:
                pass

        return redirect(
            frontend_result_url(
                transaction_id,
                result,
            )
        )

    def post(self, request):
        return self.handle(request.data)

    def get(self, request):
        return self.handle(request.query_params)


# =========================================================
# FAILED / CANCELLED CALLBACKS
# =========================================================


class PaymentResultView(GatewayCallbackView):
    result = "failed"

    def post(self, request):
        return redirect(
            frontend_result_url(
                request.data.get("tran_id", ""),
                self.result,
            )
        )

    def get(self, request):
        return redirect(
            frontend_result_url(
                request.query_params.get("tran_id", ""),
                self.result,
            )
        )


class PaymentFailView(PaymentResultView):
    result = "failed"


class PaymentCancelView(PaymentResultView):
    result = "cancelled"


# =========================================================
# IPN CALLBACK
# =========================================================


class PaymentIPNView(GatewayCallbackView):

    def post(self, request):
        data = request.data

        if data.get("status") not in (
            "VALID",
            "VALIDATED",
        ):
            return Response({"message": "Notification received."})

        if not data.get("tran_id") or not data.get("val_id"):
            return Response(
                {"detail": "Missing transaction information."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            payment = confirm_gateway_payment(
                data["tran_id"],
                data["val_id"],
            )
        except GatewayError as exc:
            return gateway_error_response(exc)

        return Response(
            {
                "message": "Payment notification processed.",
                "payment_status": payment.status,
            }
        )
