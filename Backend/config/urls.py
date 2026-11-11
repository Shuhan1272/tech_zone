from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from rest_framework.routers import DefaultRouter


urlpatterns = [
    path("api/v1/admin-panel/", include("admin_panel.urls")),
    path('admin/', admin.site.urls),

    path('api/v1/accounts/', include('accounts.urls')),
    path('api/v1/products/', include('products.urls')),
    path('api/v1/core/', include('core.urls')),
    path('api/v1/cart/',include('cart.urls')),
    path('api/v1/discounts/', include('discounts.urls')),  
    path('api/v1/orders/', include('order.urls')), 
    path('api/v1/payments/', include('payments.urls')),
    path('api/v1/wishlist/', include('wishlist.urls')),
    path("api/v1/pc-builder/",include("pc_builder.urls")), 
]

if settings.DEBUG:
    urlpatterns += static(
        settings.MEDIA_URL,
        document_root=settings.MEDIA_ROOT
    )