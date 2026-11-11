from unittest.mock import patch

from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import AccessToken

User = get_user_model()


class AccountIdentityProtectionTests(APITestCase):
    def test_registration_never_replaces_existing_accounts(self):
        for flags in (
            {"is_staff": True, "is_superuser": True},
            {"is_staff": True},
            {},
        ):
            with self.subTest(flags=flags):
                user = User.objects.create_user(
                    f"identity-{User.objects.count()}@example.test",
                    "Original-password!821",
                    is_email_verified=False,
                    **flags,
                )
                for password_confirmation in (
                    "Different-password",
                    "Secure-password!821",
                ):
                    response = self.client.post(
                        "/api/v1/accounts/register/",
                        {
                            "email": user.email,
                            "phone": "01700000000",
                            "password": "Secure-password!821",
                            "password2": password_confirmation,
                        },
                    )
                    self.assertEqual(response.status_code, 400)
                    user.refresh_from_db()
                    self.assertTrue(user.check_password("Original-password!821"))

    @patch("accounts.views.send_verification_otp")
    def test_new_registration_still_creates_customer(self, send_otp):
        response = self.client.post(
            "/api/v1/accounts/register/",
            {
                "email": "new-customer@example.test",
                "phone": "01700000000",
                "password": "Secure-password!821",
                "password2": "Secure-password!821",
            },
        )
        self.assertEqual(response.status_code, 201, response.data)
        user = User.objects.get(email="new-customer@example.test")
        self.assertFalse(user.is_staff)
        self.assertTrue(user.check_password("Secure-password!821"))
        send_otp.assert_called_once_with(user)

    def test_staff_password_reset_revokes_previously_issued_token(self):
        staff = User.objects.create_user(
            "operator@example.test", "Original-password!821", is_staff=True
        )
        token = str(AccessToken.for_user(staff))
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
        self.assertEqual(
            self.client.get("/api/v1/admin-panel/workspace/").status_code, 200
        )
        staff.set_password("Replacement-password!821")
        staff.save(update_fields=["password"])
        self.assertEqual(
            self.client.get("/api/v1/admin-panel/workspace/").status_code, 401
        )
        replacement = str(AccessToken.for_user(staff))
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {replacement}")
        self.assertEqual(
            self.client.get("/api/v1/admin-panel/workspace/").status_code, 200
        )
