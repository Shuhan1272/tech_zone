from rest_framework.permissions import BasePermission


class IsAdminOrReadOnly(BasePermission):

    def has_permission(
        self,
        request,
        view
    ):

        # Anyone who is allowed to read
        # can use GET, HEAD and OPTIONS.
        if request.method in [
            'GET',
            'HEAD',
            'OPTIONS'
        ]:

            return True

        # Only authenticated admins can
        # create/update/delete products.
        return (
            request.user.is_authenticated
            and request.user.role in [
                'admin',
                'super_admin'
            ]
        )