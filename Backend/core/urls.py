from rest_framework.routers import DefaultRouter
from .views import NoticeViewSet

router = DefaultRouter()

router.register(
    'notices',
    NoticeViewSet,
    basename='notice'
)

urlpatterns = router.urls