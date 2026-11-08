from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import DiscountViewSet, DiscountValidationView


router = DefaultRouter()

router.register(
    'discounts',
    DiscountViewSet,
    basename='discount'
)

urlpatterns = [
    path(
        'discounts/validate/',
        DiscountValidationView.as_view(),
        name='discount-validate'
    ),
]

urlpatterns += router.urls
