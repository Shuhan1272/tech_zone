import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/utils/responsive.dart';
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
                    // Exactly two lines of room, always. A Flexible here lets
                    // the row shrink below one line of text when the rest of
                    // the card is tight, and the name is then sliced through
                    // the middle instead of ellipsised.
                    SizedBox(
                      height: ProductGrid._titleHeight,
                      width: double.infinity,
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.charcoal,
                          fontWeight: FontWeight.w600,
                          height: ProductGrid._titleLineHeight,
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
      return SizedBox(
        height: ProductGrid._priceHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Price unavailable',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // One line, always: the price paid in red, the original struck through
    // beside it. Only the struck-through price may ellipsise, so a narrow
    // tile never clips what the customer actually pays.
    return SizedBox(
      height: ProductGrid._priceHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Formatters.money(variant!.discountedPrice),
            maxLines: 1,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppPalette.of(context).price,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (variant!.hasDiscount) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                Formatters.money(variant!.price),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  decorationColor: theme.colorScheme.onSurfaceVariant,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          if (product.hasMultipleVariants) ...[
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                'from',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
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
  const ProductGrid({
    super.key,
    required this.products,
    required this.columns,
    this.availableWidth,
  });

  final List<Product> products;
  final int columns;

  /// Width the grid has to fill, when it is not the full page content width —
  /// the catalogue puts it beside a sidebar. Null means the full width.
  final double? availableWidth;

  /// Aspect ratio of the image area at the top of each card. Square, so the
  /// photo takes as much of a dense tile as it can.
  static const double _imageAspect = 1.0;

  /// Line height of the product name, and the room two lines of it need.
  /// `bodySmall` is 12px, so two lines at 1.35 come to 32.4 — rounded up so
  /// a descender is never clipped.
  static const double _titleLineHeight = 1.35;
  static const double _titleHeight = 34;

  /// Room for the price line: `titleSmall` is 14px, so a line box is ~20.
  static const double _priceHeight = 22;

  /// Height the text block below the image needs. Every part of it is a fixed
  /// height, so this is a sum rather than an estimate:
  ///
  ///   9 top padding + 16 brand line + 3 gap + 34 title (two lines)
  ///   + 22 price row + 8 gap + 48 button + 10 bottom padding
  ///
  /// The button is 36 tall but lays out in 48: Material keeps a 48px tap
  /// target around it, and budgeting the drawn height instead is what pushed
  /// the name out of its two lines.
  static const double _contentHeight = 150;

  /// Gutter between tiles. Tight, so the lavender page shows as a grid line
  /// rather than as empty space.
  static const double _spacing = 12;

  @override
  Widget build(BuildContext context) {
    // A fixed childAspectRatio would overflow at some breakpoints: the image
    // grows with the column width while the text block does not. Deriving the
    // cell height from the width keeps the text block exactly as tall as it
    // needs to be at every size.
    //
    // The width is computed rather than measured with a LayoutBuilder. Every
    // card is an InkWell with two buttons in it, and a LayoutBuilder rebuilds
    // its subtree from inside the layout phase: when the pointer leaves a card
    // during a relayout, MouseTracker calls setState on it, LayoutBuilder
    // defers that rebuild to the next frame, and if navigation has removed the
    // grid by then the deferred rebuild lands on detached render objects and
    // takes the frame down. See Responsive.contentWidth.
    final width = availableWidth ?? Responsive.contentWidth(context);
    final cellWidth = (width - _spacing * (columns - 1)) / columns;
    final imageHeight = cellWidth / _imageAspect;

    return GridView.builder(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: _spacing,
        mainAxisSpacing: _spacing,
        // image + 1px divider + text block
        mainAxisExtent: imageHeight + 1 + _contentHeight,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) => ProductCard(product: products[index]),
    );
  }
}
