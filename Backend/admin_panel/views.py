"""Authenticated operations for the TechZone administration workspace."""

import hashlib
import json
from collections import defaultdict
from datetime import timedelta
from decimal import Decimal

from django.contrib.admin.models import ADDITION, CHANGE, DELETION, LogEntry
from django.contrib.auth import authenticate
from django.contrib.auth.models import Group
from django.contrib.contenttypes.models import ContentType
from django.core.exceptions import ValidationError as DjangoError
from django.core.paginator import Paginator
from django.db import IntegrityError, models, transaction
from django.db.models import Count, Q, Sum
from django.db.models.functions import TruncDate
from django.http import Http404
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle
from rest_framework_simplejwt.tokens import AccessToken

from order.models import Order, OrderItem
from payments.services import GatewayError

from .deletion import DeletionPlan
from .forms import form_for
from .insights import collection_summary, workspace_insights
from .operations import actions, execute
from .permissions import IsActiveStaff
from .resources import assignable_permissions, permitted, queryset, resources


class LoginThrottle(AnonRateThrottle):
    rate = "15/min"


@api_view(["POST"])
@permission_classes([AllowAny])
@throttle_classes([LoginThrottle])
def login(request):
    user = authenticate(
        request,
        email=request.data.get("email"),
        password=request.data.get("password"),
    )
    if not user or not user.is_active or not user.is_staff:
        return Response(
            {"detail": "Sign-in failed. Use an active staff account."}, status=403
        )
    token = AccessToken.for_user(user)
    token.set_exp(lifetime=timedelta(hours=1))
    user.last_login = timezone.now()
    user.save(update_fields=["last_login"])
    audit(user, user, CHANGE, "Signed in to the administration workspace")
    return Response({"token": str(token)})


def resource_for(key, user):
    if key not in resources:
        raise Http404
    resource = resources[key]
    if not permitted(user, resource):
        raise PermissionDenied()
    return resource


@api_view(["GET"])
@permission_classes([IsActiveStaff])
def workspace(request):
    user = request.user
    sections = [
        {"key": key, "title": resource.title, "group": resource.group}
        for key, resource in resources.items()
        if permitted(user, resource)
    ]
    return Response(
        {
            "email": user.email,
            "name": user.get_full_name() or user.email.split("@", 1)[0],
            "is_superuser": user.is_superuser,
            "role": "Workspace owner" if user.is_superuser else "Staff member",
            "can_overview": permitted(user, resources["orders"]),
            "sections": sections,
            **workspace_insights(user),
        }
    )


@api_view(["GET"])
@permission_classes([IsActiveStaff])
def permission_catalog(request):
    resource_for("roles", request.user)
    grouped = defaultdict(list)
    for permission in assignable_permissions():
        content_type = permission.content_type
        resource_key = next(
            key
            for key, resource in resources.items()
            if resource.group != "Administration"
            and resource.model._meta.label_lower
            == f"{content_type.app_label}.{content_type.model}"
        )
        resource = resources[resource_key]
        action = permission.codename.split("_", 1)[0]
        grouped[resource.group].append(
            {
                "id": permission.pk,
                "name": f"{resource.title} · {action.title()}",
                "codename": f"{content_type.app_label}.{permission.codename}",
                "action": action,
                "resource": resource_key,
            }
        )
    return Response(
        {
            "groups": [
                {
                    "key": title.lower().replace(" ", "-"),
                    "title": title,
                    "permissions": permissions,
                }
                for title, permissions in grouped.items()
            ]
        }
    )


def values(obj, fields):
    result = {"id": obj.pk}
    for name in fields.split():
        field = obj._meta.get_field(name)
        value = getattr(obj, name)
        if field.many_to_many:
            value = ", ".join(str(item) for item in value.all())
        elif isinstance(field, models.FileField):
            value = value.url if value else None
        elif field.is_relation and value is not None:
            value = str(value)
        result[name] = value
    return result


def version(obj, resource):
    raw = {field.attname: getattr(obj, field.attname) for field in obj._meta.fields}
    for field in obj._meta.many_to_many:
        if field.name in resource.edit.split():
            raw[field.name] = list(
                getattr(obj, field.name).order_by("pk").values_list("pk", flat=True)
            )
    return hashlib.sha256(
        json.dumps(raw, default=str, sort_keys=True).encode()
    ).hexdigest()


def audit(user, obj, flag, message):
    LogEntry.objects.create(
        user=user,
        content_type=ContentType.objects.get_for_model(obj),
        object_id=str(obj.pk),
        object_repr=str(obj)[:200],
        action_flag=flag,
        change_message=message,
    )


