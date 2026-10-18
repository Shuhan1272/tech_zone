from rest_framework import serializers

from .models import Order, OrderItem


class OrderItemSerializer(serializers.ModelSerializer):
    """One line of an order, read straight from the snapshot columns.

    Nothing here is looked up through the variant, so the line still reads
    correctly after the product is renamed, repriced or withdrawn.
    """

    variant_id = serializers.IntegerField(source='variant.id', read_only=True)

    product_slug = serializers.CharField(
        source='variant.product.slug',
        read_only=True
    )

    class Meta:
        model = OrderItem
        fields = [
            'id',
            'variant_id',
            'product_name',
            'product_slug',
            'variant_sku',
            'options',
            'unit_price',
            'unit_discount_percentage',
            'unit_price_paid',
            'quantity',
            'line_total',
        ]
        read_only_fields = fields


class ShippingAddressSerializer(serializers.Serializer):
    """The address as it was when the order was placed."""

    recipient = serializers.CharField(source='ship_recipient')
    company = serializers.CharField(source='ship_company')
    phone = serializers.CharField(source='ship_phone')
    address1 = serializers.CharField(source='ship_address1')
    address2 = serializers.CharField(source='ship_address2')
    city = serializers.CharField(source='ship_city')
    postal_code = serializers.CharField(source='ship_postal_code')
    region = serializers.CharField(source='ship_region')
    country = serializers.CharField(source='ship_country')


class OrderListSerializer(serializers.ModelSerializer):
    """Compact shape for the order history list."""

    status_display = serializers.CharField(
        source='get_status_display',
        read_only=True
    )

    payment_method_display = serializers.CharField(
        source='get_payment_method_display',
        read_only=True
    )

    payment_status_display = serializers.CharField(
        source='get_payment_status_display',
        read_only=True
    )

    total_quantity = serializers.IntegerField(read_only=True)

    item_count = serializers.SerializerMethodField()

    summary = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = [
            'order_number',
            'status',
            'status_display',
            'payment_method',
            'payment_method_display',
            'payment_status',
            'payment_status_display',
            'items_subtotal',
            'product_discount_total',
            'coupon_discount',
            'shipping_fee',
            'grand_total',
            'total_quantity',
            'item_count',
            'summary',
            'placed_at',
        ]
        read_only_fields = fields

    def get_item_count(self, order):
        return order.items.count()

    def get_summary(self, order):
        """"Laptop X" or "Laptop X + 2 more" -- enough to recognise the order."""
        names = [item.product_name for item in order.items.all()]

        if not names:
            return ''

        if len(names) == 1:
            return names[0]

        return f"{names[0]} + {len(names) - 1} more"


class OrderDetailSerializer(OrderListSerializer):
    """Everything about one order, including its lines and address."""

    items = OrderItemSerializer(many=True, read_only=True)

    shipping_address = serializers.SerializerMethodField()

    class Meta(OrderListSerializer.Meta):
        fields = OrderListSerializer.Meta.fields + [
            'items',
            'shipping_address',
            'customer_note',
            'created_at',
            'updated_at',
        ]
        read_only_fields = fields

    def get_shipping_address(self, order):
        return ShippingAddressSerializer(order).data


class OrderCreateSerializer(serializers.Serializer):
    """The *only* things a customer may send when placing an order.

    No prices, no totals, no item list: the server reads those from the cart
    and the catalogue. Anything else in the request body is ignored.
    """

    payment_method = serializers.ChoiceField(
        choices=Order.PaymentMethod.choices,
        default=Order.PaymentMethod.COD
    )

    customer_note = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=1000,
        default=''
    )

    # Normally sent as the Idempotency-Key header. It is accepted here as
    # well so the guarantee does not quietly depend on a CORS setting: a
    # browser blocks any request carrying a header the server has not named
    # in Access-Control-Allow-Headers, and reports it as a bare network
    # error. The header still wins when both are present.
    idempotency_key = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=64,
        default=''
    )
