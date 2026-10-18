"""Order system tests.

Covers the things that would cost real money if they broke: totals, stock,
ownership, and the two ways a double submission can reach the server.
"""

from decimal import Decimal
from unittest import mock

from django.db import DatabaseError
from django.db.models import F, QuerySet
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import Address, User
from cart.models import Cart, CartItem
from products.models import Brand, Category, Product, ProductVariant

from .models import Order, OrderItem


ORDERS_URL = '/api/v1/orders/'


def detail_url(order_number):
    return f'{ORDERS_URL}{order_number}/'


class OrderTestCase(APITestCase):
    """Shared catalogue + customer fixture."""

    def setUp(self):
        self.user = User.objects.create_user(
            email='customer@example.com',
            password='pass12345',
            phone='01700000000',
            is_email_verified=True,
        )

        self.address = Address.objects.create(
            user=self.user,
            first_name='Murad',
            last_name='Ahmed',
            address1='12 Elephant Road',
            city='Dhaka',
            postal_code='1205',
            region='Dhaka',
        )

        self.category = Category.objects.create(name='Laptop')
        self.brand = Brand.objects.create(name='Asus')

        self.laptop = Product.objects.create(
            category=self.category,
            brand=self.brand,
            name='Asus VivoBook 15',
        )

        self.mouse = Product.objects.create(
            category=self.category,
            brand=self.brand,
            name='Asus Wireless Mouse',
        )

        # 1000.00 with 10% off -> 900.00 payable per unit.
        self.laptop_variant = ProductVariant.objects.create(
            product=self.laptop,
            price=Decimal('1000.00'),
            discount_percentage=Decimal('10.00'),
            stock=5,
        )

        # 500.00, no discount.
        self.mouse_variant = ProductVariant.objects.create(
            product=self.mouse,
            price=Decimal('500.00'),
            stock=5,
        )

        self.cart = Cart.objects.create(user=self.user)

    # ----- helpers -----

    def fill_cart(self, laptops=2, mice=1):
        if laptops:
            CartItem.objects.create(
                cart=self.cart,
                variant=self.laptop_variant,
                quantity=laptops,
            )

        if mice:
            CartItem.objects.create(
                cart=self.cart,
                variant=self.mouse_variant,
                quantity=mice,
            )

    def sign_in(self, user=None):
        self.client.force_authenticate(user=user or self.user)

    def post_order(self, idempotency_key=None, **body):
        headers = {}

        if idempotency_key:
            headers['HTTP_IDEMPOTENCY_KEY'] = idempotency_key

        return self.client.post(ORDERS_URL, body, format='json', **headers)


# =========================================================
# PLACING AN ORDER
# =========================================================

