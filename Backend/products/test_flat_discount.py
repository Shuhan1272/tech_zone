"""Store-wide flat discount and the 10% shipping charge."""

from decimal import Decimal

from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.core.cache import cache
from django.test import TestCase
from rest_framework.test import APIClient

from cart.models import Cart, CartItem
from order.models import Order
from order.services import calculate_shipping

from .models import Category, FlatDiscount, Product, ProductVariant


class FlatDiscountTestCase(TestCase):
    def setUp(self):
        cache.clear()
        self.category = Category.objects.create(name="Gadget")
        self.phone = Product.objects.create(name="Phone X", category=self.category)
        self.watch = Product.objects.create(name="Watch Y", category=self.category)
        self.phone_variant = ProductVariant.objects.create(
            product=self.phone,
            price=Decimal("20000.00"),
            discount_percentage=Decimal("10"),
            stock=10,
        )
        self.watch_variant = ProductVariant.objects.create(
            product=self.watch,
            price=Decimal("1755.00"),
            discount_percentage=Decimal("0"),
            stock=10,
        )

    def tearDown(self):
        cache.clear()

    def set_flat(self, percentage):
        obj = FlatDiscount.load()
        obj.percentage = Decimal(percentage)
        obj.save()


class VariantPricingTests(FlatDiscountTestCase):
    def test_own_percentage_used_without_flat_discount(self):
        self.assertEqual(self.phone_variant.discounted_price, Decimal("18000.00"))
        self.assertEqual(self.watch_variant.discounted_price, Decimal("1755.00"))

    def test_flat_percentage_replaces_own_percentage_for_every_product(self):
        self.set_flat("30")
        self.assertEqual(self.phone_variant.discounted_price, Decimal("14000.00"))
        self.assertEqual(self.watch_variant.discounted_price, Decimal("1228.50"))
        self.assertEqual(self.watch_variant.saved_price, Decimal("526.50"))

    def test_fifty_percent_halves_every_price(self):
        self.set_flat("50")
        self.assertEqual(self.phone_variant.discounted_price, Decimal("10000.00"))
        self.assertEqual(self.watch_variant.discounted_price, Decimal("877.50"))

    def test_reset_restores_each_products_own_discount(self):
        self.set_flat("30")
        self.set_flat("0")
        self.phone_variant.refresh_from_db()
        self.assertEqual(self.phone_variant.discount_percentage, Decimal("10.00"))
        self.assertEqual(self.phone_variant.discounted_price, Decimal("18000.00"))
        self.assertEqual(self.watch_variant.discounted_price, Decimal("1755.00"))


class StorefrontListingTests(FlatDiscountTestCase):
    def test_list_prices_sorting_and_on_sale_follow_flat_discount(self):
        client = APIClient()
        url = "/api/v1/products/products/"

        on_sale = client.get(url, {"on_sale": "true"}).data["results"]
        self.assertEqual([p["name"] for p in on_sale], ["Phone X"])

        self.set_flat("50")
        on_sale = client.get(url, {"on_sale": "true"}).data["results"]
        self.assertEqual({p["name"] for p in on_sale}, {"Phone X", "Watch Y"})

        # Phone X is 10,000 at 50% off (its own 10% is paused).
        cheap = client.get(url, {"max_price": "10000"}).data["results"]
        self.assertEqual({p["name"] for p in cheap}, {"Phone X", "Watch Y"})
        cheap = client.get(url, {"max_price": "9999"}).data["results"]
        self.assertEqual([p["name"] for p in cheap], ["Watch Y"])


class AdminEndpointTests(FlatDiscountTestCase):
    url = "/api/v1/admin-panel/flat-discount/"

    def setUp(self):
        super().setUp()
        self.owner = get_user_model().objects.create_superuser(
            "owner@example.test", "pass-1234-word"
        )
        self.client = APIClient()
        self.client.force_authenticate(self.owner)

    def test_apply_and_reset(self):
        response = self.client.post(
            self.url, {"action": "apply", "percentage": "30"}, format="json"
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.assertTrue(response.data["active"])
        self.assertEqual(FlatDiscount.current_percentage(), Decimal("30.00"))
        self.assertEqual(self.phone_variant.discounted_price, Decimal("14000.00"))

        response = self.client.post(self.url, {"action": "reset"}, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertFalse(response.data["active"])
        self.assertEqual(self.phone_variant.discounted_price, Decimal("18000.00"))

    def test_rejects_hundred_percent_or_more(self):
        for value in ["100", "150"]:
            response = self.client.post(
                self.url, {"action": "apply", "percentage": value}, format="json"
            )
            self.assertEqual(response.status_code, 400, value)
        self.assertEqual(FlatDiscount.current_percentage(), Decimal("0"))

    def test_rejects_invalid_percentages(self):
        for value in ["", "abc", "-5", "0", "10.555", "NaN"]:
            response = self.client.post(
                self.url, {"action": "apply", "percentage": value}, format="json"
            )
            self.assertEqual(response.status_code, 400, value)

    def test_view_only_staff_cannot_change(self):
        staff = get_user_model().objects.create_user(
            "viewer@example.test", "pass-1234-word", is_staff=True
        )
        staff.user_permissions.add(
            Permission.objects.get(
                codename="view_productvariant", content_type__app_label="products"
            )
        )
        client = APIClient()
        client.force_authenticate(staff)
        self.assertEqual(client.get(self.url).status_code, 200)
        response = client.post(
            self.url, {"action": "apply", "percentage": "20"}, format="json"
        )
        self.assertEqual(response.status_code, 403)


class CheckoutShippingTests(FlatDiscountTestCase):
    def test_shipping_is_ten_percent_of_subtotal(self):
        self.assertEqual(calculate_shipping(Decimal("1640")), Decimal("164.00"))
        self.assertEqual(calculate_shipping(Decimal("0")), Decimal("0.00"))
        self.assertEqual(calculate_shipping(Decimal("99.95")), Decimal("10.00"))

    def test_order_total_includes_shipping_and_flat_discount(self):
        user = get_user_model().objects.create_user(
            "buyer@example.test", "pass-1234-word"
        )
        cart = Cart.objects.create(user=user)
        CartItem.objects.create(cart=cart, variant=self.watch_variant, quantity=2)
        self.set_flat("20")  # 1755 -> 1404 each

        client = APIClient()
        client.force_authenticate(user)

        cart_data = client.get("/api/v1/cart/").data
        self.assertEqual(cart_data["shipping_charge"], "280.80")

        response = client.post(
            "/api/v1/orders/checkout/",
            {
                "shipping_name": "Buyer",
                "shipping_phone": "01712345678",
                "shipping_house": "House 1",
                "shipping_road": "Road 2",
                "shipping_division": "dhaka",
                "shipping_district": "Dhaka",
                "shipping_upazila": "Dhanmondi",
                "shipping_postal_code": "1209",
                "payment_method": "cod",
            },
            format="json",
        )
        self.assertEqual(response.status_code, 201, response.data)

        order = Order.objects.get(pk=response.data["id"])
        self.assertEqual(order.subtotal, Decimal("2808.00"))  # 2 x 1404
        self.assertEqual(order.shipping_charge, Decimal("280.80"))
        self.assertEqual(order.total_amount, Decimal("3088.80"))
        self.assertEqual(response.data["shipping_charge"], "280.80")
