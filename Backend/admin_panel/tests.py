from decimal import Decimal
from django.contrib.auth.models import Permission
from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase
from accounts.serializers import RegisterSerializer
from order.models import Order
from products.models import Color
from .resources import resources


class ConsoleTests(APITestCase):
    root = "/api/v1/admin-panel/"

    @classmethod
    def setUpTestData(cls):
        cls.owner = get_user_model().objects.create_superuser(
            "owner@example.test", "s8DFI1-YZq!"
        )
        cls.customer = get_user_model().objects.create_user("buyer@example.test")
        cls.operator = get_user_model().objects.create_user(
            "staff@example.test", is_staff=True
        )
        cls.order = Order.objects.create(
            user=cls.customer,
            shipping_name="Buyer",
            total_amount=125,
            subtotal=125,
            payment_method="cod",
            status="pending",
            payment_status="pending",
        )

    def test_access_controls(self):
        self.assertEqual(self.client.get(self.root + "workspace/").status_code, 401)
        for user in (self.customer, self.operator):
            self.client.force_authenticate(user)
            self.assertEqual(
                self.client.get(self.root + "resources/orders/").status_code, 403
            )
        self.operator.user_permissions.add(
            Permission.objects.get(
                codename="view_order", content_type__app_label="order"
            )
        )
        self.client.force_authenticate(
            get_user_model().objects.get(pk=self.operator.pk)
        )
        self.assertEqual(
            self.client.get(self.root + "resources/orders/").status_code, 200
        )
        self.assertEqual(
            self.client.post(
                self.root + f"resources/orders/{self.order.pk}/action/",
                {"action": "confirmed"},
            ).status_code,
            403,
        )
        self.assertEqual(
            self.client.get(self.root + "resources/team/").status_code, 403
        )

    def test_resource_lists_and_creation_forms(self):
        self.client.force_authenticate(self.owner)
        for key, resource in resources.items():
            with self.subTest(resource=key):
                path = self.root + f"resources/{key}/"
                self.assertEqual(self.client.get(path).status_code, 200)
                if resource.create:
                    self.assertTrue(self.client.get(path + "new/").data["form"])

    def test_customer_registration_cannot_replace_unverified_staff(self):
        serializer = RegisterSerializer(
            data={
                "email": self.owner.email,
                "phone": "0123456789",
                "password": "Example!pass123",
                "password2": "Example!pass123",
            }
        )
        self.assertFalse(serializer.is_valid())
        self.assertTrue(get_user_model().objects.filter(pk=self.owner.pk).exists())

    def test_catalog_rejects_stale_edits(self):
        self.client.force_authenticate(self.owner)
        path = self.root + "resources/colors/"
        data = {"name": "Jade", "hex_code": "#00AA88", "is_active": "on"}
        pk = self.client.post(path + "new/", data).data["id"]
        url = f"{path}{pk}/"
        stamp = self.client.get(url).data["version"]
        Color.objects.filter(pk=pk).update(name="Forest")
        self.assertEqual(
            self.client.post(url, data, HTTP_X_RECORD_VERSION=stamp).status_code, 409
        )
        self.assertEqual(Color.objects.get(pk=pk).name, "Forest")

    def test_cod_workflow_and_paid_statistics(self):
        self.client.force_authenticate(self.owner)
        url = self.root + f"resources/orders/{self.order.pk}/action/"
        self.assertEqual(
            self.client.post(url, {"action": "collect_cod"}).status_code, 400
        )
        for action in ("confirmed", "shipped", "delivered", "collect_cod"):
            self.assertEqual(self.client.post(url, {"action": action}).status_code, 200)
        self.assertEqual(
            self.client.post(url, {"action": "collect_cod"}).status_code, 400
        )
        report = self.client.get(self.root + "overview/?days=7").data
        self.assertEqual(report["revenue"], Decimal("125"))
        self.assertEqual(len(report["series"]), 7)

    def test_staff_provisioning_hashes_password(self):
        self.client.force_authenticate(self.owner)
        response = self.client.post(
            self.root + "resources/team/new/",
            {
                "email": "operator@example.test",
                "phone": "0123456789",
                "is_active": "on",
                "new_password": "Tm8!hsX42yR",
            },
        )
        self.assertEqual(response.status_code, 200, response.data)
        staff = get_user_model().objects.get(pk=response.data["id"])
        self.assertTrue(staff.is_staff and staff.check_password("Tm8!hsX42yR"))
        self.assertFalse(staff.is_superuser)


