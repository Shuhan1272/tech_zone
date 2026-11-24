"""0% EMI checkout and the admin overview reporting window."""

from datetime import timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from cart.models import Cart, CartItem
from payments.services import GatewayError
from products.models import Category, Product, ProductVariant

from .models import Order
from .services import emi_monthly_amount

CHECKOUT = "/api/v1/orders/checkout/"
ADDRESS = {
    "shipping_name": "Buyer",
    "shipping_phone": "01712345678",
    "shipping_house": "House 1",
    "shipping_road": "Road 2",
    "shipping_division": "dhaka",
    "shipping_district": "Dhaka",
    "shipping_upazila": "Dhanmondi",
    "shipping_postal_code": "1209",
}


class EmiCheckoutTests(TestCase):
    def setUp(self):
        cache.clear()
        category = Category.objects.create(name="Phone")
        phone = Product.objects.create(name="Phone Z", category=category)
        self.variant = ProductVariant.objects.create(
            product=phone,
            price=Decimal("179999.00"),
            discount_percentage=Decimal("10"),
            stock=5,
        )
        cheap = Product.objects.create(name="Cable", category=category)
        self.cheap_variant = ProductVariant.objects.create(
            product=cheap, price=Decimal("1000.00"), stock=5
        )
        self.user = get_user_model().objects.create_user(
            "emi-buyer@example.test", "pass-1234-word"
        )
        self.cart = Cart.objects.create(user=self.user)
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def tearDown(self):
        cache.clear()

    def test_monthly_amount_rounds_up(self):
        self.assertEqual(emi_monthly_amount(Decimal("179999"), 12), Decimal("15000"))
        self.assertEqual(emi_monthly_amount(Decimal("12000"), 12), Decimal("1000"))

    def test_emi_order_uses_regular_price_and_stores_tenure(self):
        CartItem.objects.create(cart=self.cart, variant=self.variant, quantity=1)
        response = self.client.post(
            CHECKOUT,
            {**ADDRESS, "payment_method": "sslcommerz", "emi_months": 12},
            format="json",
        )
        self.assertEqual(response.status_code, 201, response.data)
        order = Order.objects.get(pk=response.data["id"])
        self.assertTrue(order.is_emi)
        self.assertEqual(order.emi_months, 12)
        # Regular price, not the 10% cash discount price.
        self.assertEqual(order.subtotal, Decimal("179999.00"))
        self.assertEqual(order.items.get().unit_price, Decimal("179999.00"))
        self.assertEqual(order.total_amount, Decimal("197998.90"))
        self.assertEqual(order.emi_monthly_amount, Decimal("16500"))

    def test_cash_order_keeps_discount_price(self):
        CartItem.objects.create(cart=self.cart, variant=self.variant, quantity=1)
        response = self.client.post(
            CHECKOUT, {**ADDRESS, "payment_method": "sslcommerz"}, format="json"
        )
        self.assertEqual(response.status_code, 201, response.data)
        order = Order.objects.get(pk=response.data["id"])
        self.assertFalse(order.is_emi)
        self.assertEqual(order.subtotal, Decimal("161999.10"))

    def test_emi_rejected_with_cash_on_delivery(self):
        CartItem.objects.create(cart=self.cart, variant=self.variant, quantity=1)
        response = self.client.post(
            CHECKOUT,
            {**ADDRESS, "payment_method": "cod", "emi_months": 6},
            format="json",
        )
        self.assertEqual(response.status_code, 400)
        self.assertFalse(Order.objects.exists())

    def test_emi_rejected_below_minimum_and_for_bad_tenure(self):
        CartItem.objects.create(cart=self.cart, variant=self.cheap_variant, quantity=1)
        response = self.client.post(
            CHECKOUT,
            {**ADDRESS, "payment_method": "sslcommerz", "emi_months": 3},
            format="json",
        )
        self.assertEqual(response.status_code, 400)

        response = self.client.post(
            CHECKOUT,
            {**ADDRESS, "payment_method": "sslcommerz", "emi_months": 5},
            format="json",
        )
        self.assertEqual(response.status_code, 400)
        self.assertFalse(Order.objects.exists())

    def test_gateway_payload_enables_emi(self):
        from unittest.mock import patch

        from django.test import override_settings

        from payments.models import Payment
        from payments.services import create_gateway_session

        CartItem.objects.create(cart=self.cart, variant=self.variant, quantity=1)
        response = self.client.post(
            CHECKOUT,
            {**ADDRESS, "payment_method": "sslcommerz", "emi_months": 6},
            format="json",
        )
        order = Order.objects.get(pk=response.data["id"])
        payment = Payment.objects.create(
            order=order,
            amount=order.total_amount,
            transaction_id="TZ-EMI-TEST",
        )
        with override_settings(
            SSLCOMMERZ_STORE_ID="test-store",
            SSLCOMMERZ_STORE_PASSWORD="test-store-pass",
            SSLCOMMERZ_BACKEND_URL="https://backend.example.test",
        ), patch("payments.services.gateway_request") as gateway:
            gateway.return_value = {}
            with self.assertRaises(GatewayError):
                create_gateway_session(payment)
        payload = gateway.call_args.args[2]
        self.assertEqual(payload["emi_option"], "1")
        self.assertEqual(payload["emi_max_inst_option"], "6")
        self.assertEqual(payload["emi_selected_inst"], "6")


class OverviewRangeTests(TestCase):
    url = "/api/v1/admin-panel/overview/"

    def setUp(self):
        self.owner = get_user_model().objects.create_superuser(
            "owner-range@example.test", "pass-1234-word"
        )
        self.client = APIClient()
        self.client.force_authenticate(self.owner)

    def test_today_preset_is_one_day(self):
        response = self.client.get(self.url, {"days": "1"})
        self.assertEqual(response.status_code, 200)
        today = timezone.localdate().isoformat()
        self.assertEqual(response.data["start"], today)
        self.assertEqual(response.data["end"], today)
        self.assertEqual(len(response.data["series"]), 1)

    def test_custom_range(self):
        end = timezone.localdate() - timedelta(days=1)
        start = end - timedelta(days=9)
        response = self.client.get(
            self.url, {"start": start.isoformat(), "end": end.isoformat()}
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data["days"], 10)
        self.assertEqual(len(response.data["series"]), 10)
        self.assertEqual(response.data["series"][0]["date"], start.isoformat())

    def test_invalid_custom_ranges(self):
        today = timezone.localdate()
        for params in [
            {"start": "2026-02-30", "end": today.isoformat()},
            {"start": today.isoformat(), "end": (today - timedelta(days=1)).isoformat()},
            {"start": today.isoformat(), "end": (today + timedelta(days=1)).isoformat()},
            {"start": (today - timedelta(days=400)).isoformat(), "end": today.isoformat()},
            {"start": today.isoformat()},
        ]:
            self.assertEqual(self.client.get(self.url, params).status_code, 400, params)