def filtered_records(request, key, resource):
    records = queryset(key)
    term = request.query_params.get("q", "").strip()[:200]
    if term:
        search = Q(pk__isnull=True)
        if term.isascii() and term.isdigit() and len(term) < 19:
            search = Q(pk=int(term))
        for name in resource.search.split():
            search |= Q(**{name + "__icontains": term})
        records = records.filter(search)

    filters = {}
    if key == "variants":
        filters["inventory"] = [("low", "Low stock (1–5)"), ("out", "Out of stock")]
        stock = request.query_params.get("inventory")
        if stock == "low":
            records = records.filter(stock__range=(1, 5))
        elif stock == "out":
            records = records.filter(stock=0)
    if key == "questions":
        filters["unanswered"] = [("1", "Awaiting answer"), ("0", "Answered")]
        unanswered = Q(answer="") | Q(answer__isnull=True)
        if request.query_params.get("unanswered") == "1":
            records = records.filter(unanswered)
        elif request.query_params.get("unanswered") == "0":
            records = records.exclude(unanswered)
    if key == "team":
        filters["group"] = list(
            Group.objects.order_by("name").values_list("pk", "name")
        )
        selected_role = request.query_params.get("group")
        if selected_role and selected_role.isascii() and selected_role.isdigit():
            records = records.filter(groups__pk=selected_role)
    sortable = []
    for name in resource.columns.split():
        field = resource.model._meta.get_field(name)
        if not field.many_to_many:
            sortable.append(name)
        if field.choices:
            filters[name] = list(field.choices)
        elif isinstance(field, models.BooleanField):
            filters[name] = (
                [("1", "Active"), ("0", "Suspended")]
                if key == "team" and name == "is_active"
                else [("1", "Yes"), ("0", "No")]
            )
        choices = {str(value) for value, _label in filters.get(name, [])}
        selected = request.query_params.get(name)
        if selected in choices:
            records = records.filter(**{name: selected})
    ordering = request.query_params.get("ordering", "-id")
    if ordering.lstrip("-") not in sortable + ["id"]:
        ordering = "-id"
    records = records.order_by(ordering, "-pk")
    return records, filters, sortable, ordering


@api_view(["GET"])
@permission_classes([IsActiveStaff])
def listing(request, key):
    resource = resource_for(key, request.user)
    records, filters, sortable, ordering = filtered_records(request, key, resource)
    page_size = {"20": 20, "50": 50, "100": 100}.get(
        request.query_params.get("page_size"), 20
    )
    page = Paginator(records, page_size).get_page(request.query_params.get("page"))
    rows = [values(obj, resource.columns) for obj in page]
    if key == "roles":
        for obj, row in zip(page.object_list, rows):
            row.update(
                member_count=obj.user_set.count(),
                permission_count=obj.permissions.count(),
            )
    return Response(
        {
            "columns": resource.columns.split(),
            "filters": filters,
            "rows": rows,
            "page": page.number,
            "pages": page.paginator.num_pages,
            "count": page.paginator.count,
            "page_size": page_size,
            "ordering": ordering,
            "sortable": sortable,
            "summary": collection_summary(key),
            "create": resource.create and permitted(request.user, resource, "add"),
        }
    )


def deletion_plan(obj, user, key):
    plan = DeletionPlan(obj, user)
    if key == "roles" and obj.user_set.exists():
        plan.blockers.append(
            "This role is assigned to accounts. Reassign those accounts before deleting it."
        )
    return plan


def record_details(obj, resource, key, user, write, remove):
    fields = " ".join(
        dict.fromkeys(
            (resource.columns + " " + resource.extra + " " + resource.edit).split()
        )
    )
    detail = values(obj, fields) if obj else {}
    item_fields = {
        "orders": "product_name sku ram storage color_name quantity unit_price line_total",
        "carts": "variant quantity",
        "wishlists": "variant",
        "builds": "component_type variant quantity",
    }
    items = []
    if obj and key in item_fields:
        items = [
            values(item, item_fields[key]) for item in obj.items.select_related().all()
        ]
    response = {
        "data": detail,
        "version": version(obj, resource) if obj else "",
        "items": items,
        "delete": remove,
        "deletion": deletion_plan(obj, user, key).summary() if remove else None,
        "form": form_for(resource, instance=obj).as_div() if write else "",
        "actions": (
            actions(key, obj) if obj and permitted(user, resource, "change") else []
        ),
    }
    if obj and key == "team":
        response["access"] = {
            "groups": list(obj.groups.order_by("name").values("id", "name")),
            "direct_permissions": list(
                obj.user_permissions.values_list("pk", flat=True)
            ),
            "effective_permissions": sorted(obj.get_all_permissions()),
            "last_login": obj.last_login,
            "date_joined": obj.date_joined,
        }
    if obj and key == "roles":
        response["members"] = list(
            obj.user_set.order_by("email").values(
                "id", "email", "is_active", "is_staff"
            )
        )
    return response


