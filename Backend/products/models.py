
from django.core.validators import (
    MinValueValidator,
    MaxValueValidator,
)
from django.db import models
from django.utils.text import slugify

from accounts.models import User


class TimeStampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True,blank=True,null=True)
    updated_at = models.DateTimeField(auto_now=True,blank=True,null=True)

    class Meta:
        abstract = True


# =========================================================
# Category
# =========================================================

class Category(TimeStampedModel):

    parent = models.ForeignKey(
        'self',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='sub_categories'
    )

    name = models.CharField(
        max_length=100,
        unique=True
    )

    filters = models.JSONField(default=dict, blank=True)

    description = models.TextField(blank=True)

    image = models.ImageField(
        upload_to='categories/',
        blank=True,
        default='categories/default.jpg'
    )

    slug = models.SlugField(
        max_length=120,
        unique=True,
        blank=True
    )

    is_active = models.BooleanField(default=True)
    is_featured = models.BooleanField(default=False)

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.name)
        return super().save(*args, **kwargs)

    def __str__(self):
        if self.parent:
            return f"{self.parent.name} → {self.name}"
        return self.name


# =========================================================
# Brand
# =========================================================

class Brand(TimeStampedModel):

    categories = models.ManyToManyField(
        Category,
        related_name='brands',
        blank=True
    )

    name = models.CharField(
        max_length=100,
        unique=True
    )

    description = models.TextField(blank=True)

    image = models.ImageField(
        upload_to='brands/',
        blank=True,
        default='brands/default.jpg'
    )

    slug = models.SlugField(
        max_length=120,
        unique=True,
        blank=True
    )

    is_active = models.BooleanField(default=True)

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.name)
        return super().save(*args, **kwargs)

    def __str__(self):
        return self.name


# =========================================================
# Product
# =========================================================

class Product(TimeStampedModel):

    class Availability(models.TextChoices):
        IN_STOCK = "in_stock", "In Stock"
        OUT_OF_STOCK = "out_of_stock", "Out of Stock"
        COMING_SOON = "coming_soon", "Coming Soon"
        PRE_ORDER = "pre_order", "Pre Order"

    category = models.ForeignKey(
        Category,
        on_delete=models.PROTECT,
        related_name='products'
    )

    brand = models.ForeignKey(
        Brand,
        on_delete=models.PROTECT,
        related_name='products',
        blank=True,
        null=True
    )

    availability = models.CharField(
        max_length=20,
        choices=Availability.choices,
        default=Availability.IN_STOCK
    )

    name = models.CharField(
        max_length=200,
        unique=True
    )

    slug = models.SlugField(
        max_length=220,
        unique=True,
        blank=True
    )

    description = models.TextField(blank=True)

    key_feature = models.JSONField(
        default=dict,
        blank=True
    )

    specification = models.JSONField(
        default=dict,
        blank=True
    )

    is_active = models.BooleanField(default=True)
    is_featured = models.BooleanField(default=False)

    @property
    def product_code(self):
        return f"TZ-P{self.id:06d}"

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.name)
        return super().save(*args, **kwargs)

    def __str__(self):
        return self.name



# =========================================================
# Product Variant
# =========================================================

class ProductVariant(TimeStampedModel):

    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name='variants'
    )

    sku = models.CharField(
        max_length=100,
        unique=True,
        blank=True
    )

    # RAM and storage for mobile phones, tablets, etc.

    ram = models.CharField(
        max_length=50,
        blank=True,
        null=True
    )

    storage = models.CharField(
        max_length=50,
        blank=True,
        null=True
    )

    color = models.ForeignKey(
        'Color',
        on_delete=models.PROTECT,
        related_name='product_variants',
        blank=True,
        null=True
    )

    price = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[MinValueValidator(0)]
    )

    discount_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=0,
        validators=[
            MinValueValidator(0),
            MaxValueValidator(100)
        ]
    )

    stock = models.PositiveIntegerField(default=0)

    is_default = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)

    # =====================================================
    # Discounted Price
    # =====================================================

    @property
    def discounted_price(self):
        discount = (
            self.price *
            self.discount_percentage /
            100
        )

        return self.price - discount

    # =====================================================
    # Saved Price
    # =====================================================

    @property
    def saved_price(self):
        return (
            self.price *
            self.discount_percentage /
            100
        )

    # =====================================================
    # Save
    # =====================================================

    def save(self, *args, **kwargs):

        # Always generate SKU from current variant data.

        parts = [self.product.slug]

        if self.ram:
            parts.append(slugify(self.ram))

        if self.storage:
            parts.append(slugify(self.storage))

        if self.color_id:
            parts.append(slugify(self.color.name))

        base_sku = "-".join(parts)

        # Ensure SKU does not exceed database field length.
        max_length = self._meta.get_field(
            'sku'
        ).max_length

        base_sku = base_sku[:max_length].rstrip('-')

        sku = base_sku
        counter = 2

        # Ensure unique SKU.
        while ProductVariant.objects.filter(
            sku=sku
        ).exclude(pk=self.pk).exists():

            suffix = f"-{counter}"

            sku = (
                base_sku[:max_length - len(suffix)]
                .rstrip('-') + suffix
            )

            counter += 1

        self.sku = sku

        # First variant becomes default automatically.
        if not ProductVariant.objects.filter(
            product=self.product
        ).exclude(pk=self.pk).exists():

            self.is_default = True

        # Only one default variant per product.
        if self.is_default:

            ProductVariant.objects.filter(
                product=self.product,
                is_default=True
            ).exclude(pk=self.pk).update(
                is_default=False
            )

        # Ensure SKU is saved when update_fields is used.
        if kwargs.get('update_fields') is not None:

            update_fields = set(
                kwargs['update_fields']
            )

            update_fields.add('sku')

            kwargs['update_fields'] = update_fields

        super().save(*args, **kwargs)

    # =====================================================
    # String Representation
    # =====================================================

    def __str__(self):
        return f"{self.product.name} - {self.sku}"



# =========================================================
# Product Image
# =========================================================

class ProductImage(TimeStampedModel):

    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name='images'
    )

    image = models.ImageField(
        upload_to='products/',
        default='products/default.jpg'
    )

    alt_text = models.CharField(
        max_length=200,
        blank=True
    )

    is_primary = models.BooleanField(default=False)
    display_order = models.PositiveIntegerField(default=0)

    def save(self, *args, **kwargs):
        if not self.alt_text:
            self.alt_text = (
                f'{self.product.name} product image'
            )
        return super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.product.name} image'


# =========================================================
# Product Question
# =========================================================

class ProductQuestion(TimeStampedModel):

    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name='questions'
    )

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='product_questions'
    )

    question = models.TextField()
    answer = models.TextField(blank=True)

    is_approved = models.BooleanField(default=False)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.question


# =========================================================
# Product Review
# =========================================================

class ProductReview(TimeStampedModel):

    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name='reviews'
    )

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='product_reviews'
    )

    rating = models.PositiveSmallIntegerField(
        validators=[
            MinValueValidator(1),
            MaxValueValidator(5)
        ]
    )

    review = models.TextField()

    # Every review must be approved by an admin.
    is_approved = models.BooleanField(
        default=False,
        db_index=True
    )

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.product.name} - {self.rating}/5'


class Color(TimeStampedModel):

    name = models.CharField(
        max_length=50,
        unique=True
    )

    hex_code = models.CharField(
        max_length=7,
        unique=True
    )

    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name
