import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/catalog_provider.dart';
import 'common.dart';

/// A product tile for the home and catalog grids.
///
/// Every price shown here comes from `default_variant` on the list serializer —
/// the backend's own `price`, `discounted_price` and `saved_price`. Nothing is
/// recomputed locally.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final variant = product.primaryVariant;
    final imageUrl = context.select<CatalogProvider, String?>(
      (catalog) => catalog.primaryImageFor(product.id),
    );

    return Card(
      child: InkWell(
        onTap: () => context.push('/product/${product.slug}', extra: product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: ProductGrid._imageAspect,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ImagePlate(
                    child: RemoteImage(url: imageUrl, label: product.name),
                  ),
                  // Savings badge, top left, reading both the amount saved
                  // and the percentage off — the two numbers the backend
                  // already sends on `default_variant`.
                  if (variant?.hasDiscount ?? false)
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Badgelet(
                          label: Formatters.savingsBadge(
                            variant!.savedPrice,
                            variant.discountPercentage,
                          ),
                          color: palette.badge,
                          foreground: palette.onBadge,
                        ),
                      ),
                    ),
                  // Bottom left, so it never collides with the savings badge.
                  if (!product.inStock)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Badgelet(
                          label: 'Out of stock',
                          color: AppColors.charcoal,
                          foreground: AppColors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((product.brandName ?? '').isNotEmpty &&
                        product.brandName != 'null')
                      Text(
                        product.brandName!.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.accent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    const SizedBox(height: 3),
                    // Flexible so the title drops to one line rather than
                    // overflowing when the text scale is turned up.
                    Flexible(
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.charcoal,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _PriceBlock(variant: variant, product: product),
                    const SizedBox(height: 8),
                    _AddButton(product: product, variant: variant),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.variant, required this.product});

  final ProductVariant? variant;
  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (variant == null) {
      return Text(
        'Price unavailable',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    // Price paid in red, the original struck through beside it, on one line
    // where there is room and wrapping underneath where there is not.
    return Wrap(
      spacing: 7,
      runSpacing: 1,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        Text(
          Formatters.money(variant!.discountedPrice),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: AppPalette.of(context).price,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (variant!.hasDiscount)
          Text(
            Formatters.money(variant!.price),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              decorationColor: theme.colorScheme.onSurfaceVariant,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (product.hasMultipleVariants)
          Text(
            'from',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// "Add to cart" on a card.
///
/// Signed-out customers are routed to login instead, because every cart
/// endpoint requires authentication. Products with more than one variant go to
/// the detail page so the customer picks a variant deliberately.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.product, required this.variant});

  final Product product;
  final ProductVariant? variant;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final isSignedIn = context.select<AuthProvider, bool>((a) => a.isSignedIn);

    final v = variant;
    final disabled = v == null || !v.inStock;
    final pending = v != null && cart.isVariantPending(v.id);

    if (product.hasMultipleVariants) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () =>
              context.push('/product/${product.slug}', extra: product),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Choose options'),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: disabled || pending
            ? null
            : () async {
                if (!isSignedIn) {
                  context.push('/login?next=/product/${product.slug}');
                  return;
                }
                final failure = await cart.addToCart(variantId: v.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  appSnackBar(
                    context,
                    ok: failure == null,
                    message: failure ?? 'Added ${product.name} to your cart.',
                  ),
                );
              },
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        icon: pending
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : const Icon(Icons.add_shopping_cart_rounded, size: 16),
        label: Text(disabled ? 'Unavailable' : 'Add to cart'),
      ),
    );
  }
}

/// Responsive product grid shared by home, catalog and search.
class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key, required this.products, required this.columns});

  final List<Product> products;
  final int columns;

  /// Aspect ratio of the image area at the top of each card. Square, so the
  /// photo takes as much of a dense tile as it can.
  static const double _imageAspect = 1.0;

  /// Height the text block below the image needs: brand line, two-line title,
  /// price (with a struck-through original) and the action button, plus the
  /// card's own padding. Fixed, because none of it scales with card width.
  static const double _contentHeight = 152;

  /// Gutter between tiles. Tight, so the lavender page shows as a grid line
  /// rather than as empty space.
  static const double _spacing = 12;

  @override
  Widget build(BuildContext context) {
    // A fixed childAspectRatio would overflow at some breakpoints: the image
    // grows with the column width while the text block does not. Deriving the
    // cell height from the measured width keeps the text block exactly as tall
    // as it needs to be at every size.
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = _spacing;
        final cellWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final imageHeight = cellWidth / _imageAspect;

        return GridView.builder(
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            // image + 1px divider + text block
            mainAxisExtent: imageHeight + 1 + _contentHeight,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) =>
              ProductCard(product: products[index]),
        );
      },
    );
  }
}