class DeletionTests(APITestCase):
    base = "/api/v1/admin-panel/resources/"

    def setUp(self):
        from products.models import Category

        self.owner = get_user_model().objects.create_superuser(
            "owner@example.test", "example-password"
        )
        self.client.force_authenticate(self.owner)
        self.category = Category.objects.create(name="Storage")
        self.url = f"{self.base}categories/{self.category.pk}/"

    def headers(self, url):
        record = self.client.get(url).data
        return {
            "HTTP_X_RECORD_VERSION": record["version"],
            "HTTP_X_DELETION_TOKEN": record["deletion"]["token"],
        }

    def test_empty_category_can_be_deleted(self):
        self.assertEqual(
            self.client.delete(self.url, **self.headers(self.url)).status_code, 204
        )
        self.assertEqual(self.client.get(self.url).status_code, 404)

    def test_protected_product_in_descendant_blocks_entire_deletion(self):
        from products.models import Category, Product

        child = Category.objects.create(name="SSD", parent=self.category)
        product = Product.objects.create(name="Drive", category=child)
        self.assertTrue(self.client.get(self.url).data["deletion"]["blockers"])
        self.assertEqual(
            self.client.delete(self.url, **self.headers(self.url)).status_code, 409
        )
        for record in (self.category, child, product):
            record.refresh_from_db()

    def test_new_child_requires_new_preview(self):
        from products.models import Category

        old_preview = self.headers(self.url)
        child = Category.objects.create(name="SSD", parent=self.category)
        self.assertEqual(self.client.delete(self.url, **old_preview).status_code, 409)
        child.refresh_from_db()
        self.assertEqual(
            self.client.delete(self.url, **self.headers(self.url)).status_code, 204
        )
        self.assertFalse(Category.objects.exists())

    def test_view_permission_alone_cannot_delete(self):
        staff = get_user_model().objects.create_user(
            "viewer@example.test", is_staff=True
        )
        staff.user_permissions.add(Permission.objects.get(codename="view_category"))
        self.client.force_authenticate(staff)
        self.assertFalse(self.client.get(self.url).data["delete"])
        self.assertEqual(self.client.delete(self.url).status_code, 403)

    def test_cascade_requires_permission_on_each_model(self):
        from products.models import Category
        from pc_builder.models import PCComponentCategory

        mapping = PCComponentCategory.objects.create(
            category=self.category, component_type="storage"
        )
        staff = get_user_model().objects.create_user(
            "catalog@example.test", is_staff=True
        )
        staff.user_permissions.add(
            *Permission.objects.filter(
                codename__in=["view_category", "delete_category"]
            )
        )
        self.client.force_authenticate(staff)
        self.assertTrue(self.client.get(self.url).data["deletion"]["blockers"])
        self.assertEqual(
            self.client.delete(self.url, **self.headers(self.url)).status_code, 409
        )
        mapping.refresh_from_db()
        self.assertTrue(Category.objects.filter(pk=self.category.pk).exists())


