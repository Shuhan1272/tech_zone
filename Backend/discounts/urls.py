from rest_framework.routers import DefaultRouter

from .views import DiscountViewSet


router = DefaultRouter()

router.register(
    'discounts',
    DiscountViewSet,
    basename='discount'
)

urlpatterns = router.urls