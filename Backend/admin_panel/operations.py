from order.admin import change_order_status
from order.services import confirm_cod_payment
from payments import services


def actions(key, record):
    if key == "team":
        return ["deactivate_staff"] if record.is_active else ["activate_staff"]
    if key == "orders":
        steps = {
            "pending": ["confirmed", "cancelled"],
            "confirmed": ["shipped", "cancelled"],
            "shipped": ["delivered"],
        }
        result = list(steps.get(record.status, []))
        if (
            record.payment_method == "cod"
            and record.status == "delivered"
            and record.payment_status == "pending"
        ):
            result.append("collect_cod")
        return result
    if key == "payments":
        return {
            "paid": ["request_refund"],
            "review": ["approve_payment"],
            "refunded": [],
        }.get(record.status, ["verify_payment"])
    if key == "refunds":
        return {
            "requested": ["approve_refund", "reject_refund"],
            "approved": ["process_refund", "reject_refund"],
            "processing": ["verify_refund"],
        }.get(record.status, [])
    return []


def execute(key, obj, action, user, note):
    if key == "team":
        obj.is_active = action == "activate_staff"
        obj.save(update_fields=["is_active"])
        return obj
    if key == "orders":
        return (
            confirm_cod_payment(obj.pk)
            if action == "collect_cod"
            else change_order_status(obj.pk, action)
        )
    handlers = {
        "request_refund": lambda: services.request_full_refund(obj.pk, note),
        "approve_payment": lambda: services.approve_reviewed_payment(obj.pk),
        "verify_payment": lambda: services.reconcile_gateway_payment(obj),
        "approve_refund": lambda: services.approve_refund_request(obj.pk, user, note),
        "reject_refund": lambda: services.reject_refund_request(obj.pk, user, note),
        "process_refund": lambda: services.process_approved_refund(obj.pk, user),
        "verify_refund": lambda: services.check_gateway_refund(obj),
    }
    return handlers[action]()
