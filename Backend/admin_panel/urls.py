from django.urls import path
from . import views

urlpatterns = [
    path("login/", views.login),
    path("workspace/", views.workspace),
    path("permissions/", views.permission_catalog),
    path("overview/", views.overview),
    path("resources/<slug:key>/", views.listing),
    path("resources/<slug:key>/new/", views.record),
    path("resources/<slug:key>/<int:pk>/", views.record),
    path("resources/<slug:key>/<int:pk>/action/", views.operation),
]
