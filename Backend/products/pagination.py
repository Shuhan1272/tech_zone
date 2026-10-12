from rest_framework.pagination import PageNumberPagination


class ProductPagination(
    PageNumberPagination
):

    # Default items per page when none is specified in the URL
    page_size = 20

    # The query parameter name used in the URL (e.g., ?show=48 or ?page_size=48)
    page_size_query_param = 'limit' 

    # Set this higher than or equal to your maximum dropdown value (90)
    max_page_size = 90