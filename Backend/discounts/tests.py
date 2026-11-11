"""The legacy discount API must honor the console's model permissions."""

from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from rest_framework.test import APITestCase

from .models import Discount


class DiscountAuthorizationTests(APITestCase):
    root = "/api/v1/discounts/discounts/"

    def setUp(self):
        self.staff = get_user_model().objects.create_user(
            "discount-staff@example.test", is_staff=True
        )
        self.discount = Discount.objects.create(
            name="Example promotion",
            discount_type="promo",
            code="EXAMPLE",
            value_type="percentage",
            value=10,
        )

    def authenticate(self, *codenames):
        self.staff.user_permissions.set(
            Permission.objects.filter(
                content_type__app_label="discounts", codename__in=codenames
            )
        )
        self.staff = get_user_model().objects.get(pk=self.staff.pk)
        self.client.force_authenticate(self.staff)

    def test_unprivileged_staff_cannot_read_or_change_discounts(self):
        self.authenticate()
        self.assertEqual(self.client.get(self.root).status_code, 403)
        self.assertEqual(
            self.client.patch(
                f"{self.root}{self.discount.pk}/", {"is_active": False}
            ).status_code,
            403,
        )
        self.assertEqual(
            self.client.delete(f"{self.root}{self.discount.pk}/").status_code, 403
        )

    def test_view_permission_does_not_allow_changes(self):
        self.authenticate("view_discount")
        self.assertEqual(self.client.get(self.root).status_code, 200)
        self.assertEqual(
            self.client.patch(
                f"{self.root}{self.discount.pk}/", {"is_active": False}
            ).status_code,
            403,
        )

    def test_changes_require_the_matching_model_permission(self):
        self.authenticate("view_discount", "change_discount")
        response = self.client.patch(
            f"{self.root}{self.discount.pk}/", {"is_active": False}
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.discount.refresh_from_db()
        self.assertFalse(self.discount.is_active)
        self.assertEqual(
            self.client.delete(f"{self.root}{self.discount.pk}/").status_code, 403
        )

    def test_customer_with_model_permission_is_not_staff(self):
        self.authenticate("view_discount")
        self.staff.is_staff = False
        self.staff.save(update_fields=["is_staff"])
        self.client.force_authenticate(self.staff)
        self.assertEqual(self.client.get(self.root).status_code, 403)

    def test_customer_discount_validation_is_preserved(self):
        user = get_user_model().objects.create_user("buyer@example.test")
        self.client.force_authenticate(user)
        response = self.client.post(
            self.root + "validate/", {"code": "EXAMPLE", "order_amount": "100.00"}
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data["discount_amount"], "10.00")
