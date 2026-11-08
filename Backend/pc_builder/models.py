
from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator
from django.db import models

from products.models import Category, ProductVariant


class ComponentType(models.TextChoices):
    CPU = "cpu", "CPU"
    CPU_COOLER = "cpu_cooler", "CPU Cooler"
    MOTHERBOARD = "motherboard", "Motherboard"
    RAM = "ram", "RAM"
    STORAGE = "storage", "Storage"
    GPU = "gpu", "Graphics Card"
    PSU = "psu", "Power Supply"
    CASE = "case", "Casing"
    MONITOR = "monitor", "Monitor"
    CASE_COOLER = "case_cooler", "Casing Cooler"
    KEYBOARD = "keyboard", "Keyboard"
    MOUSE = "mouse", "Mouse"
    SPEAKER = "speaker", "Speaker"
    HEADPHONE = "headphone", "Headphone"
    NETWORK = "network", "WiFi / LAN Adapter"
    UPS = "ups", "UPS"


class PCComponentCategory(models.Model):
    category = models.OneToOneField(
        Category,
        on_delete=models.CASCADE,
        related_name="pc_builder_mapping"
    )

    component_type = models.CharField(
        max_length=30,
        choices=ComponentType.choices
    )

    def __str__(self):
        return (
            f"{self.category.name} - "
            f"{self.get_component_type_display()}"
        )


class PCBuild(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="pc_builds"
    )

    name = models.CharField(
        max_length=150,
        default="My PC Build"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.name} - {self.user}"


class PCBuildItem(models.Model):
    build = models.ForeignKey(
        PCBuild,
        on_delete=models.CASCADE,
        related_name="items"
    )

    component_type = models.CharField(
        max_length=30,
        choices=ComponentType.choices
    )

    variant = models.ForeignKey(
        ProductVariant,
        on_delete=models.PROTECT,
        related_name="pc_build_items"
    )

    quantity = models.PositiveIntegerField(
        default=1,
        validators=[MinValueValidator(1)]
    )

    class Meta:
        ordering = ["component_type"]
        constraints = [
            models.UniqueConstraint(
                fields=["build", "component_type"],
                name="unique_pc_build_component_type"
            )
        ]

    def clean(self):
        super().clean()

        if self.variant_id and self.component_type:
            valid_mapping = PCComponentCategory.objects.filter(
                category_id=self.variant.product.category_id,
                component_type=self.component_type
            ).exists()

            if not valid_mapping:
                raise ValidationError({
                    "variant": (
                        "This product category is not mapped "
                        "to the selected PC component type."
                    )
                })

    def __str__(self):
        return (
            f"{self.get_component_type_display()} - "
            f"{self.variant.product.name}"
        )
