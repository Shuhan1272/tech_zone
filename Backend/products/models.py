from django.utils import timezone
import uuid

from django.core.validators import (
    MinValueValidator,
    MaxValueValidator,
)
from django.db import models
from django.utils.text import slugify

from accounts.models import User

from django.core.exceptions import ValidationError


class TimeStampedModel(models.Model):

    created_at = models.DateTimeField(
        auto_now_add=True
        #default=timezone.now
    )

    updated_at = models.DateTimeField(
        auto_now=True
        #default=timezone.now
    )

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

    description = models.TextField(
        blank=True 
    )

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

    is_active = models.BooleanField(
        default=True
    )

    is_featured = models.BooleanField(
            default=False
    )

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

    description = models.TextField(
        blank=True 
    )

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

    is_active = models.BooleanField(
        default=True
    )

    def save(self, *args, **kwargs):

        if not self.slug:
            self.slug = slugify(self.name)

        return super().save(*args, **kwargs)

    def __str__(self):
        
        return f"{self.name}"

        


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

    description = models.TextField(
        blank=True
    )

    key_feature = models.JSONField(
        default=dict,
        blank=True 
    )

    specification = models.JSONField(
        default=dict,
        blank=True
    )

    def default_color():
        return ["Black", "White"]
        
    colors = models.JSONField(
        default=default_color,  
        blank=True
    )


    is_active = models.BooleanField(
        default=True
    )

    is_featured = models.BooleanField(
        default=False
    )

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

    def default_options():
        return {
            "RAM": "",
            "Storage": ""
        }

    options = models.JSONField(
        default=default_options,
        blank=True
    )


    price = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[
            MinValueValidator(0)
        ]
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

    stock = models.PositiveIntegerField(
        default=0
    )

    is_default = models.BooleanField(
        default=False
    )

    is_active = models.BooleanField(
        default=True
    )

    @property
    def discounted_price(self):

        discount = (
            self.price *
            self.discount_percentage /
            100
        )

        return self.price - discount
    
    @property
    def saved_price(self):
        discount = (
            self.price *
            self.discount_percentage /
            100
        )
        return discount
    
    def save(self, *args, **kwargs):

        if not self.sku:

            self.sku = (
                f"{self.product.slug}-{self.options.get('RAM',' ')}-{self.options.get('Storage',' ')}"
            )

        # First variant becomes default
        if not ProductVariant.objects.filter(
            product=self.product
            ).exclude(pk=self.pk).exists():

            self.is_default = True

        # If this variant is selected as default,
        # remove default from all other variants
        if self.is_default:
            ProductVariant.objects.filter(
            product=self.product,
            is_default=True
            ).exclude(
            pk=self.pk
            ).update(
            is_default=False
            )

        super().save(*args, **kwargs)

    def __str__(self):

        return f'{self.product.name} - {self.sku}'


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

    is_primary = models.BooleanField(
        default=False
    )

    display_order = models.PositiveIntegerField(
        default=0
    )

    def save(self, *args, **kwargs):

        if not self.alt_text:

            self.alt_text = (
                f'{self.product.name} product image'
            )

        return super().save(*args, **kwargs)
    

    def __str__(self):

        return (
            f'{self.product.name} image'
        )


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

    answer = models.TextField(
        blank=True
    )

    is_approved = models.BooleanField(
        default=False
    )

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

    class Meta:

        ordering = ['-created_at']

        constraints = [
            models.UniqueConstraint(
                fields=['product', 'user'],
                name='unique_product_review'
            )
        ]

    def __str__(self):

        return f'{self.product.name} - {self.rating}/5'
