import re
from django import forms
from django.forms import modelform_factory
from django.contrib.auth.password_validation import validate_password
from django.contrib.auth.models import Permission
from django.db.models import Q

from .resources import assignable_permissions


class ConsoleForm(forms.ModelForm):
    def clean(self):
        data = super().clean()
        start = data.get("start_date") or data.get("start_at")
        end = data.get("end_date") or data.get("end_at")
        if start and end and start >= end:
            raise forms.ValidationError("End time must be later than start time.")
        for field in ("value", "minimum_order_amount", "max_discount"):
            if data.get(field) is not None and data[field] < 0:
                self.add_error(field, "Enter a non-negative amount.")
        if data.get("value_type") == "percentage" and (data.get("value") or 0) > 100:
            self.add_error("value", "Percentage must be at most 100.")
        if "code" in data and data.get("discount_type") == "promo" and not data["code"]:
            self.add_error("code", "A promo discount needs a code.")
        if "hex_code" in data and not re.fullmatch(r"#[\da-fA-F]{6}", data["hex_code"]):
            self.add_error("hex_code", "Use a six-digit hex color such as #2563EB.")
        parent = data.get("parent")
        seen = {self.instance.pk}
        while parent:
            if parent.pk in seen:
                self.add_error(
                    "parent", "Choose a parent outside this category's descendants."
                )
                break
            seen.add(parent.pk)
            parent = parent.parent
        return data


class StaffForm(ConsoleForm):
    new_password = forms.CharField(
        label="New password",
        required=False,
        strip=False,
        widget=forms.PasswordInput(attrs={"autocomplete": "new-password"}),
        help_text="Required for new staff. Leave blank to keep the current password.",
    )

    def clean(self):
        data = super().clean()
        password = data.get("new_password")
        if password:
            for name in ("email", "first_name", "last_name"):
                setattr(self.instance, name, data.get(name, ""))
            try:
                validate_password(password, self.instance)
            except forms.ValidationError as exc:
                self.add_error("new_password", exc)
        elif not self.instance.pk:
            self.add_error("new_password", "Enter an initial password.")
        return data

    def save(self, commit=True):
        self.instance.is_staff = True
        self.instance.role = "admin"
        if self.cleaned_data.get("new_password"):
            self.instance.set_password(self.cleaned_data["new_password"])
        return super().save(commit=commit)


class PermissionChoices(forms.ModelMultipleChoiceField):
    def label_from_instance(self, permission):
        action = permission.codename.split("_", 1)[0]
        return f"{permission.content_type.name.title()} · {action.title()}"


def permission_field(instance, name):
    """Keep previously assigned permissions visible when editing legacy roles."""
    allowed = assignable_permissions()
    if instance and instance.pk:
        selected = getattr(instance, name).values_list("pk", flat=True)
        allowed = (
            Permission.objects.filter(
                Q(pk__in=allowed.values("pk")) | Q(pk__in=selected)
            )
            .select_related("content_type")
            .order_by("content_type__app_label", "content_type__model", "codename")
        )
    return PermissionChoices(
        queryset=allowed,
        required=False,
        label="Direct permissions" if name == "user_permissions" else "Permissions",
        help_text=(
            "Choose the actions this role can perform. Administrative access stays owner-only."
            if name == "permissions"
            else "Optional permissions added to those inherited from assigned roles."
        ),
    )


def form_for(resource, **kwargs):
    klass = modelform_factory(
        resource.model,
        form=StaffForm if resource.title == "Staff accounts" else ConsoleForm,
        fields=resource.edit.split(),
    )
    form = klass(**kwargs)
    for name in ("permissions", "user_permissions"):
        if name in form.fields:
            original = form.fields[name]
            form.fields[name] = permission_field(form.instance, name)
            form.fields[name].initial = original.initial
    if "groups" in form.fields:
        form.fields["groups"].label = "Roles"
        form.fields["groups"].help_text = (
            "Permissions from all selected roles are combined."
        )
    for field in form.fields.values():
        if isinstance(field, forms.DateTimeField):
            field.widget = forms.DateTimeInput(
                format="%Y-%m-%dT%H:%M", attrs={"type": "datetime-local"}
            )
    return form
