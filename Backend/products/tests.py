"""Review moderation requires change access, including original admin actions."""

from unittest.mock import Mock

from django.contrib import admin
from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.core.exceptions import PermissionDenied
from django.test import RequestFactory, TestCase

from .models import ProductReview


class ReviewAdminAuthorizationTests(TestCase):
    def setUp(self):
        self.staff = get_user_model().objects.create_user(
            "review-viewer@example.test", is_staff=True
        )
        self.staff.user_permissions.add(
            Permission.objects.get(
                codename="view_productreview", content_type__app_label="products"
            )
        )
        self.request = RequestFactory().post("/admin/products/productreview/")
        self.request.user = self.staff
        self.model_admin = admin.site._registry[ProductReview]

    def test_moderation_actions_are_hidden_for_view_only_staff(self):
        actions = self.model_admin.get_actions(self.request)
        self.assertNotIn("approve_reviews", actions)
        self.assertNotIn("reject_reviews", actions)

    def test_direct_moderation_action_does_not_mutate_forbidden_queryset(self):
        queryset = Mock()
        for name in ("approve_reviews", "reject_reviews"):
            with self.assertRaises(PermissionDenied):
                getattr(self.model_admin, name)(self.request, queryset)
        queryset.update.assert_not_called()

    def test_change_permission_exposes_moderation_actions(self):
        self.staff.user_permissions.add(
            Permission.objects.get(
                codename="change_productreview", content_type__app_label="products"
            )
        )
        self.request.user = get_user_model().objects.get(pk=self.staff.pk)
        self.assertIn("approve_reviews", self.model_admin.get_actions(self.request))
