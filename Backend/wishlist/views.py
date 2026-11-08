from uuid import uuid4

from django.conf import settings
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from django.urls import reverse

from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Wishlist, WishlistItem
from .pdf import build_wishlist_pdf
from .serializers import WishlistAddSerializer, WishlistItemSerializer


def wishlist_items(wishlist):
    return (
        WishlistItem.objects.filter(wishlist=wishlist)
        .select_related('variant__product__category')
        .prefetch_related('variant__product__images')
    )


class WishlistView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        wishlist = Wishlist.objects.filter(user=request.user).first()
        items = list(wishlist_items(wishlist)) if wishlist else []

        return Response({
            'count': len(items),
            'is_public': wishlist.is_public if wishlist else False,
            'items': WishlistItemSerializer(
                items,
                many=True,
                context={'request': request}
            ).data,
        })

    def delete(self, request):
        WishlistItem.objects.filter(
            wishlist__user=request.user
        ).delete()

        return Response(status=status.HTTP_204_NO_CONTENT)


class WishlistAddView(generics.GenericAPIView):
    serializer_class = WishlistAddSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        wishlist, _ = Wishlist.objects.get_or_create(
            user=request.user
        )

        item, created = WishlistItem.objects.get_or_create(
            wishlist=wishlist,
            variant=serializer.validated_data['variant']
        )

        item = wishlist_items(wishlist).get(pk=item.pk)

        return Response(
            WishlistItemSerializer(
                item,
                context={'request': request}
            ).data,
            status=(
                status.HTTP_201_CREATED
                if created
                else status.HTTP_200_OK
            )
        )


class WishlistRemoveView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, pk):
        item = get_object_or_404(
            WishlistItem,
            pk=pk,
            wishlist__user=request.user
        )
        item.delete()

        return Response(status=status.HTTP_204_NO_CONTENT)


class WishlistShareView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        wishlist, _ = Wishlist.objects.get_or_create(
            user=request.user
        )

        if not wishlist.is_public:
            wishlist.is_public = True
            wishlist.save(update_fields=['is_public', 'updated_at'])

        token = wishlist.share_token

        public_api_url = request.build_absolute_uri(
            reverse('wishlist-public', kwargs={'token': token})
        )

        share_url = (
            f'{settings.FRONTEND_URL.rstrip("/")}'
            f'/wishlist/shared/{token}/'
        )

        return Response({
            'share_url': share_url,
            'public_api_url': public_api_url,
        })

    def delete(self, request):
        wishlist = Wishlist.objects.filter(
            user=request.user
        ).first()

        if wishlist and wishlist.is_public:
            wishlist.is_public = False
            wishlist.share_token = uuid4()
            wishlist.save(
                update_fields=['is_public', 'share_token', 'updated_at']
            )

        return Response(status=status.HTTP_204_NO_CONTENT)


class PublicWishlistView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def get(self, request, token):
        wishlist = get_object_or_404(
            Wishlist,
            share_token=token,
            is_public=True
        )

        items = list(wishlist_items(wishlist))

        return Response({
            'count': len(items),
            'items': WishlistItemSerializer(
                items,
                many=True,
                context={'request': request}
            ).data,
        })


class WishlistDownloadView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        wishlist = Wishlist.objects.filter(
            user=request.user
        ).first()

        items = list(wishlist_items(wishlist)) if wishlist else []

        response = HttpResponse(
            build_wishlist_pdf(items),
            content_type='application/pdf'
        )
        response['Content-Disposition'] = (
            'attachment; filename="fastkart-wishlist.pdf"'
        )
        response['Cache-Control'] = 'no-store'

        return response