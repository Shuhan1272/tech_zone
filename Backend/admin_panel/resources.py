"""Explicit inventory of fields the operations console may read and change."""

from dataclasses import dataclass
from django.apps import apps
from django.contrib.auth.models import Permission


@dataclass
class Resource:
    model_name: str
    group: str
    title: str
    columns: str
    search: str = ""
    edit: str = ""
    extra: str = ""
    create: bool = False
    delete: bool = True

    @property
    def model(self):
        return apps.get_model(self.model_name)


resources = {
    "orders": Resource(
        "order.Order",
        "Commerce",
        "Orders",
        "shipping_name status payment_status total_amount",
        "shipping_name shipping_phone user__email",
        extra="user payment_method subtotal discount_amount discount_code shipping_phone shipping_address shipping_house shipping_road shipping_division shipping_district shipping_upazila shipping_postal_code shipping_instructions created_at",
        delete=False,
    ),
    "payments": Resource(
        "payments.Payment",
        "Commerce",
        "Payments",
        "transaction_id order status amount",
        "transaction_id order__shipping_name",
        extra="currency payment_method bank_transaction_id risk_level review_reason created_at",
        delete=False,
    ),
    "refunds": Resource(
        "payments.PaymentRefund",
        "Commerce",
        "Refunds",
        "payment status amount created_at",
        "payment__transaction_id reason",
        extra="reason admin_note reviewed_by reviewed_at refund_reference_id failure_reason",
        delete=False,
    ),
    "products": Resource(
        "products.Product",
        "Catalog",
        "Products",
        "name category availability is_active",
        "name slug",
        "name category brand availability description key_feature specification is_active is_featured",
        "slug",
        True,
    ),
    "variants": Resource(
        "products.ProductVariant",
        "Catalog",
        "Inventory",
        "sku stock price is_active",
        "sku product__name",
        "product ram storage color price discount_percentage stock is_default is_active",
        create=True,
    ),
    "categories": Resource(
        "products.Category",
        "Catalog",
        "Categories",
        "name parent is_active is_featured",
        "name",
        "name parent description filters image is_active is_featured",
        create=True,
    ),
    "brands": Resource(
        "products.Brand",
        "Catalog",
        "Brands",
        "name is_active",
        "name",
        "name categories description image is_active",
        create=True,
    ),
    "images": Resource(
        "products.ProductImage",
        "Catalog",
        "Product images",
        "product alt_text is_primary display_order",
        "product__name alt_text",
        "product image alt_text is_primary display_order",
        create=True,
    ),
    "colors": Resource(
        "products.Color",
        "Catalog",
        "Colors",
        "name hex_code is_active",
        "name hex_code",
        "name hex_code is_active",
        create=True,
    ),
    "discounts": Resource(
        "discounts.Discount",
        "Merchandising",
        "Discounts",
        "name code used_count is_active",
        "name code",
        "name discount_type code value_type value max_discount minimum_order_amount usage_limit start_date end_date is_active",
        create=True,
    ),
    "notices": Resource(
        "core.Notice",
        "Merchandising",
        "Notices",
        "title notice_type is_active is_featured",
        "title message",
        "title message notice_type is_active is_featured start_at end_at",
        create=True,
    ),
    "reviews": Resource(
        "products.ProductReview",
        "Community",
        "Reviews",
        "product user rating is_approved",
        "product__name user__email review",
        "is_approved",
        "review created_at",
    ),
    "questions": Resource(
        "products.ProductQuestion",
        "Community",
        "Questions",
        "product question is_approved",
        "product__name question",
        "answer is_approved",
        "user created_at",
    ),
    "customers": Resource(
        "accounts.User",
        "Community",
        "Customers",
        "email first_name is_active date_joined",
        "email first_name last_name phone",
        "is_active",
        "last_name phone is_email_verified",
    ),
    "addresses": Resource(
        "accounts.Address",
        "Community",
        "Addresses",
        "user city region country",
        "user__email city",
        extra="first_name last_name company address1 address2 postal_code",
    ),
    "carts": Resource(
        "cart.Cart", "Community", "Carts", "user updated_at", "user__email"
    ),
    "wishlists": Resource(
        "wishlist.Wishlist",
        "Community",
        "Wishlists",
        "user is_public updated_at",
        "user__email",
    ),
    "mappings": Resource(
        "pc_builder.PCComponentCategory",
        "PC builder",
        "Component mappings",
        "category component_type",
        "category__name",
        "category component_type",
        create=True,
    ),
    "builds": Resource(
        "pc_builder.PCBuild",
        "PC builder",
        "Saved builds",
        "name user updated_at",
        "name user__email",
    ),
    "team": Resource(
        "accounts.User",
        "Administration",
        "Staff accounts",
        "email first_name last_name is_active groups last_login",
        "email first_name last_name phone",
        "email first_name last_name phone is_active groups user_permissions",
        create=True,
        delete=False,
    ),
    "roles": Resource(
        "auth.Group",
        "Administration",
        "Roles & permissions",
        "name permissions",
        "name",
        "name permissions",
        create=True,
    ),
    "activity": Resource(
        "admin.LogEntry",
        "Administration",
        "Activity log",
        "user object_repr action_flag action_time",
        "user__email object_repr change_message",
        extra="content_type object_id change_message",
        delete=False,
    ),
}


def permitted(user, resource, action="view"):
    if not user.is_authenticated or not user.is_active or not user.is_staff:
        return False
    if action == "delete" and not resource.delete:
        return False
    if resource.group == "Administration":
        return user.is_superuser
    opts = resource.model._meta
    return user.has_perm(f"{opts.app_label}.{action}_{opts.model_name}")


def assignable_permissions():
    """Only business-model permissions belong in delegated console roles.

    Account administration, role management and audit history stay owner-only.
    Django's system permissions are deliberately excluded from the picker.
    """
    labels = {}
    for key, resource in resources.items():
        if resource.group == "Administration":
            continue
        allowed = {"view"}
        if resource.create:
            allowed.add("add")
        if resource.edit or key in {"orders", "payments", "refunds"}:
            allowed.add("change")
        if resource.delete:
            allowed.add("delete")
        opts = resource.model._meta
        labels[(opts.app_label, opts.model_name)] = allowed
    ids = [
        permission.pk
        for permission in Permission.objects.select_related("content_type")
        if (permission.content_type.app_label, permission.content_type.model) in labels
        and permission.codename.split("_", 1)[0]
        in labels[(permission.content_type.app_label, permission.content_type.model)]
    ]
    return (
        Permission.objects.filter(pk__in=ids)
        .select_related("content_type")
        .order_by("content_type__app_label", "content_type__model", "codename")
    )


def queryset(key):
    qs = resources[key].model.objects.all()
    if key == "team":
        qs = qs.filter(is_staff=True, is_superuser=False)
    if key == "customers":
        qs = qs.filter(is_staff=False, is_superuser=False, role="customer")
    if key in {"team", "roles"}:
        qs = (
            qs.prefetch_related("groups", "user_permissions")
            if key == "team"
            else qs.prefetch_related("permissions", "user_set")
        )
    return qs.select_related().order_by("-pk")
