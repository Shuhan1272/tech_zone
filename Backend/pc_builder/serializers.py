
from decimal import Decimal

from rest_framework import serializers

from products.models import Product, ProductVariant

from .models import (
    ComponentType,
    PCComponentCategory,
    PCBuild,
    PCBuildItem,
)


# =========================================================
# PC COMPONENT VARIANT SERIALIZER
# =========================================================

class PCComponentVariantSerializer(serializers.ModelSerializer):

    product_id = serializers.IntegerField(
        source="product.id",
        read_only=True
    )

    product_name = serializers.CharField(
        source="product.name",
        read_only=True
    )

    brand = serializers.CharField(
        source="product.brand.name",
        read_only=True,
        allow_null=True
    )

    category = serializers.CharField(
        source="product.category.name",
        read_only=True
    )

    discounted_price = serializers.DecimalField(
        max_digits=12,
        decimal_places=2,
        read_only=True
    )

    image = serializers.SerializerMethodField()

    class Meta:
        model = ProductVariant

        fields = [
            "id",
            "product_id",
            "product_name",
            "brand",
            "category",
            "sku",
            "ram",
            "storage",
            "price",
            "discounted_price",
            "stock",
            "image",
        ]

        read_only_fields = fields

    def get_image(self, obj):

        images = list(obj.product.images.all())

        if not images:
            return None

        image = min(
            images,
            key=lambda item: (
                not item.is_primary,
                item.display_order,
                item.id
            )
        )

        if not image.image:
            return None

        request = self.context.get("request")
        url = image.image.url

        if request:
            return request.build_absolute_uri(url)

        return url


# =========================================================
# PC BUILD ITEM SERIALIZER
# =========================================================

class PCBuildItemSerializer(serializers.ModelSerializer):

    variant = PCComponentVariantSerializer(
        read_only=True
    )

    subtotal = serializers.SerializerMethodField()

    class Meta:
        model = PCBuildItem

        fields = [
            "id",
            "component_type",
            "variant",
            "quantity",
            "subtotal",
        ]

        read_only_fields = fields

    def get_subtotal(self, obj):

        amount = (
            obj.variant.discounted_price
            * obj.quantity
        )

        return str(
            amount.quantize(Decimal("0.01"))
        )


# =========================================================
# PC BUILD SERIALIZER
# =========================================================

class PCBuildSerializer(serializers.ModelSerializer):

    items = PCBuildItemSerializer(
        many=True,
        read_only=True
    )

    total_price = serializers.SerializerMethodField()

    class Meta:
        model = PCBuild

        fields = [
            "id",
            "name",
            "items",
            "total_price",
            "created_at",
            "updated_at",
        ]

        read_only_fields = [
            "id",
            "items",
            "total_price",
            "created_at",
            "updated_at",
        ]

    def get_total_price(self, obj):

        total = sum(
            (
                item.variant.discounted_price
                * item.quantity
                for item in obj.items.all()
            ),
            Decimal("0.00")
        )

        return str(
            total.quantize(Decimal("0.01"))
        )


# =========================================================
# PC BUILD COMPONENT INPUT SERIALIZER
# =========================================================

class PCBuildItemInputSerializer(serializers.Serializer):

    component_type = serializers.ChoiceField(
        choices=ComponentType.choices
    )

    variant_id = serializers.PrimaryKeyRelatedField(
        source="variant",
        queryset=ProductVariant.objects.select_related(
            "product"
        ).filter(
            is_active=True,
            product__is_active=True
        )
    )

    quantity = serializers.IntegerField(
        min_value=1,
        default=1
    )

    def validate(self, attrs):

        variant = attrs["variant"]
        component_type = attrs["component_type"]
        quantity = attrs["quantity"]

        # =================================================
        # VALIDATE COMPONENT CATEGORY MAPPING
        # =================================================

        mapped = PCComponentCategory.objects.filter(
            category_id=variant.product.category_id,
            component_type=component_type
        ).exists()

        if not mapped:
            raise serializers.ValidationError({
                "variant_id": (
                    "This product is not mapped to the "
                    "selected PC component type in Django Admin."
                )
            })

        # =================================================
        # VALIDATE PRODUCT AVAILABILITY
        # =================================================

        if (
            variant.product.availability
            != Product.Availability.IN_STOCK
        ):
            raise serializers.ValidationError({
                "variant_id": (
                    "This product is currently unavailable."
                )
            })

        # =================================================
        # VALIDATE AVAILABLE STOCK
        # =================================================

        if variant.stock < quantity:
            raise serializers.ValidationError({
                "quantity": (
                    "Requested quantity exceeds available stock."
                )
            })

        # =================================================
        # VALIDATE SINGLE-QUANTITY COMPONENTS
        # =================================================

        single_quantity_components = {
            ComponentType.CPU,
            ComponentType.CPU_COOLER,
            ComponentType.MOTHERBOARD,
            ComponentType.GPU,
            ComponentType.PSU,
            ComponentType.CASE,
        }

        if (
            component_type in single_quantity_components
            and quantity != 1
        ):
            raise serializers.ValidationError({
                "quantity": (
                    "This component must have quantity 1."
                )
            })

        return attrs