class PlaceOrderTests(OrderTestCase):

    def test_successful_order(self):
        self.fill_cart()
        self.sign_in()

        response = self.post_order(payment_method='cod')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        order = Order.objects.get()

        # The order number is returned and is not a guessable sequence.
        self.assertEqual(response.data['order_number'], order.order_number)
        self.assertTrue(order.order_number.startswith('TZ-'))
        self.assertEqual(len(order.order_number.split('-')), 3)

        # A new order is pending, and cash on delivery is NOT paid.
        self.assertEqual(order.status, Order.Status.PENDING)
        self.assertEqual(order.payment_method, Order.PaymentMethod.COD)
        self.assertEqual(order.payment_status, Order.PaymentStatus.UNPAID)

        self.assertEqual(order.items.count(), 2)

    def test_totals_are_calculated_by_the_server(self):
        self.fill_cart(laptops=2, mice=1)
        self.sign_in()

        self.post_order()

        order = Order.objects.get()

        # 2 x 1000 + 1 x 500 list price
        self.assertEqual(order.items_subtotal, Decimal('2500.00'))

        # 2 x 100 saved on the discounted laptop
        self.assertEqual(order.product_discount_total, Decimal('200.00'))

        self.assertEqual(order.coupon_discount, Decimal('0.00'))

        # No delivery charge is calculated anywhere: a real zero.
        self.assertEqual(order.shipping_fee, Decimal('0.00'))

        self.assertEqual(order.grand_total, Decimal('2300.00'))

    def test_client_supplied_prices_are_ignored(self):
        self.fill_cart(laptops=1, mice=0)
        self.sign_in()

        response = self.post_order(
            grand_total='1',
            items_subtotal='1',
            shipping_fee='999',
            items=[{'variant': self.laptop_variant.id, 'quantity': 100}],
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        order = Order.objects.get()

        self.assertEqual(order.grand_total, Decimal('900.00'))
        self.assertEqual(order.shipping_fee, Decimal('0.00'))
        self.assertEqual(order.items.count(), 1)
        self.assertEqual(order.items.first().quantity, 1)

    def test_prices_are_snapshotted(self):
        self.fill_cart(laptops=1, mice=0)
        self.sign_in()

        self.post_order()

        # The catalogue price doubles after the order was placed.
        self.laptop_variant.price = Decimal('2000.00')
        self.laptop_variant.save()

        self.laptop.name = 'Asus VivoBook 15 (2026 refresh)'
        self.laptop.save()

        item = OrderItem.objects.get()

        self.assertEqual(item.unit_price, Decimal('1000.00'))
        self.assertEqual(item.unit_price_paid, Decimal('900.00'))
        self.assertEqual(item.line_total, Decimal('900.00'))
        self.assertEqual(item.product_name, 'Asus VivoBook 15')

    def test_address_is_snapshotted(self):
        self.fill_cart(laptops=1, mice=0)
        self.sign_in()

        self.post_order()

        # The customer moves house afterwards.
        self.address.city = 'Chattogram'
        self.address.save()

        order = Order.objects.get()

        self.assertEqual(order.ship_city, 'Dhaka')
        self.assertEqual(order.ship_recipient, 'Murad Ahmed')
        self.assertEqual(order.ship_phone, '01700000000')

    def test_stock_is_deducted(self):
        self.fill_cart(laptops=2, mice=1)
        self.sign_in()

        self.post_order()

        self.laptop_variant.refresh_from_db()
        self.mouse_variant.refresh_from_db()

        self.assertEqual(self.laptop_variant.stock, 3)
        self.assertEqual(self.mouse_variant.stock, 4)

    def test_cart_is_emptied_only_after_the_order_exists(self):
        self.fill_cart()
        self.sign_in()

        self.post_order()

        self.assertEqual(Order.objects.count(), 1)
        self.assertEqual(self.cart.items.count(), 0)

    def test_empty_cart_is_rejected(self):
        self.sign_in()

        response = self.post_order()

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('cart', response.data)
        self.assertEqual(Order.objects.count(), 0)

    def test_insufficient_stock_is_rejected(self):
        self.fill_cart(laptops=2, mice=0)
        self.sign_in()

        self.laptop_variant.stock = 1
        self.laptop_variant.save()

        response = self.post_order()

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('items', response.data)

        # Nothing was written and nothing was taken from stock.
        self.assertEqual(Order.objects.count(), 0)

        self.laptop_variant.refresh_from_db()
        self.assertEqual(self.laptop_variant.stock, 1)

        # The cart is left intact so the customer can fix the quantity.
        self.assertEqual(self.cart.items.count(), 1)

    def test_inactive_product_is_rejected(self):
        self.fill_cart(laptops=1, mice=0)
        self.sign_in()

        self.laptop_variant.is_active = False
        self.laptop_variant.save()

        response = self.post_order()

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(Order.objects.count(), 0)

    def test_missing_address_is_rejected(self):
        self.address.delete()
        self.fill_cart()
        self.sign_in()

        response = self.post_order()

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('shipping_address', response.data)
        self.assertEqual(Order.objects.count(), 0)

    def test_incomplete_address_is_rejected(self):
        self.address.city = '   '
        self.address.postal_code = ''
        self.address.save()

        self.fill_cart()
        self.sign_in()

        response = self.post_order()

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('shipping_address', response.data)
        self.assertEqual(Order.objects.count(), 0)

    def test_unknown_payment_method_is_rejected(self):
        self.fill_cart()
        self.sign_in()

        response = self.post_order(payment_method='card')

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(Order.objects.count(), 0)

    def test_anonymous_cannot_place_an_order(self):
        self.fill_cart()

        response = self.post_order()

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertEqual(Order.objects.count(), 0)


# =========================================================
# DUPLICATE SUBMISSION
# =========================================================

class DuplicateSubmissionTests(OrderTestCase):

    def test_same_idempotency_key_returns_the_first_order(self):
        self.fill_cart()
        self.sign_in()

        first = self.post_order(idempotency_key='checkout-abc-123')
        second = self.post_order(idempotency_key='checkout-abc-123')

        self.assertEqual(first.status_code, status.HTTP_201_CREATED)

        # The replay is not a new order, so it is not a 201.
        self.assertEqual(second.status_code, status.HTTP_200_OK)

        self.assertEqual(
            first.data['order_number'],
            second.data['order_number'],
        )

        self.assertEqual(Order.objects.count(), 1)

    def test_replayed_key_does_not_deduct_stock_twice(self):
        self.fill_cart(laptops=2, mice=0)
        self.sign_in()

        self.post_order(idempotency_key='k-1')
        self.post_order(idempotency_key='k-1')
        self.post_order(idempotency_key='k-1')

        self.laptop_variant.refresh_from_db()

        self.assertEqual(self.laptop_variant.stock, 3)
        self.assertEqual(Order.objects.count(), 1)

    def test_a_different_key_is_a_different_checkout(self):
        self.fill_cart(laptops=1, mice=0)
        self.sign_in()

        first = self.post_order(idempotency_key='k-1')

        # The cart is empty now, so a genuinely new checkout attempt is
        # rejected rather than silently duplicating the first order.
        second = self.post_order(idempotency_key='k-2')

        self.assertEqual(first.status_code, status.HTTP_201_CREATED)
        self.assertEqual(second.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(Order.objects.count(), 1)

    def test_two_customers_may_reuse_the_same_key(self):
        other = User.objects.create_user(
            email='other@example.com',
            password='pass12345',
            phone='01800000000',
        )

        Address.objects.create(
            user=other,
            first_name='Other',
            last_name='Customer',
            address1='9 Mirpur Road',
            city='Dhaka',
            postal_code='1216',
            region='Dhaka',
        )

        other_cart = Cart.objects.create(user=other)

        CartItem.objects.create(
            cart=other_cart,
            variant=self.mouse_variant,
            quantity=1,
        )

        self.fill_cart(laptops=1, mice=0)

        self.sign_in()
        mine = self.post_order(idempotency_key='same-key')

        self.client.force_authenticate(user=other)
        theirs = self.post_order(idempotency_key='same-key')

        self.assertEqual(mine.status_code, status.HTTP_201_CREATED)
        self.assertEqual(theirs.status_code, status.HTTP_201_CREATED)

        self.assertNotEqual(
            mine.data['order_number'],
            theirs.data['order_number'],
        )

    def post_raw(self, body, header_key=None):
        """POST with full control over header and body, for the key tests."""
        headers = {}

        if header_key:
            headers['HTTP_IDEMPOTENCY_KEY'] = header_key

        return self.client.post(ORDERS_URL, body, format='json', **headers)

    def test_a_key_in_the_body_works_without_the_header(self):
        # A browser will not send Idempotency-Key unless the server names it
        # in Access-Control-Allow-Headers, so the body carries it too and the
        # guarantee does not depend on that setting.
        self.fill_cart()
        self.sign_in()

        payload = {'payment_method': 'cod', 'idempotency_key': 'body-key-1'}

        first = self.post_raw(payload)
        second = self.post_raw(payload)

        self.assertEqual(first.status_code, status.HTTP_201_CREATED)
        self.assertEqual(second.status_code, status.HTTP_200_OK)
        self.assertEqual(
            first.data['order_number'],
            second.data['order_number'],
        )
        self.assertEqual(Order.objects.count(), 1)

    def test_the_header_wins_when_both_are_present(self):
        self.fill_cart()
        self.sign_in()

        response = self.post_raw(
            {'payment_method': 'cod', 'idempotency_key': 'from-body'},
            header_key='from-header',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Order.objects.get().idempotency_key, 'from-header')

    def test_the_two_carriers_are_the_same_key(self):
        """Header on the first attempt, body on the retry: still one order."""
        self.fill_cart()
        self.sign_in()

        first = self.post_raw({'payment_method': 'cod'}, header_key='shared')

        second = self.post_raw(
            {'payment_method': 'cod', 'idempotency_key': 'shared'}
        )

        self.assertEqual(first.status_code, status.HTTP_201_CREATED)
        self.assertEqual(second.status_code, status.HTTP_200_OK)
        self.assertEqual(Order.objects.count(), 1)

    def test_second_submission_without_a_key_finds_an_empty_cart(self):
        self.fill_cart(laptops=1, mice=0)
        self.sign_in()

        first = self.post_order()
        second = self.post_order()

        self.assertEqual(first.status_code, status.HTTP_201_CREATED)
        self.assertEqual(second.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(Order.objects.count(), 1)


# =========================================================
# OVERSELLING AND ROLLBACK
# =========================================================

class StockSafetyTests(OrderTestCase):

    def test_conditional_update_cannot_oversell(self):
        """The exact statement place_order uses to deduct stock.

        It is one atomic UPDATE, so two customers racing for the last unit
        cannot both succeed: the loser updates zero rows.
        """
        self.laptop_variant.stock = 3
        self.laptop_variant.save()

        taken = (
            ProductVariant.objects
            .filter(pk=self.laptop_variant.pk, stock__gte=5)
            .update(stock=F('stock') - 5)
        )

        self.assertEqual(taken, 0)

        self.laptop_variant.refresh_from_db()
        self.assertEqual(self.laptop_variant.stock, 3)

    def test_failure_mid_placement_rolls_everything_back(self):
        """Emptying the cart is the last step; make it fail.

        By then the order, its items and both stock deductions have been
        written, so this proves the whole placement unwinds together.
        """
        self.fill_cart(laptops=2, mice=1)
        self.sign_in()

        with mock.patch.object(
            QuerySet, 'delete', side_effect=DatabaseError('disk is on fire')
        ):
            response = self.post_order()

        self.assertEqual(
            response.status_code,
            status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

        # The customer is told nothing technical.
        self.assertNotIn('disk', str(response.data).lower())

        self.assertEqual(Order.objects.count(), 0)
        self.assertEqual(OrderItem.objects.count(), 0)

        self.laptop_variant.refresh_from_db()
        self.mouse_variant.refresh_from_db()

        self.assertEqual(self.laptop_variant.stock, 5)
        self.assertEqual(self.mouse_variant.stock, 5)

        self.assertEqual(self.cart.items.count(), 2)


# =========================================================
# CANCELLATION
# =========================================================

class CancellationTests(OrderTestCase):

    def place(self):
        self.fill_cart(laptops=2, mice=1)
        self.sign_in()
        self.post_order()

        return Order.objects.get()

    def test_cancelling_restores_stock(self):
        order = self.place()

        self.laptop_variant.refresh_from_db()
        self.assertEqual(self.laptop_variant.stock, 3)

        order.status = Order.Status.CANCELLED
        order.save()

        self.laptop_variant.refresh_from_db()
        self.mouse_variant.refresh_from_db()

        self.assertEqual(self.laptop_variant.stock, 5)
        self.assertEqual(self.mouse_variant.stock, 5)

        order.refresh_from_db()
        self.assertIsNotNone(order.stock_restored_at)

    def test_stock_is_restored_exactly_once(self):
        order = self.place()

        order.status = Order.Status.CANCELLED
        order.save()

        # Repeated saves, re-fetches and direct calls must all be no-ops.
        order.save()

        Order.objects.get(pk=order.pk).save()

        self.assertFalse(Order.objects.get(pk=order.pk).restore_stock())

        self.laptop_variant.refresh_from_db()
        self.mouse_variant.refresh_from_db()

        self.assertEqual(self.laptop_variant.stock, 5)
        self.assertEqual(self.mouse_variant.stock, 5)

    def test_reinstating_then_cancelling_again_restores_once(self):
        order = self.place()

        order.status = Order.Status.CANCELLED
        order.save()

        order.status = Order.Status.CONFIRMED
        order.save()

        order.status = Order.Status.CANCELLED
        order.save()

        self.laptop_variant.refresh_from_db()

        # Still 5, not 7: the second cancellation found the claim taken.
        self.assertEqual(self.laptop_variant.stock, 5)

    def test_other_status_changes_do_not_touch_stock(self):
        order = self.place()

        for next_status in (
            Order.Status.CONFIRMED,
            Order.Status.PROCESSING,
            Order.Status.SHIPPED,
            Order.Status.DELIVERED,
        ):
            order.status = next_status
            order.save()

        self.laptop_variant.refresh_from_db()

        self.assertEqual(self.laptop_variant.stock, 3)
        self.assertIsNone(Order.objects.get(pk=order.pk).stock_restored_at)

    def test_customers_cannot_cancel_through_the_api(self):
        order = self.place()

        for method in (self.client.patch, self.client.put):
            response = method(
                detail_url(order.order_number),
                {'status': 'cancelled'},
                format='json',
            )

            self.assertEqual(
                response.status_code,
                status.HTTP_405_METHOD_NOT_ALLOWED,
            )

        self.assertEqual(
            Order.objects.get(pk=order.pk).status,
            Order.Status.PENDING,
        )


# =========================================================
# HISTORY AND DETAIL
# =========================================================

class OrderHistoryTests(OrderTestCase):

    def setUp(self):
        super().setUp()

        self.stranger = User.objects.create_user(
            email='stranger@example.com',
            password='pass12345',
            phone='01900000000',
        )

        Address.objects.create(
            user=self.stranger,
            first_name='Stranger',
            last_name='Danger',
            address1='1 Gulshan Avenue',
            city='Dhaka',
            postal_code='1212',
            region='Dhaka',
        )

        stranger_cart = Cart.objects.create(user=self.stranger)

        CartItem.objects.create(
            cart=stranger_cart,
            variant=self.mouse_variant,
            quantity=1,
        )

        self.client.force_authenticate(user=self.stranger)
        self.post_order()

        self.stranger_order = Order.objects.get(user=self.stranger)

        self.client.force_authenticate(user=None)

    def place_mine(self):
        self.fill_cart(laptops=1, mice=0)
        self.sign_in()
        self.post_order()

        return Order.objects.get(user=self.user)

    def test_history_lists_only_my_orders(self):
        mine = self.place_mine()

        response = self.client.get(ORDERS_URL)

        self.assertEqual(response.status_code, status.HTTP_200_OK)

        numbers = [row['order_number'] for row in response.data['results']]

        self.assertEqual(numbers, [mine.order_number])
        self.assertNotIn(self.stranger_order.order_number, numbers)

    def test_history_includes_a_readable_summary(self):
        self.place_mine()

        response = self.client.get(ORDERS_URL)
        row = response.data['results'][0]

        self.assertEqual(row['summary'], 'Asus VivoBook 15')
        self.assertEqual(row['item_count'], 1)
        self.assertEqual(row['total_quantity'], 1)
        self.assertEqual(row['status_display'], 'Pending')
        self.assertEqual(row['payment_method_display'], 'Cash on Delivery')
        self.assertEqual(row['shipping_fee'], '0.00')

    def test_history_is_empty_for_a_new_customer(self):
        self.sign_in()

        response = self.client.get(ORDERS_URL)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 0)
        self.assertEqual(response.data['results'], [])

    def test_anonymous_cannot_read_history(self):
        response = self.client.get(ORDERS_URL)

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_detail_returns_items_and_address(self):
        mine = self.place_mine()

        response = self.client.get(detail_url(mine.order_number))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['order_number'], mine.order_number)
        self.assertEqual(len(response.data['items']), 1)

        item = response.data['items'][0]
        self.assertEqual(item['product_name'], 'Asus VivoBook 15')
        self.assertEqual(item['unit_price'], '1000.00')
        self.assertEqual(item['unit_price_paid'], '900.00')

        address = response.data['shipping_address']
        self.assertEqual(address['recipient'], 'Murad Ahmed')
        self.assertEqual(address['city'], 'Dhaka')

    def test_cannot_read_another_customers_order(self):
        self.sign_in()

        response = self.client.get(detail_url(self.stranger_order.order_number))

        # 404, not 403: a 403 would confirm the order exists.
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_anonymous_cannot_read_a_detail(self):
        response = self.client.get(detail_url(self.stranger_order.order_number))

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_unknown_order_number_is_a_404(self):
        self.sign_in()

        response = self.client.get(detail_url('TZ-000000-ZZZZZZ'))

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)


# =========================================================
# DJANGO ADMIN
# =========================================================

class OrderAdminTests(OrderTestCase):
    """The back office is where orders are actually worked, so it is tested."""

    def setUp(self):
        super().setUp()

        self.staff = User.objects.create_superuser(
            email='admin@example.com',
            password='admin12345',
            phone='01600000000',
        )

        self.fill_cart(laptops=2, mice=1)
        self.sign_in()
        self.post_order()
        self.order = Order.objects.get(user=self.user)

        self.client.force_authenticate(user=None)
        self.client.force_login(self.staff)

    def test_changelist_lists_the_order(self):
        response = self.client.get(reverse('admin:order_order_changelist'))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, self.order.order_number)

    def test_change_page_opens_with_the_snapshot(self):
        response = self.client.get(
            reverse('admin:order_order_change', args=[self.order.pk])
        )

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, self.order.order_number)
        self.assertContains(response, 'Asus VivoBook 15')
        self.assertContains(response, '12 Elephant Road')

    def test_orders_cannot_be_created_by_hand(self):
        # A typed-in order would have no stock deduction behind it.
        response = self.client.get(reverse('admin:order_order_add'))

        self.assertEqual(response.status_code, 403)

    def test_cancel_action_restores_stock(self):
        self.laptop_variant.refresh_from_db()
        self.assertEqual(self.laptop_variant.stock, 3)

        response = self.client.post(
            reverse('admin:order_order_changelist'),
            {
                'action': 'cancel_orders',
                '_selected_action': [str(self.order.pk)],
            },
            follow=True,
        )

        self.assertEqual(response.status_code, 200)

        self.order.refresh_from_db()
        self.assertEqual(self.order.status, Order.Status.CANCELLED)
        self.assertIsNotNone(self.order.stock_restored_at)

        self.laptop_variant.refresh_from_db()
        self.mouse_variant.refresh_from_db()

        self.assertEqual(self.laptop_variant.stock, 5)
        self.assertEqual(self.mouse_variant.stock, 5)

    def test_running_the_cancel_action_twice_restores_once(self):
        payload = {
            'action': 'cancel_orders',
            '_selected_action': [str(self.order.pk)],
        }

        url = reverse('admin:order_order_changelist')

        self.client.post(url, payload, follow=True)
        self.client.post(url, payload, follow=True)

        self.laptop_variant.refresh_from_db()

        self.assertEqual(self.laptop_variant.stock, 5)

    def test_shipping_action_leaves_stock_alone(self):
        self.client.post(
            reverse('admin:order_order_changelist'),
            {
                'action': 'mark_shipped',
                '_selected_action': [str(self.order.pk)],
            },
            follow=True,
        )

        self.order.refresh_from_db()
        self.assertEqual(self.order.status, Order.Status.SHIPPED)

        self.laptop_variant.refresh_from_db()
        self.assertEqual(self.laptop_variant.stock, 3)
