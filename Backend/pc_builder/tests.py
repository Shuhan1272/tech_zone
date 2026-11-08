
from types import SimpleNamespace

from django.test import SimpleTestCase

from products.models import Product

from .models import ComponentType
from .services import check_compatibility


def make_component(component_type, specification):
    product = SimpleNamespace(
        name=component_type,
        specification=specification,
        is_active=True,
        availability=Product.Availability.IN_STOCK,
    )

    variant = SimpleNamespace(
        product=product,
        is_active=True,
        stock=10,
        options={},
    )

    return SimpleNamespace(
        component_type=component_type,
        variant=variant,
        quantity=1,
    )


def sample_build():
    return [
        make_component(
            ComponentType.CPU,
            {"Socket": "AM5", "Max Turbo Power": "120W"}
        ),
        make_component(
            ComponentType.MOTHERBOARD,
            {
                "Socket": "AM5",
                "Memory Type": "DDR5",
                "Form Factor": "ATX",
            }
        ),
        make_component(
            ComponentType.RAM,
            {"Memory Type": "DDR5"}
        ),
        make_component(ComponentType.STORAGE, {}),
        make_component(
            ComponentType.PSU,
            {"Rated Power": "750W"}
        ),
        make_component(
            ComponentType.CASE,
            {
                "Motherboard Support": "ATX, Micro-ATX",
                "Max GPU Length": "340mm",
                "Max CPU Cooler Height": "160mm",
            }
        ),
        make_component(
            ComponentType.GPU,
            {
                "GPU Length": "300mm",
                "Total Board Power": "250W",
                "Recommended PSU": "650W",
            }
        ),
        make_component(
            ComponentType.CPU_COOLER,
            {
                "Supported Sockets": "AM5, LGA1700",
                "Height": "155mm",
            }
        ),
    ]


class PCCompatibilityTests(SimpleTestCase):

    def test_compatible_build(self):
        report = check_compatibility(sample_build())

        self.assertEqual(report["status"], "checks_passed")
        self.assertEqual(report["issues"], [])
        self.assertEqual(report["missing_required"], [])

    def test_incompatible_build(self):
        items = sample_build()

        items[1].variant.product.specification["Socket"] = "LGA1700"
        items[2].variant.product.specification["Memory Type"] = "DDR4"
        items[4].variant.product.specification["Rated Power"] = "450W"
        items[5].variant.product.specification["Max GPU Length"] = "250mm"
        items[7].variant.product.specification["Height"] = "170mm"

        report = check_compatibility(items)

        self.assertEqual(report["status"], "incompatible")
        self.assertGreaterEqual(len(report["issues"]), 4)

    def test_missing_specifications(self):
        items = sample_build()

        items[0].variant.product.specification.pop("Socket")
        items[1].variant.product.specification.pop("Memory Type")

        report = check_compatibility(items)

        self.assertEqual(
            report["status"],
            "not_fully_verified"
        )
        self.assertTrue(report["warnings"])
