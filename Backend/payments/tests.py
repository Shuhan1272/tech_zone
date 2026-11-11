"""Authorization regressions for payment APIs and the original Django admin."""

from unittest.mock import patch

from django.contrib import admin
from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.core.exceptions import PermissionDenied
from django.test import RequestFactory
from rest_framework.test import APITestCase

from order.models import Order
from .models import Payment, PaymentRefund


class RefundAuthorizationTests(APITestCase):
    root = "/api/v1/payments/"

    def setUp(self):
        users = get_user_model().objects
        self.customer = users.create_user("customer@example.test", "ExamplePassword!85")
        self.staff = users.create_user("staff@example.test", is_staff=True)
        self.order = Order.objects.create(
            user=self.customer,
            shipping_name="Example customer",
            subtotal=100,
            total_amount=100,
            status="pending",
            payment_method="sslcommerz",
            payment_status="paid",
        )
        self.payment = Payment.objects.create(
            order=self.order,
            transaction_id="test-authorization-payment",
            bank_transaction_id="test-bank-transaction",
            amount=100,
            status="paid",
        )
        self.refund = PaymentRefund.objects.create(
            payment=self.payment,
            amount=100,
            reason="Customer requested cancellation",
        )

    def authenticate_staff(self, *codenames):
        self.staff.user_permissions.set(
            Permission.objects.filter(
                content_type__app_label="payments", codename__in=codenames
            )
        )
        # Fetch again because Django caches computed permissions on the instance.
        self.staff = get_user_model().objects.get(pk=self.staff.pk)
        self.client.force_authenticate(self.staff)

    def test_staff_without_refund_permissions_cannot_read_or_mutate(self):
        self.authenticate_staff()
        self.assertEqual(self.client.get(self.root + "refunds/admin/").status_code, 403)
        self.assertEqual(
            self.client.get(self.root + f"refunds/admin/{self.refund.pk}/").status_code,
            403,
        )
        with patch("payments.views.process_approved_refund") as gateway_call:
            response = self.client.post(
                self.root + f"refunds/admin/{self.refund.pk}/process/"
            )
        self.assertEqual(response.status_code, 403)
        gateway_call.assert_not_called()

    def test_refund_viewer_cannot_approve_or_submit_to_gateway(self):
        self.authenticate_staff("view_paymentrefund")
        self.assertEqual(self.client.get(self.root + "refunds/admin/").status_code, 200)
        for action in ("approve", "reject", "process", "check"):
            response = self.client.post(
                self.root + f"refunds/admin/{self.refund.pk}/{action}/",
                {"note": "Review"},
            )
            self.assertEqual(response.status_code, 403, action)
        self.refund.refresh_from_db()
        self.assertEqual(self.refund.status, "requested")

    def test_authorized_reviewer_can_approve_without_gateway_submission(self):
        self.authenticate_staff("view_paymentrefund", "change_paymentrefund")
        with patch("payments.views.process_approved_refund") as gateway_call:
            response = self.client.post(
                self.root + f"refunds/admin/{self.refund.pk}/approve/",
                {"note": "Reviewed"},
            )
        self.assertEqual(response.status_code, 200, response.data)
        gateway_call.assert_not_called()
        self.refund.refresh_from_db()
        self.assertEqual(self.refund.status, "approved")
        self.assertEqual(self.refund.reviewed_by_id, self.staff.pk)

    def test_inactive_staff_is_denied_even_when_force_authenticated(self):
        self.authenticate_staff("view_paymentrefund", "change_paymentrefund")
        self.staff.is_active = False
        self.staff.save(update_fields=["is_active"])
        self.client.force_authenticate(self.staff)
        self.assertEqual(self.client.get(self.root + "refunds/admin/").status_code, 403)

    def test_customer_can_read_own_refund_but_not_staff_endpoint(self):
        self.client.force_authenticate(self.customer)
        response = self.client.get(self.root + f"refunds/order/{self.order.pk}/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["refund"]["id"], self.refund.pk)
        self.assertEqual(self.client.get(self.root + "refunds/admin/").status_code, 403)
        other = get_user_model().objects.create_user("other@example.test")
        self.client.force_authenticate(other)
        self.assertEqual(
            self.client.get(self.root + f"refunds/order/{self.order.pk}/").status_code,
            404,
        )

    def test_customer_can_still_request_own_refund(self):
        self.refund.delete()
        self.client.force_authenticate(self.customer)
        response = self.client.post(
            self.root + "refunds/request/",
            {
                "order_id": self.order.pk,
                "reason": "Please cancel my order",
            },
        )
        self.assertEqual(response.status_code, 201, response.data)
        self.assertTrue(
            PaymentRefund.objects.filter(
                payment=self.payment, status="requested"
            ).exists()
        )

    def test_django_admin_view_only_staff_cannot_use_bulk_actions_or_custom_url(self):
        self.authenticate_staff("view_payment", "view_paymentrefund")
        request = RequestFactory().post("/admin/")
        request.user = self.staff
        payment_admin = admin.site._registry[Payment]
        refund_admin = admin.site._registry[PaymentRefund]
        self.assertNotIn("verify_payments", payment_admin.get_actions(request))
        self.assertNotIn("approve_refunds", refund_admin.get_actions(request))
        with patch("payments.admin.reconcile_gateway_payment") as gateway_call:
            with self.assertRaises(PermissionDenied):
                payment_admin.verify_payments(request, Payment.objects.all())
        gateway_call.assert_not_called()
        with self.assertRaises(PermissionDenied):
            refund_admin.manage_refund_view(request, self.refund.pk, "approve")

    def test_django_admin_refund_change_permission_is_model_specific(self):
        self.authenticate_staff("view_paymentrefund", "change_paymentrefund")
        request = RequestFactory().get("/admin/")
        request.user = self.staff
        refund_admin = admin.site._registry[PaymentRefund]
        self.assertTrue(refund_admin.has_change_permission(request, self.refund))
        self.assertIn("approve_refunds", refund_admin.get_actions(request))
        self.assertFalse(
            admin.site._registry[Payment].has_change_permission(request, self.payment)
        )