@api_view(["GET", "POST", "DELETE"])
@permission_classes([IsActiveStaff])
def record(request, key, pk=None):
    user = request.user
    resource = resource_for(key, user)
    write = bool(
        permitted(user, resource, "change" if pk else "add")
        and resource.edit
        and (pk or resource.create)
    )
    remove = bool(pk and permitted(user, resource, "delete"))
    if not pk and not write:
        raise PermissionDenied()
    with transaction.atomic():
        obj = (
            get_object_or_404(queryset(key).select_for_update(), pk=pk) if pk else None
        )
        if request.method == "GET":
            return Response(record_details(obj, resource, key, user, write, remove))
        if not (remove if request.method == "DELETE" else write):
            raise PermissionDenied()
        if pk and version(obj, resource) != request.headers.get("X-Record-Version"):
            return Response(
                {
                    "detail": "This record changed. Close and reopen it to see the latest values."
                },
                status=409,
            )
        if request.method == "DELETE":
            plan = deletion_plan(obj, user, key)
            if plan.blockers:
                return Response({"detail": ". ".join(plan.blockers)}, status=409)
            if plan.token != request.headers.get("X-Deletion-Token"):
                return Response(
                    {
                        "detail": "Related records changed. Reopen the record to review the deletion."
                    },
                    status=409,
                )
            try:
                with transaction.atomic():
                    audit(user, obj, DELETION, "Removed in TechZone console")
                    plan.collector.delete()
            except IntegrityError:
                return Response(
                    {
                        "detail": "A related record prevents deletion. Reopen the record to review."
                    },
                    status=409,
                )
            return Response(status=204)
        form = form_for(resource, instance=obj, data=request.data, files=request.FILES)
        if not form.is_valid():
            return Response(form.errors, status=400)
        try:
            with transaction.atomic():
                saved = form.save()
                audit(
                    user,
                    saved,
                    CHANGE if pk else ADDITION,
                    "Updated " + ", ".join(form.changed_data),
                )
        except IntegrityError:
            raise ValidationError("This change conflicts with another record.")
        return Response({"id": saved.pk})


@api_view(["POST"])
@permission_classes([IsActiveStaff])
def operation(request, key, pk):
    resource = resource_for(key, request.user)
    if not permitted(request.user, resource, "change"):
        raise PermissionDenied()
    with transaction.atomic():
        obj = get_object_or_404(queryset(key).select_for_update(), pk=pk)
        stamp = request.headers.get("X-Record-Version")
        if (stamp or key == "team") and stamp != version(obj, resource):
            return Response(
                {
                    "detail": "This record changed. Reopen it before applying this action."
                },
                status=409,
            )
        action = request.data.get("action")
        if action not in actions(key, obj):
            raise ValidationError("This action is unavailable for the current status.")
        note = str(request.data.get("note", "")).strip()[:2000]
        if key in {"team", "orders"}:
            execute_action(key, obj, action, request.user, note)
            return Response({"ok": True})
    # Gateway services manage their own short transactions. Do not hold a
    # database lock open while they contact the external payment provider.
    execute_action(key, obj, action, request.user, note)
    return Response({"ok": True})


def execute_action(key, obj, action, user, note):
    try:
        execute(key, obj, action, user, note)
    except (DjangoError, GatewayError) as exc:
        raise ValidationError(
            " ".join(exc.messages) if isinstance(exc, DjangoError) else str(exc)
        )
    audit(user, obj, CHANGE, action.replace("_", " ").capitalize())


@api_view(["GET"])
@permission_classes([IsActiveStaff])
def overview(request):
    resource_for("orders", request.user)
    days = {"7": 7, "30": 30, "90": 90}.get(request.query_params.get("days"), 30)
    today = timezone.localdate()
    start = today - timedelta(days=days - 1)
    orders = Order.objects.filter(created_at__date__range=(start, today))
    paid = orders.filter(payment_status="paid").exclude(status="cancelled")
    daily = {
        row["day"]: row["total"]
        for row in paid.annotate(day=TruncDate("created_at"))
        .values("day")
        .annotate(total=Sum("total_amount"))
    }
    total = sum(daily.values(), Decimal(0))
    count = paid.count()
    states = dict(orders.values_list("status").annotate(n=Count("pk")).order_by())
    sellers = (
        OrderItem.objects.filter(order__in=paid)
        .values("product_name")
        .annotate(units=Sum("quantity"))
        .order_by("-units", "product_name")[:5]
    )
    return Response(
        {
            "sellers": list(sellers),
            "revenue": total,
            "orders": orders.count(),
            "average": total / count if count else 0,
            "pending": states.get("pending", 0),
            "states": states,
            "series": [
                {"date": day.isoformat(), "value": daily.get(day, 0)}
                for day in (start + timedelta(days=index) for index in range(days))
            ],
            "recent": [
                values(
                    order, "shipping_name status payment_status total_amount created_at"
                )
                for order in orders.order_by("-pk")[:6]
            ],
            **workspace_insights(request.user),
        }
    )
