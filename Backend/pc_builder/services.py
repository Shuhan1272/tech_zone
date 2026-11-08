
import math
import re

from products.models import Product

from .models import ComponentType


# =========================================================
# REQUIRED PC COMPONENTS
# =========================================================

REQUIRED_COMPONENTS = (
    ComponentType.CPU,
    ComponentType.MOTHERBOARD,
    ComponentType.RAM,
    ComponentType.STORAGE,
    ComponentType.PSU,
    ComponentType.CASE,
)


# =========================================================
# NORMALIZE SPECIFICATION KEYS
# =========================================================

def _normalize(value):
    return re.sub(
        r"[^a-z0-9]",
        "",
        str(value).lower()
    )


# =========================================================
# FIND PRODUCT SPECIFICATION
# =========================================================

def find_specification(specification, *names):

    wanted = {
        _normalize(name)
        for name in names
    }

    def search(data):

        if isinstance(data, dict):

            for key, value in data.items():

                if _normalize(key) in wanted:

                    if isinstance(value, (str, int, float)):
                        return str(value)

                    if isinstance(value, list):
                        return ", ".join(map(str, value))

            for value in data.values():

                result = search(value)

                if result is not None:
                    return result

        elif isinstance(data, list):

            for value in data:

                result = search(value)

                if result is not None:
                    return result

        return None

    return search(specification)


# =========================================================
# EXTRACT CPU SOCKETS
# =========================================================

def extract_sockets(value):

    if not value:
        return set()

    matches = re.findall(
        r"\b(?:LGA[\s-]*\d{3,4}|AM[2345]|"
        r"STRX4|STR5|TR4|FM1|FM2)\b",
        str(value),
        re.IGNORECASE
    )

    return {
        re.sub(r"[\s-]", "", item).upper()
        for item in matches
    }


# =========================================================
# EXTRACT RAM GENERATION
# =========================================================

def extract_ram_types(value):

    if not value:
        return set()

    matches = re.findall(
        r"\bDDR[\s-]*[345]\b",
        str(value),
        re.IGNORECASE
    )

    return {
        re.sub(r"[\s-]", "", item).upper()
        for item in matches
    }


# =========================================================
# EXTRACT MOTHERBOARD FORM FACTORS
# =========================================================

def extract_form_factors(value):

    if not value:
        return set()

    text = str(value).upper()
    result = set()

    patterns = (
        (
            "e_atx",
            r"\b(?:E[\s-]*ATX|EXTENDED[\s-]*ATX)\b"
        ),
        (
            "micro_atx",
            r"\b(?:MICRO[\s-]*ATX|M[\s-]*ATX|MATX|UATX)\b"
        ),
        (
            "mini_itx",
            r"\b(?:MINI[\s-]*ITX|MITX|ITX)\b"
        ),
    )

    for name, pattern in patterns:

        if re.search(pattern, text):

            result.add(name)

            text = re.sub(
                pattern,
                " ",
                text
            )

    if re.search(r"\bATX\b", text):
        result.add("atx")

    return result


# =========================================================
# EXTRACT DIMENSIONS IN MILLIMETERS
# =========================================================

def extract_mm(value):

    if value is None:
        return None

    text = str(value).strip()

    match = re.search(
        r"(\d+(?:\.\d+)?)\s*(mm|cm)\b",
        text,
        re.IGNORECASE
    )

    if match:

        number = float(match.group(1))

        if match.group(2).lower() == "cm":
            return number * 10

        return number

    if re.fullmatch(r"\d+(?:\.\d+)?", text):
        return float(text)

    return None


# =========================================================
# EXTRACT WATTAGE
# =========================================================

def extract_watts(value):

    if value is None:
        return None

    text = str(value).strip()

    matches = re.findall(
        r"(\d+(?:\.\d+)?)\s*(?:w|watt|watts)\b",
        text,
        re.IGNORECASE
    )

    if matches:
        return max(
            float(number)
            for number in matches
        )

    if re.fullmatch(r"\d+(?:\.\d+)?", text):
        return float(text)

    return None


