"""Small operational counts, always scoped to the operator's permissions."""

from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group
from django.db.models import Q

from .resources import permitted, resources


def workspace_insights(user):
    summary = {}
    alerts = []
    rules = [
        (
            "orders",
            "pending_orders",
            "Orders awaiting confirmation",
            Q(status="pending"),
            "status=pending",
        ),
        (
            "variants",
            "low_stock",
            "Variants running low",
            Q(stock__range=(1, 5)),
            "inventory=low",
        ),
        (
            "variants",
            "out_of_stock",
            "Variants out of stock",
            Q(stock=0),
            "inventory=out",
        ),
        (
            "reviews",
            "pending_reviews",
            "Reviews awaiting approval",
            Q(is_approved=False),
            "is_approved=0",
        ),
        (
            "questions",
            "unanswered_questions",
            "Questions awaiting an answer",
            Q(answer="") | Q(answer__isnull=True),
            "unanswered=1",
        ),
        (
            "refunds",
            "pending_refunds",
            "Refunds awaiting review",
            Q(status="requested"),
            "status=requested",
        ),
        (
            "payments",
            "review_payments",
            "Payments needing review",
            Q(status="review"),
            "status=review",
        ),
    ]
    for key, metric, title, query, query_filter in rules:
        resource = resources[key]
        if not permitted(user, resource):
            continue
        count = resource.model.objects.filter(query).count()
        summary[metric] = count
        if count:
            alerts.append(
                {"key": key, "title": title, "count": count, "filter": query_filter}
            )
    if user.is_superuser:
        staff = get_user_model().objects.filter(is_staff=True)
        summary.update(
            active_staff=staff.filter(is_active=True).count(),
            inactive_staff=staff.filter(is_active=False).count(),
            roles=Group.objects.count(),
        )
    return {"summary": summary, "alerts": alerts}


def collection_summary(key):
    model = resources[key].model
    if key == "team":
        staff = model.objects.filter(is_staff=True, is_superuser=False)
        return {
            "total": staff.count(),
            "active": staff.filter(is_active=True).count(),
            "inactive": staff.filter(is_active=False).count(),
            "roles": Group.objects.count(),
        }
    if key == "roles":
        return {
            "total": model.objects.count(),
            "assigned": model.objects.filter(user__is_staff=True).distinct().count(),
        }
    return {}
