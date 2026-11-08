
from django.contrib import admin

from .models import (
    PCComponentCategory,
    PCBuild,
    PCBuildItem,
)


@admin.register(PCComponentCategory)
class PCComponentCategoryAdmin(admin.ModelAdmin):
    list_display = (
        "category",
        "component_type",
    )

    list_filter = ("component_type",)

    search_fields = ("category__name",)


class PCBuildItemInline(admin.TabularInline):
    model = PCBuildItem
    extra = 0
    raw_id_fields = ("variant",)


@admin.register(PCBuild)
class PCBuildAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "name",
        "user",
        "created_at",
    )

    search_fields = (
        "name",
        "user__email",
    )

    list_select_related = ("user",)

    inlines = [PCBuildItemInline]
