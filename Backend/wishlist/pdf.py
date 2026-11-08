
from html import escape
from io import BytesIO
from zoneinfo import ZoneInfo

from django.conf import settings
from django.utils import timezone

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import (
    getSampleStyleSheet,
    ParagraphStyle,
)
from reportlab.lib.utils import ImageReader
from reportlab.platypus import (
    Image,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


def build_wishlist_pdf(items):
    buffer = BytesIO()

    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=32,
        rightMargin=32,
        topMargin=40,
        bottomMargin=40,
    )

    styles = getSampleStyleSheet()

    small = ParagraphStyle(
        'WishlistCell',
        parent=styles['Normal'],
        fontSize=8,
        leading=12,
        wordWrap='CJK',
    )

    product_style = ParagraphStyle(
        'WishlistProduct',
        parent=small,
        fontSize=9,
        leading=13,
    )

    code_style = ParagraphStyle(
        'WishlistCode',
        parent=small,
        fontSize=8,
        leading=12,
        textColor=colors.HexColor('#2457E7'),
    )

    # Header styles
    header_left = ParagraphStyle(
        'WishlistHeaderLeft',
        fontName='Helvetica-Bold',
        fontSize=8,
        leading=11,
        textColor=colors.white,
        alignment=0,
    )

    header_center = ParagraphStyle(
        'WishlistHeaderCenter',
        parent=header_left,
        alignment=1,
    )

    header_right = ParagraphStyle(
        'WishlistHeaderRight',
        parent=header_left,
        alignment=2,
    )

    bd_time = timezone.localtime(
        timezone.now(),
        ZoneInfo('Asia/Dhaka')
    )

    frontend_url = getattr(
        settings,
        'FRONTEND_URL',
        'http://localhost:3000'
    ).rstrip('/')

    story = [
        Paragraph(
            'TechZone | My Wishlist',
            styles['Title']
        ),
        Spacer(1, 10),
        Paragraph(
            f'Generated: {bd_time.strftime("%d-%m-%Y %I:%M %p")} (BDT)',
            styles['Normal']
        ),
        Spacer(1, 8),
        Paragraph(
            'Find your favorite products using their '
            'product code or open the product link.',
            styles['Normal']
        ),
        Spacer(1, 18),
    ]

    if not items:
        story.append(
            Paragraph(
                'Your wishlist is empty.',
                styles['Normal']
            )
        )

    else:
        # Properly aligned header cells
        rows = [[
            Paragraph('#', header_center),
            Paragraph('Image', header_center),
            Paragraph('Product Details', header_left),
            Paragraph('Regular', header_right),
            Paragraph('Special', header_right),
        ]]

        for number, item in enumerate(items, 1):

            variant = item.variant
            product = variant.product

            product_code = product.product_code
            sku = variant.sku

            product_url = (
                f'{frontend_url}/product/{product.slug}'
            )

            # Find primary product image
            images = list(product.images.all())

            picture = next(
                (
                    img for img in images
                    if img.is_primary
                ),
                images[0] if images else None
            )

            thumbnail = '-'

            if picture and picture.image:
                try:
                    with picture.image.storage.open(
                        picture.image.name,
                        'rb'
                    ) as file:
                        image_data = file.read()

                    image_buffer = BytesIO(image_data)

                    reader = ImageReader(image_buffer)
                    img_width, img_height = reader.getSize()

                    max_size = 48

                    scale = min(
                        max_size / img_width,
                        max_size / img_height
                    )

                    thumbnail = Image(
                        image_buffer,
                        width=img_width * scale,
                        height=img_height * scale
                    )

                except Exception:
                    thumbnail = '-'

            product_name = escape(product.name)
            category_name = escape(
                product.category.name
            )

            safe_sku = escape(sku)
            safe_code = escape(product_code)

            safe_url = escape(
                product_url,
                quote=True
            )

            product_details = [
                Paragraph(
                    f'<b>{product_name}</b>',
                    product_style
                ),
                Spacer(1, 4),
                Paragraph(
                    f'Category: {category_name}',
                    small
                ),
                Spacer(1, 4),
                Paragraph(
                    f'<b>Product Code:</b> {safe_code}',
                    code_style
                ),
                Paragraph(
                    f'<b>SKU:</b> {safe_sku}',
                    small
                ),
            ]

            product_details.extend([
                Spacer(1, 5),
                Paragraph(
                    f'<link href="{safe_url}" '
                    f'color="#2457E7">'
                    f'<u>View Product on TechZone</u>'
                    f'</link>',
                    small
                )
            ])

            rows.append([
                str(number),
                thumbnail,
                product_details,
                f'{variant.price:,.2f}',
                f'{variant.discounted_price:,.2f}',
            ])

        # A4 width = 595.28
        # Margins = 32 + 32
        # Available width = 531.28
        available_width = A4[0] - 64

        table = Table(
            rows,
            colWidths=[
                26,
                60,
                available_width - 26 - 60 - 92 - 92,
                92,
                92,
            ],
            repeatRows=1,
            hAlign='LEFT',
        )

        table.setStyle(TableStyle([

            # Header background
            (
                'BACKGROUND',
                (0, 0),
                (-1, 0),
                colors.HexColor('#2457E7')
            ),

            # Header text color
            (
                'TEXTCOLOR',
                (0, 0),
                (-1, 0),
                colors.white
            ),

            # Header font
            (
                'FONTNAME',
                (0, 0),
                (-1, 0),
                'Helvetica-Bold'
            ),

            # Header vertical alignment
            (
                'VALIGN',
                (0, 0),
                (-1, 0),
                'MIDDLE'
            ),

            # Header padding
            (
                'TOPPADDING',
                (0, 0),
                (-1, 0),
                12
            ),
            (
                'BOTTOMPADDING',
                (0, 0),
                (-1, 0),
                12
            ),

            # Center number and image columns
            (
                'ALIGN',
                (0, 0),
                (1, -1),
                'CENTER'
            ),

            # Left-align product details
            (
                'ALIGN',
                (2, 0),
                (2, -1),
                'LEFT'
            ),

            # Right-align both price columns
            (
                'ALIGN',
                (3, 0),
                (4, -1),
                'RIGHT'
            ),

            # Vertical alignment for all cells
            (
                'VALIGN',
                (0, 0),
                (-1, -1),
                'MIDDLE'
            ),

            # Alternating row backgrounds
            (
                'ROWBACKGROUNDS',
                (0, 1),
                (-1, -1),
                [
                    colors.white,
                    colors.whitesmoke
                ]
            ),

            # Cell padding
            (
                'LEFTPADDING',
                (0, 0),
                (-1, -1),
                6
            ),
            (
                'RIGHTPADDING',
                (0, 0),
                (-1, -1),
                6
            ),
            (
                'TOPPADDING',
                (0, 1),
                (-1, -1),
                10
            ),
            (
                'BOTTOMPADDING',
                (0, 1),
                (-1, -1),
                10
            ),

            # Row separators
            (
                'LINEBELOW',
                (0, 0),
                (-1, 0),
                0.5,
                colors.HexColor('#DDE4F0')
            ),
            (
                'LINEBELOW',
                (0, 1),
                (-1, -1),
                0.3,
                colors.HexColor('#E5EAF2')
            ),
        ]))

        story.append(table)
        story.append(Spacer(1, 16))

        story.append(
            Paragraph(
                '<b>Note:</b> Prices and availability '
                'may change. Please check TechZone '
                'before placing an order.',
                styles['Normal']
            )
        )

    doc.build(story)

    return buffer.getvalue()