class StaffAndRoleTests(APITestCase):
    root = "/api/v1/admin-panel/"

    def setUp(self):
        from django.contrib.auth.models import Group

        self.owner = get_user_model().objects.create_superuser(
            "owner@example.test", "A9!sY2-kP8vQ"
        )
        self.staff = get_user_model().objects.create_user(
            "operator@example.test", "A9!sY2-kP8vQ", is_staff=True, role="admin"
        )
        self.role = Group.objects.create(name="Catalog viewer")
        self.view_color = Permission.objects.get(
            content_type__app_label="products", codename="view_color"
        )
        self.role.permissions.add(self.view_color)
        self.client.force_authenticate(self.owner)

    def staff_url(self):
        return self.root + f"resources/team/{self.staff.pk}/"

    def test_permission_catalog_excludes_system_administration(self):
        result = self.client.get(self.root + "permissions/")
        self.assertEqual(result.status_code, 200)
        entries = [
            entry for group in result.data["groups"] for entry in group["permissions"]
        ]
        self.assertIn("products.view_color", [entry["codename"] for entry in entries])
        self.assertNotIn("auth.change_group", [entry["codename"] for entry in entries])
        self.assertNotIn("accounts.add_user", [entry["codename"] for entry in entries])
        self.client.force_authenticate(self.staff)
        self.assertEqual(self.client.get(self.root + "permissions/").status_code, 403)

    def test_owner_can_create_role_and_assign_it_to_staff(self):
        result = self.client.post(
            self.root + "resources/roles/new/",
            {"name": "Inventory viewer", "permissions": [self.view_color.pk]},
        )
        self.assertEqual(result.status_code, 200, result.data)
        stamp = self.client.get(self.staff_url()).data["version"]
        result = self.client.post(
            self.staff_url(),
            {
                "email": self.staff.email,
                "phone": "0123456789",
                "groups": [result.data["id"]],
                "is_active": "on",
                "is_superuser": "on",
            },
            HTTP_X_RECORD_VERSION=stamp,
        )
        self.assertEqual(result.status_code, 200, result.data)
        staff = get_user_model().objects.get(pk=self.staff.pk)
        self.assertFalse(staff.is_superuser)
        self.assertTrue(staff.check_password("A9!sY2-kP8vQ"))
        self.client.force_authenticate(staff)
        self.assertEqual(
            self.client.get(self.root + "resources/colors/").status_code, 200
        )
        self.assertEqual(
            self.client.get(self.root + "resources/roles/").status_code, 403
        )
        self.assertEqual(
            self.client.get(self.root + "resources/colors/new/").status_code, 403
        )

    def test_new_role_cannot_assign_system_permissions(self):
        permission = Permission.objects.get(
            content_type__app_label="auth", codename="change_group"
        )
        response = self.client.post(
            self.root + "resources/roles/new/",
            {"name": "System administrator", "permissions": [permission.pk]},
        )
        self.assertEqual(response.status_code, 400)

    def test_role_membership_and_status_filter(self):
        self.staff.groups.add(self.role)
        response = self.client.get(
            self.root
            + f"resources/team/?group={self.role.pk}&is_active=1&ordering=email"
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual([row["id"] for row in response.data["rows"]], [self.staff.pk])
        self.assertEqual(response.data["summary"]["active"], 1)
        self.assertEqual(response.data["rows"][0]["groups"], self.role.name)
        self.assertEqual(response.data["ordering"], "email")
        self.assertEqual(
            self.client.get(self.root + "resources/team/?ordering=password").data[
                "ordering"
            ],
            "-id",
        )

    def test_staff_status_action_needs_current_version(self):
        url = self.staff_url() + "action/"
        self.assertEqual(
            self.client.post(url, {"action": "deactivate_staff"}).status_code, 409
        )
        stamp = self.client.get(self.staff_url()).data["version"]
        response = self.client.post(
            url, {"action": "deactivate_staff"}, HTTP_X_RECORD_VERSION=stamp
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.staff.refresh_from_db()
        self.assertFalse(self.staff.is_active)
        self.assertEqual(
            self.client.post(
                url, {"action": "activate_staff"}, HTTP_X_RECORD_VERSION=stamp
            ).status_code,
            409,
        )
        stamp = self.client.get(self.staff_url()).data["version"]
        self.assertEqual(
            self.client.post(
                url, {"action": "activate_staff"}, HTTP_X_RECORD_VERSION=stamp
            ).status_code,
            200,
        )

    def test_suspended_staff_token_loses_access_immediately(self):
        self.client.force_authenticate(user=None)
        result = self.client.post(
            self.root + "login/",
            {"email": self.staff.email, "password": "A9!sY2-kP8vQ"},
        )
        self.assertEqual(result.status_code, 200)
        self.client.credentials(HTTP_AUTHORIZATION="Bearer " + result.data["token"])
        self.assertEqual(self.client.get(self.root + "workspace/").status_code, 200)
        get_user_model().objects.filter(pk=self.staff.pk).update(is_active=False)
        self.assertEqual(self.client.get(self.root + "workspace/").status_code, 401)
        self.client.credentials()
        self.assertEqual(
            self.client.post(
                self.root + "login/",
                {"email": self.staff.email, "password": "A9!sY2-kP8vQ"},
            ).status_code,
            403,
        )

    def test_role_permission_changes_apply_to_existing_tokens(self):
        from rest_framework.test import APIClient

        self.staff.groups.add(self.role)
        staff_client = APIClient()
        result = staff_client.post(
            self.root + "login/",
            {"email": self.staff.email, "password": "A9!sY2-kP8vQ"},
        )
        staff_client.credentials(HTTP_AUTHORIZATION="Bearer " + result.data["token"])
        url = self.root + "resources/colors/"
        self.assertEqual(staff_client.get(url).status_code, 200)
        self.role.permissions.clear()
        self.assertEqual(staff_client.get(url).status_code, 403)
        self.role.permissions.add(self.view_color)
        self.assertEqual(staff_client.get(url).status_code, 200)

    def test_sign_in_updates_last_login_and_audit(self):
        from django.contrib.admin.models import LogEntry

        self.client.force_authenticate(user=None)
        response = self.client.post(
            self.root + "login/",
            {"email": self.staff.email, "password": "A9!sY2-kP8vQ"},
        )
        self.assertEqual(response.status_code, 200)
        self.staff.refresh_from_db()
        self.assertIsNotNone(self.staff.last_login)
        self.assertTrue(
            LogEntry.objects.filter(
                user=self.staff, change_message__contains="Signed in"
            ).exists()
        )

    def test_audit_and_staff_records_cannot_be_deleted(self):
        from django.contrib.admin.models import CHANGE, LogEntry

        entry = LogEntry.objects.create(
            user=self.owner,
            object_repr="Staff status",
            action_flag=CHANGE,
            change_message="Suspended operator",
        )
        for key, pk in (("activity", entry.pk), ("team", self.staff.pk)):
            url = self.root + f"resources/{key}/{pk}/"
            self.assertFalse(self.client.get(url).data["delete"])
            self.assertEqual(self.client.delete(url).status_code, 403)
        audit_url = self.root + f"resources/activity/{entry.pk}/"
        self.assertEqual(
            self.client.post(audit_url, {"change_message": "Changed"}).status_code, 403
        )

    def test_assigned_role_cannot_be_deleted(self):
        self.staff.groups.add(self.role)
        url = self.root + f"resources/roles/{self.role.pk}/"
        result = self.client.get(url).data
        self.assertTrue(result["deletion"]["blockers"])
        self.assertEqual(
            self.client.delete(
                url,
                HTTP_X_RECORD_VERSION=result["version"],
                HTTP_X_DELETION_TOKEN=result["deletion"]["token"],
            ).status_code,
            409,
        )
        self.assertEqual(result["members"][0]["email"], self.staff.email)

    def test_workspace_counts_and_alerts_follow_permissions(self):
        from products.models import Category, Product, ProductVariant

        category = Category.objects.create(name="Memory")
        product = Product.objects.create(category=category, name="RAM")
        ProductVariant.objects.create(product=product, sku="RAM-1", price=100, stock=2)
        permission = Permission.objects.get(
            content_type__app_label="products", codename="view_productvariant"
        )
        self.staff.user_permissions.add(permission)
        self.client.force_authenticate(self.staff)
        response = self.client.get(self.root + "workspace/")
        self.assertEqual(response.data["summary"]["low_stock"], 1)
        self.assertNotIn("active_staff", response.data["summary"])
        self.assertNotIn("pending_orders", response.data["summary"])
        self.assertEqual(response.data["alerts"][0]["key"], "variants")
        self.assertFalse(response.data["can_overview"])

    def test_staff_without_model_permissions_cannot_use_legacy_catalog_admin_role(self):
        result = self.client.post(
            "/api/v1/products/categories/", {"name": "Forbidden category"}
        )
        self.assertEqual(result.status_code, 201)
        self.client.force_authenticate(self.staff)
        self.assertEqual(
            self.client.post(
                "/api/v1/products/categories/", {"name": "Another category"}
            ).status_code,
            403,
        )
        self.assertEqual(
            self.client.get("/api/v1/products/categories/").status_code, 200
        )

    def test_django_account_admin_is_owner_only_even_with_change_user(self):
        from django.contrib import admin
        from django.test import RequestFactory

        self.staff.user_permissions.add(
            Permission.objects.get(
                content_type__app_label="accounts", codename="change_user"
            )
        )
        request = RequestFactory().get("/admin/accounts/user/")
        request.user = self.staff
        account_admin = admin.site._registry[get_user_model()]
        self.assertFalse(account_admin.has_change_permission(request, self.owner))
        self.assertFalse(account_admin.has_view_permission(request, self.owner))
