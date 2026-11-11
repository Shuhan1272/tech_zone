"""View-only access must never authorize order transitions in Django admin."""

from unittest.mock import patch

from django.contrib import admin
from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.core.exceptions import PermissionDenied
from django.test import RequestFactory, TestCase

from .models import Order


class OrderAdminAuthorizationTests(TestCase):
    def setUp(self):
        self.staff = get_user_model().objects.create_user(
            "order-viewer@example.test", is_staff=True
        )
        self.staff.user_permissions.add(
            Permission.objects.get(
                codename="view_order", content_type__app_label="order"
            )
        )
        self.request = RequestFactory().post("/admin/order/order/")
        self.request.user = self.staff
        self.model_admin = admin.site._registry[Order]

    def test_order_actions_are_hidden_from_view_only_staff(self):
        actions = self.model_admin.get_actions(self.request)
        for name in (
            "confirm_orders",
            "ship_orders",
            "deliver_orders",
            "cancel_orders",
            "confirm_cod_payments",
        ):
            self.assertNotIn(name, actions)

    def test_direct_bulk_action_is_denied_before_status_service(self):
        with patch("order.admin.change_order_status") as change:
            with self.assertRaises(PermissionDenied):
                self.model_admin.confirm_orders(self.request, Order.objects.all())
        change.assert_not_called()

    def test_change_permission_exposes_order_actions(self):
        self.staff.user_permissions.add(
            Permission.objects.get(
                codename="change_order", content_type__app_label="order"
            )
        )
        self.request.user = get_user_model().objects.get(pk=self.staff.pk)
        self.assertIn("confirm_orders", self.model_admin.get_actions(self.request))
