"""Inspect the same relationship graph Django uses for admin deletions."""

from collections import Counter
from hashlib import sha256
import json

from django.contrib.admin.utils import NestedObjects
from django.db import router


class DeletionPlan:
    def __init__(self, record, user):
        database = router.db_for_write(type(record), instance=record)
        self.collector = NestedObjects(using=database, origin=record)
        self.collector.collect([record])
        self.changes = []
        self.missing_permissions = set()
        identities = {}

        for model, objects in self.collector.data.items():
            if not objects:
                continue
            meta = model._meta
            identities[meta.label_lower] = sorted(str(obj.pk) for obj in objects)
            label = str(meta.verbose_name_plural)
            if meta.auto_created:
                label = (
                    f"{meta.auto_created._meta.verbose_name} links ({meta.model_name})"
                )
            elif not user.has_perm(f"{meta.app_label}.delete_{meta.model_name}"):
                self.missing_permissions.add(label)
            self.changes.append(f"Delete {len(objects)} · {label}")

        # SET_NULL links survive deletion. Include them in the preview and stamp.
        for (field, value), groups in self.collector.field_updates.items():
            ids = {str(obj.pk) for group in groups for obj in group}
            if ids:
                identities[f"{field.model._meta.label_lower}.{field.name}"] = sorted(
                    ids
                )
                self.changes.append(
                    f"Update {field.name} on {len(ids)} · {field.model._meta.verbose_name_plural}"
                )

        self.token = sha256(json.dumps(identities, sort_keys=True).encode()).hexdigest()
        protected = Counter(
            str(obj._meta.verbose_name_plural) for obj in self.collector.protected
        )
        self.blockers = [
            f"Protected records: {count} · {name}"
            for name, count in sorted(protected.items())
        ]
        if self.missing_permissions:
            self.blockers.append(
                "Delete permission required for "
                + ", ".join(sorted(self.missing_permissions))
            )

    def summary(self):
        return {
            "changes": sorted(self.changes),
            "blockers": self.blockers,
            "token": self.token,
        }
