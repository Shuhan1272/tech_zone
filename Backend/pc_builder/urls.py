
from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import (
    PCComponentListView,
    PCBuildViewSet,
)


router = DefaultRouter()

router.register(
    "builds",
    PCBuildViewSet,
    basename="pc-build"
)


urlpatterns = [
    path(
        "components/",
        PCComponentListView.as_view(),
        name="pc-components"
    ),
] + router.urls
