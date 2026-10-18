from django.contrib import admin, messages

from .models import Order, OrderItem


# =========================================================
# ORDER ITEM (inline)
# =========================================================

class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    can_delete = False

    # Every column here is a snapshot of how things were when the order was
    # placed. Editing one would falsify the record, so none of them open.
    readonly_fields = (
        'variant',
        'product_name',
        'variant_sku',
        'options',
        'unit_price',
        'unit_discount_percentage',
        'unit_price_paid',
        'quantity',
        'line_total',
    )

    fields = readonly_fields

    def has_add_permission(self, request, obj=None):
        return False


# =========================================================
# ORDER
# =========================================================

@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    inlines = (OrderItemInline,)

    list_display = (
        'order_number',
        'user',
        'status',
        'payment_method',
        'payment_status',
        'grand_total',
        'placed_at',
    )

    list_filter = (
        'status',
        'payment_status',
        'payment_method',
        'placed_at',
    )

    search_fields = (
        'order_number',
        'user__email',
        'user__phone',
        'items__product_name',
    )

    date_hierarchy = 'placed_at'

    ordering = ('-placed_at',)

    # Only the two workflow fields are editable. Money, the address
    # snapshot and the customer's own note are the record of what happened.
    readonly_fields = (
        'order_number',
        'user',
        'items_subtotal',
        'product_discount_total',
        'coupon_code',
        'coupon_discount',
        'shipping_fee',
        'grand_total',
        'ship_first_name',
        'ship_last_name',
        'ship_company',
        'ship_phone',
        'ship_address1',
        'ship_address2',
        'ship_city',
        'ship_postal_code',
        'ship_region',
        'ship_country',
        'customer_note',
        'idempotency_key',
        'stock_restored_at',
        'placed_at',
        'created_at',
        'updated_at',
    )

    fieldsets = (
        ('Order', {
            'fields': (
                'order_number',
                'user',
                'status',
                'placed_at',
            )
        }),
        ('Payment', {
            'fields': (
                'payment_method',
                'payment_status',
            ),
            'description': (
                'Cash on delivery orders stay <b>Unpaid</b> until the cash '
                'is actually collected. Do not mark an order paid before '
                'then.'
            ),
        }),
        ('Totals (calculated at checkout)', {
            'fields': (
                'items_subtotal',
                'product_discount_total',
                'coupon_code',
                'coupon_discount',
                'shipping_fee',
                'grand_total',
            ),
            'description': (
                'Shipping is <b>৳0.00</b>: no delivery charge is calculated '
                'anywhere in the system yet.'
            ),
        }),
        ('Delivery address (as placed)', {
            'fields': (
                'ship_first_name',
                'ship_last_name',
                'ship_company',
                'ship_phone',
                'ship_address1',
                'ship_address2',
                'ship_city',
                'ship_postal_code',
                'ship_region',
                'ship_country',
            )
        }),
        ('Other', {
            'fields': (
                'customer_note',
                'stock_restored_at',
                'idempotency_key',
                'created_at',
                'updated_at',
            )
        }),
    )

    actions = (
        'mark_confirmed',
        'mark_processing',
        'mark_shipped',
        'mark_delivered',
        'cancel_orders',
    )

    def get_queryset(self, request):
        return (
            super().get_queryset(request)
            .select_related('user')
            .prefetch_related('items')
        )

    def has_add_permission(self, request):
        # Orders are created by checkout, never typed in by hand: a
        # hand-made order would have no stock deduction behind it.
        return False

    # ----- status actions -----
    #
    # Each one saves the object instead of calling queryset.update(), because
    # Order.save() is what notices a move into Cancelled and gives the stock
    # back. A bulk UPDATE would skip that entirely.

    def _set_status(self, request, queryset, new_status, label):
        changed = 0

        for order in queryset:
            if order.status == new_status:
                continue

            order.status = new_status
            order.save()
            changed += 1

        self.message_user(
            request,
            f'{changed} order(s) marked {label}.',
            messages.SUCCESS if changed else messages.INFO
        )

    @admin.action(description='Mark selected orders as Confirmed')
    def mark_confirmed(self, request, queryset):
        self._set_status(
            request, queryset, Order.Status.CONFIRMED, 'Confirmed'
        )

    @admin.action(description='Mark selected orders as Processing')
    def mark_processing(self, request, queryset):
        self._set_status(
            request, queryset, Order.Status.PROCESSING, 'Processing'
        )

    @admin.action(description='Mark selected orders as Shipped')
    def mark_shipped(self, request, queryset):
        self._set_status(
            request, queryset, Order.Status.SHIPPED, 'Shipped'
        )

    @admin.action(description='Mark selected orders as Delivered')
    def mark_delivered(self, request, queryset):
        self._set_status(
            request, queryset, Order.Status.DELIVERED, 'Delivered'
        )

    @admin.action(description='Cancel selected orders (restores stock)')
    def cancel_orders(self, request, queryset):
        self._set_status(
            request, queryset, Order.Status.CANCELLED, 'Cancelled'
        )