# =========================================================
# GET WATTAGE FROM SPECIFICATIONS
# =========================================================

def get_wattage(specification, *names):

    values = []

    for name in names:

        value = find_specification(
            specification,
            name
        )

        watts = extract_watts(value)

        if watts is not None:
            values.append(watts)

    return max(values) if values else None


# =========================================================
# CHECK PC BUILD COMPATIBILITY
# =========================================================

def check_compatibility(items):

    items = list(items)

    selected = {
        item.component_type: item
        for item in items
    }

    issues = []
    warnings = []
    checked_rules = []

    missing_required = [
        component
        for component in REQUIRED_COMPONENTS
        if component not in selected
    ]

    # =====================================================
    # GET SELECTED PRODUCTS
    # =====================================================

    def get_product(component_type):

        item = selected.get(component_type)

        if item:
            return item.variant.product

        return None

    def get_spec(component_type):

        product = get_product(component_type)

        if product:
            return product.specification or {}

        return {}

    cpu = get_product(ComponentType.CPU)
    motherboard = get_product(ComponentType.MOTHERBOARD)
    ram = get_product(ComponentType.RAM)
    gpu = get_product(ComponentType.GPU)
    psu = get_product(ComponentType.PSU)
    case = get_product(ComponentType.CASE)
    cooler = get_product(ComponentType.CPU_COOLER)

    cpu_spec = get_spec(ComponentType.CPU)
    motherboard_spec = get_spec(ComponentType.MOTHERBOARD)
    ram_spec = get_spec(ComponentType.RAM)
    gpu_spec = get_spec(ComponentType.GPU)
    psu_spec = get_spec(ComponentType.PSU)
    case_spec = get_spec(ComponentType.CASE)
    cooler_spec = get_spec(ComponentType.CPU_COOLER)

    # =====================================================
    # 1. PRODUCT AVAILABILITY AND STOCK
    # =====================================================

    for item in items:

        variant = item.variant
        product = variant.product

        if (
            not variant.is_active
            or not product.is_active
            or product.availability
            != Product.Availability.IN_STOCK
        ):
            issues.append(
                f"{product.name} is unavailable."
            )

        if variant.stock < item.quantity:
            issues.append(
                f"Insufficient stock for {product.name}."
            )

    # =====================================================
    # 2. CPU AND MOTHERBOARD SOCKET
    # =====================================================

    cpu_sockets = extract_sockets(
        find_specification(
            cpu_spec,
            "Socket",
            "Socket Type",
            "CPU Socket",
            "Processor Socket"
        )
    )

    if not cpu_sockets and cpu:
        cpu_sockets = extract_sockets(cpu.name)

    if cpu and motherboard:

        motherboard_sockets = extract_sockets(
            find_specification(
                motherboard_spec,
                "Socket",
                "Socket Type",
                "CPU Socket",
                "Processor Socket"
            )
        )

        if not motherboard_sockets:
            motherboard_sockets = extract_sockets(
                motherboard.name
            )

        if cpu_sockets and motherboard_sockets:

            checked_rules.append(
                "cpu_motherboard_socket"
            )

            if cpu_sockets.isdisjoint(
                motherboard_sockets
            ):
                issues.append(
                    "CPU and motherboard sockets do not match."
                )

        else:
            warnings.append(
                "CPU/motherboard socket could not be verified."
            )

    # =====================================================
    # 3. MOTHERBOARD AND RAM GENERATION
    # =====================================================

    if motherboard and ram:

        board_ram = extract_ram_types(
            find_specification(
                motherboard_spec,
                "Memory Type",
                "RAM Type",
                "Memory Support",
                "Memory Technology",
                "Supported Memory"
            )
        )

        ram_type = extract_ram_types(
            find_specification(
                ram_spec,
                "Memory Type",
                "RAM Type",
                "Memory Technology",
                "DDR Type"
            )
        )

        # FIX:
        # ProductVariant.options no longer exists.
        # Use product names as fallback.

        if not board_ram:
            board_ram = extract_ram_types(
                motherboard.name
            )

        if not ram_type:
            ram_type = extract_ram_types(
                ram.name
            )

        if board_ram and ram_type:

            checked_rules.append(
                "motherboard_ram_type"
            )

            if board_ram.isdisjoint(ram_type):

                issues.append(
                    "Motherboard and RAM generations do not match."
                )

        else:
            warnings.append(
                "Motherboard/RAM compatibility could not be verified."
            )

    # =====================================================
    # 4. MOTHERBOARD AND CASING FORM FACTOR
    # =====================================================

    if motherboard and case:

        board_forms = extract_form_factors(
            find_specification(
                motherboard_spec,
                "Form Factor",
                "Motherboard Form Factor"
            )
        )

        case_forms = extract_form_factors(
            find_specification(
                case_spec,
                "Motherboard Support",
                "Motherboard Compatibility",
                "Supported Motherboard",
                "Supported Motherboards",
                "Supported Form Factors",
                "Motherboard Form Factor"
            )
        )

        if not board_forms:
            board_forms = extract_form_factors(
                motherboard.name
            )

        sizes = {
            "mini_itx": 1,
            "micro_atx": 2,
            "atx": 3,
            "e_atx": 4,
        }

        if board_forms and case_forms:

            if board_forms.intersection(case_forms):

                checked_rules.append(
                    "motherboard_case_form_factor"
                )

            elif (
                min(sizes[name] for name in board_forms)
                > max(sizes[name] for name in case_forms)
            ):

                checked_rules.append(
                    "motherboard_case_form_factor"
                )

                issues.append(
                    "Motherboard is too large for the casing."
                )

            else:

                warnings.append(
                    "Motherboard form factor is not explicitly "
                    "listed as supported by the casing."
                )

        else:

            warnings.append(
                "Motherboard/casing form factor could not be verified."
            )

    # =====================================================
    # 5. GPU LENGTH AND CASING CLEARANCE
    # =====================================================

    if gpu and case:

        gpu_length = extract_mm(
            find_specification(
                gpu_spec,
                "GPU Length",
                "Graphics Card Length",
                "Card Length",
                "Length"
            )
        )

        case_gpu_clearance = extract_mm(
            find_specification(
                case_spec,
                "Max GPU Length",
                "Maximum GPU Length",
                "GPU Clearance",
                "Maximum Graphics Card Length",
                "Max VGA Length",
                "VGA Length"
            )
        )

        if (
            gpu_length is not None
            and case_gpu_clearance is not None
        ):

            checked_rules.append(
                "gpu_case_clearance"
            )

            if gpu_length > case_gpu_clearance:

                issues.append(
                    f"GPU length ({gpu_length:g} mm) exceeds "
                    f"casing clearance "
                    f"({case_gpu_clearance:g} mm)."
                )

        else:

            warnings.append(
                "GPU/casing clearance could not be verified."
            )

    # =====================================================
    # 6. CPU COOLER SOCKET
    # =====================================================

    if cpu and cooler:

        cooler_sockets = extract_sockets(
            find_specification(
                cooler_spec,
                "Supported Socket",
                "Supported Sockets",
                "Socket Support",
                "Compatible Sockets",
                "Socket Compatibility",
                "CPU Socket",
                "Compatibility"
            )
        )

        if cpu_sockets and cooler_sockets:

            checked_rules.append(
                "cpu_cooler_socket"
            )

            if cpu_sockets.isdisjoint(
                cooler_sockets
            ):

                issues.append(
                    "CPU cooler does not support the CPU socket."
                )

        else:

            warnings.append(
                "CPU cooler socket compatibility could not be verified."
            )

    # =====================================================
    # 7. CPU COOLER HEIGHT AND CASING CLEARANCE
    # =====================================================

    if cooler and case:

        cooler_height = extract_mm(
            find_specification(
                cooler_spec,
                "Cooler Height",
                "Height"
            )
        )

        case_cooler_clearance = extract_mm(
            find_specification(
                case_spec,
                "Maximum CPU Cooler Height",
                "Max CPU Cooler Height",
                "CPU Cooler Clearance",
                "Max Cooler Height",
                "Cooler Height Support"
            )
        )

        if (
            cooler_height is not None
            and case_cooler_clearance is not None
        ):

            checked_rules.append(
                "cpu_cooler_case_clearance"
            )

            if cooler_height > case_cooler_clearance:

                issues.append(
                    f"CPU cooler height ({cooler_height:g} mm) "
                    f"exceeds casing clearance "
                    f"({case_cooler_clearance:g} mm)."
                )

        else:

            warnings.append(
                "CPU cooler/casing clearance could not be verified."
            )

    # =====================================================
    # 8. PSU WATTAGE
    # =====================================================

    if psu:

        psu_watts = get_wattage(
            psu_spec,
            "Rated Power",
            "Continuous Power",
            "Output Power",
            "Wattage",
            "Total Power",
            "Power"
        )

        cpu_watts = get_wattage(
            cpu_spec,
            "Max Turbo Power",
            "Maximum Turbo Power",
            "Processor Base Power",
            "TDP",
            "Thermal Design Power",
            "Power Consumption"
        )

        gpu_watts = get_wattage(
            gpu_spec,
            "Total Board Power",
            "Board Power",
            "TBP",
            "TGP",
            "Graphics Power",
            "Power Consumption",
            "TDP"
        )

        gpu_recommended_psu = get_wattage(
            gpu_spec,
            "Recommended PSU",
            "Recommended Power Supply",
            "Minimum PSU",
            "Minimum Power Supply",
            "PSU Requirement"
        )

        if (
            gpu
            and gpu_recommended_psu is not None
            and psu_watts is not None
        ):

            checked_rules.append(
                "gpu_recommended_psu"
            )

            if psu_watts < gpu_recommended_psu:

                issues.append(
                    f"GPU recommends at least "
                    f"{gpu_recommended_psu:g}W PSU, "
                    f"but selected PSU is {psu_watts:g}W."
                )

        if (
            cpu
            and cpu_watts is not None
            and (not gpu or gpu_watts is not None)
            and psu_watts is not None
        ):

            # Approximate additional consumption: 75W
            # Estimated safety headroom: 25%

            estimated_watts = math.ceil(
                (
                    cpu_watts
                    + (gpu_watts or 0)
                    + 75
                ) * 1.25
            )

            checked_rules.append(
                "estimated_psu_wattage"
            )

            if psu_watts < estimated_watts:

                issues.append(
                    f"Estimated PSU requirement is "
                    f"{estimated_watts}W, but selected "
                    f"PSU is {psu_watts:g}W."
                )

        elif cpu:

            warnings.append(
                "PSU wattage could not be fully estimated "
                "because power specifications are missing."
            )

    # =====================================================
    # 9. FINAL COMPATIBILITY RESULT
    # =====================================================

    if issues:
        result_status = "incompatible"

    elif warnings or missing_required:
        result_status = "not_fully_verified"

    else:
        result_status = "checks_passed"

    return {
        "status": result_status,
        "issues": issues,
        "warnings": warnings,
        "missing_required": missing_required,
        "checked_rules": checked_rules,
        "note": (
            "Compatibility checks are advisory and depend "
            "on accurate product specifications. PSU calculations "
            "are estimates. Other constraints such as BIOS support, "
            "connectors, PCIe slots, storage interfaces and "
            "thermal performance are not fully verified."
        ),
    }
