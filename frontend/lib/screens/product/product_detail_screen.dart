import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_detail_provider.dart';
import '../../services/product_service.dart';
import '../../widgets/common.dart';

/// Product detail: gallery, variant picker, price, stock, specifications,
/// reviews and Q&A.
///
/// Prices come from the selected variant's server-computed `discounted_price`
/// and `saved_price`. Stock gates the quantity stepper, but the backend is
/// still the authority — an add that exceeds stock is rejected server-side and
/// the message is surfaced verbatim.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.slug, this.listEntry});

  final String slug;

  /// The card the customer clicked, if any. Carries `key_feature` and
  /// `colors`, which the detail serializer does not return.
  final Product? listEntry;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final ProductDetailProvider _detail;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _detail = ProductDetailProvider(context.read<ProductService>());
    _load();
  }

  void _load() {
    _detail.load(
      widget.slug,
      isSignedIn: context.read<AuthProvider>().isSignedIn,
      listEntry: widget.listEntry,
    );
  }

  @override
  void didUpdateWidget(ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug) {
      _quantity = 1;
      _load();
    }
  }

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _detail,
      child: Consumer<ProductDetailProvider>(
        builder: (context, detail, _) {
          if (detail.isLoading) {
            return const PageContainer(
              child: LoadingState(message: 'Loading product…'),
            );
          }

          if (detail.error != null || detail.product == null) {
            return PageContainer(
              child: ErrorState(
                title: 'Product unavailable',
                message: detail.error ?? 'This product could not be loaded.',
                onRetry: _load,
              ),
            );
          }

          return PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Breadcrumbs(product: detail.product!),
                const SizedBox(height: 18),
                _MainSection(
                  detail: detail,
                  quantity: _quantity,
                  onQuantityChanged: (value) =>
                      setState(() => _quantity = value),
                ),
                const SizedBox(height: 40),
                _InfoTabs(detail: detail),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InkWell(
          onTap: () => context.go('/'),
          child: Text('Home', style: style),
        ),
        Text('  /  ', style: style),
        InkWell(
          onTap: () => context.go('/catalog'),
          child: Text('Products', style: style),
        ),
        if ((product.categoryName ?? '').isNotEmpty) ...[
          Text('  /  ', style: style),
          Text(product.categoryName!, style: style),
        ],
      ],
    );
  }
}

class _MainSection extends StatelessWidget {
  const _MainSection({
    required this.detail,
    required this.quantity,
    required this.onQuantityChanged,
  });

  final ProductDetailProvider detail;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final gallery = _Gallery(detail: detail);
    final info = _BuyBox(
      detail: detail,
      quantity: quantity,
      onQuantityChanged: onQuantityChanged,
    );

    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [gallery, const SizedBox(height: 26), info],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: gallery),
        const SizedBox(width: 34),
        Expanded(flex: 6, child: info),
      ],
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.detail});

  final ProductDetailProvider detail;

  @override
  Widget build(BuildContext context) {
    final urls = detail.imageUrls;
    final selected = urls.isEmpty
        ? null
        : urls[detail.selectedImageIndex.clamp(0, urls.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: AspectRatio(
            aspectRatio: 1,
            child: ImagePlate(
              padding: const EdgeInsets.all(20),
              child: RemoteImage(url: selected, label: detail.product?.name),
            ),
          ),
        ),
        if (urls.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final isActive = index == detail.selectedImageIndex;
                return InkWell(
                  onTap: () => detail.selectImage(index),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    width: 74,
                    decoration: BoxDecoration(
                      color: AppPalette.of(context).imagePlate,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: isActive
                            ? AppColors.electricBlue
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: RemoteImage(url: urls[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Title, price, variant picker, stock and the add-to-cart action.
class _BuyBox extends StatelessWidget {
  const _BuyBox({
    required this.detail,
    required this.quantity,
    required this.onQuantityChanged,
  });

  final ProductDetailProvider detail;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final product = detail.product!;
    final variant = detail.selectedVariant;
    final cart = context.watch<CartProvider>();
    final isSignedIn = context.select<AuthProvider, bool>((a) => a.isSignedIn);

    final inCart = variant == null ? 0 : cart.quantityInCart(variant.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if ((product.brandName ?? '').isNotEmpty && product.brandName != 'null')
          Text(
            product.brandName!.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: palette.accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
        const SizedBox(height: 7),
        Text(
          product.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (detail.averageRating != null) ...[
              StarRating(rating: detail.averageRating!),
              const SizedBox(width: 7),
              Text(
                detail.averageRating!.toStringAsFixed(1),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '(${detail.reviews.length})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
            ],
            if (variant != null)
              Badgelet(
                label: variant.inStock
                    ? '${variant.stock} in stock'
                    : 'Out of stock',
                icon: variant.inStock
                    ? Icons.check_circle_outline_rounded
                    : Icons.remove_circle_outline_rounded,
                // In stock is the brand green, filled: it is the one label a
                // customer looks for before anything else on this page.
                color: variant.inStock
                    ? palette.success
                    : theme.colorScheme.errorContainer,
                foreground: variant.inStock
                    ? palette.onSuccess
                    : theme.colorScheme.onErrorContainer,
              ),
          ],
        ),
        const SizedBox(height: 20),
        _PriceRow(variant: variant),
        const SizedBox(height: 22),
        if (product.sellableVariants.length > 1) ...[
          Text(
            'Configuration',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final option in product.sellableVariants)
                ChoiceChip(
                  selected: option.id == variant?.id,
                  onSelected: (_) => detail.selectVariant(option),
                  label: Text(option.optionSummary),
                  avatar: option.inStock
                      ? null
                      : const Icon(Icons.block_rounded, size: 14),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (product.colors.isNotEmpty) ...[
          Text(
            'Colour',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Colour is listed by the manufacturer and is not a separate '
            'orderable variant.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final color in product.colors)
                ChoiceChip(
                  selected: color == detail.selectedColor,
                  onSelected: (_) => detail.selectColor(color),
                  label: Text(color),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (variant != null && variant.inStock) ...[
          Row(
            children: [
              _QuantityStepper(
                quantity: quantity,
                max: variant.stock,
                onChanged: onQuantityChanged,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FilledButton.icon(
                  onPressed: cart.isVariantPending(variant.id)
                      ? null
                      : () async {
                          if (!isSignedIn) {
                            context.push(
                              '/login?next=/product/${product.slug}',
                            );
                            return;
                          }
                          final failure = await cart.addToCart(
                            variantId: variant.id,
                            quantity: quantity,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            appSnackBar(
                              context,
                              ok: failure == null,
                              message:
                                  failure ??
                                  'Added $quantity x ${variant.optionSummary} '
                                      'to your cart.',
                              actionLabel: failure == null ? 'View cart' : null,
                              onAction: failure == null
                                  ? () => context.push('/cart')
                                  : null,
                            ),
                          );
                        },
                  icon: cart.isVariantPending(variant.id)
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: Text(isSignedIn ? 'Add to cart' : 'Sign in to buy'),
                ),
              ),
            ],
          ),
          if (inCart > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.shopping_cart_checkout_rounded,
                  size: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '$inCart already in your cart',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/cart'),
                  child: const Text('View cart'),
                ),
              ],
            ),
          ],
        ] else
          UnavailableNotice(
            title: 'Not available to order',
            message: variant == null
                ? 'This product has no active variant priced for sale.'
                : 'This configuration is out of stock. Try another '
                      'configuration or check back later.',
            icon: Icons.inventory_2_outlined,
          ),
        if (detail.hasKeyFeatures) ...[
          const SizedBox(height: 26),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Key features',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final entry in product.keyFeature.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: palette.successText,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                        children: [
                          TextSpan(
                            text: '${entry.key}: ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: '${entry.value}'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.variant});

  final ProductVariant? variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    if (variant == null) {
      return Text(
        'Price unavailable',
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              Formatters.money(variant!.discountedPrice),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: palette.price,
              ),
            ),
            if (variant!.hasDiscount) ...[
              Text(
                Formatters.money(variant!.price),
                style: theme.textTheme.titleMedium?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Badgelet(
                label: Formatters.discountBadge(variant!.discountPercentage),
                color: palette.badge,
                foreground: palette.onBadge,
              ),
            ],
          ],
        ),
        if (variant!.hasDiscount) ...[
          const SizedBox(height: 6),
          Text(
            'You save ${Formatters.money(variant!.savedPrice)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (variant!.sku.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'SKU: ${variant!.sku}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.max,
    required this.onChanged,
  });

  final int quantity;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
            icon: const Icon(Icons.remove_rounded, size: 18),
            tooltip: 'Decrease',
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: quantity < max ? () => onChanged(quantity + 1) : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            tooltip: 'Increase',
          ),
        ],
      ),
    );
  }
}

/// Description, specification table, reviews and Q&A.
class _InfoTabs extends StatelessWidget {
  const _InfoTabs({required this.detail});

  final ProductDetailProvider detail;

  @override
  Widget build(BuildContext context) {
    final product = detail.product!;

    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Column(
              children: [
                TabBar(
                  isScrollable: Responsive.isMobile(context),
                  tabAlignment: Responsive.isMobile(context)
                      ? TabAlignment.start
                      : TabAlignment.fill,
                  tabs: [
                    const Tab(text: 'Description'),
                    const Tab(text: 'Specification'),
                    Tab(text: 'Reviews (${detail.reviews.length})'),
                    Tab(text: 'Q&A (${detail.questions.length})'),
                  ],
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    height: 420,
                    child: TabBarView(
                      children: [
                        _DescriptionTab(product: product),
                        _SpecificationTab(product: product),
                        _ReviewsTab(detail: detail),
                        _QuestionsTab(detail: detail),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionTab extends StatelessWidget {
  const _DescriptionTab({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    if (product.description.trim().isEmpty) {
      return const EmptyState(
        title: 'No description',
        message: 'This product has no description yet.',
        icon: Icons.description_outlined,
      );
    }

    return SingleChildScrollView(
      child: Text(
        product.description.trim(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.65),
      ),
    );
  }
}

/// Renders the `specification` JSONField as a key/value table.
class _SpecificationTab extends StatelessWidget {
  const _SpecificationTab({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final entries = product.specification.entries
        .where((e) => '${e.value}'.trim().isNotEmpty)
        .toList();

    if (entries.isEmpty) {
      return const EmptyState(
        title: 'No specification',
        message: 'This product has no specification recorded yet.',
        icon: Icons.list_alt_rounded,
      );
    }

    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            Container(
              color: i.isEven
                  ? theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    )
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: Responsive.isMobile(context) ? 130 : 230,
                    child: Text(
                      entries[i].key,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${entries[i].value}',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Reviews list plus a submit form.
///
/// Both require authentication — the ViewSet is `IsAuthenticated` even for GET
/// — so signed-out visitors get a sign-in prompt instead of an empty list.
class _ReviewsTab extends StatefulWidget {
  const _ReviewsTab({required this.detail});

  final ProductDetailProvider detail;

  @override
  State<_ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<_ReviewsTab> {
  final _controller = TextEditingController();
  int _rating = 5;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final failure = await widget.detail.submitReview(
      rating: _rating,
      review: _controller.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (failure == null) {
      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(context, ok: true, message: 'Thanks for your review.'),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(appSnackBar(context, ok: false, message: failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    if (!auth.isSignedIn) {
      return _SignInPrompt(
        message:
            'Reviews are only available to signed-in customers on this API.',
        onSignIn: () =>
            context.push('/login?next=/product/${detail.product!.slug}'),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Write a review',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  onPressed: () => setState(() => _rating = star),
                  visualDensity: VisualDensity.compact,
                  tooltip: '$star star${star == 1 ? '' : 's'}',
                  icon: Icon(
                    _rating >= star
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppPalette.of(context).rating,
                    size: 24,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'How did this product work out for you?',
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Text('Submit review'),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You can leave one review per product.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          const Divider(),
          const SizedBox(height: 14),
          if (detail.reviews.isEmpty)
            const EmptyState(
              title: 'No reviews yet',
              message: 'Be the first to review this product.',
              icon: Icons.rate_review_outlined,
            )
          else
            for (final review in detail.reviews)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StarRating(rating: review.rating.toDouble()),
                        const SizedBox(width: 10),
                        Text(
                          review.userId == auth.user?.id
                              ? 'You'
                              : 'Verified customer',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          Formatters.relative(review.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      review.review,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _QuestionsTab extends StatefulWidget {
  const _QuestionsTab({required this.detail});

  final ProductDetailProvider detail;

  @override
  State<_QuestionsTab> createState() => _QuestionsTabState();
}

class _QuestionsTabState extends State<_QuestionsTab> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final failure = await widget.detail.submitQuestion(_controller.text.trim());
    if (!mounted) return;
    setState(() => _submitting = false);

    if (failure == null) {
      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          ok: true,
          message: 'Question submitted. Our team will reply soon.',
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(appSnackBar(context, ok: false, message: failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    if (!auth.isSignedIn) {
      return _SignInPrompt(
        message:
            'Questions and answers are only available to signed-in customers '
            'on this API.',
        onSignIn: () =>
            context.push('/login?next=/product/${detail.product!.slug}'),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ask a question',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'What would you like to know about this product?',
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Text('Submit question'),
            ),
          ),
          const SizedBox(height: 22),
          const Divider(),
          const SizedBox(height: 14),
          if (detail.questions.isEmpty)
            const EmptyState(
              title: 'No questions yet',
              message: 'Ask the first question about this product.',
              icon: Icons.help_outline_rounded,
            )
          else
            for (final question in detail.questions)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.help_outline_rounded,
                          size: 16,
                          color: AppPalette.of(context).accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            question.question,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          Formatters.relative(question.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: question.isAnswered
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.support_agent_rounded,
                                  size: 16,
                                  color: theme.colorScheme.secondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    question.answer,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      height: 1.55,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Awaiting a reply from the TechZone team.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.message, required this.onSignIn});

  final String message;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: 'Sign in to continue',
      message: message,
      icon: Icons.lock_outline_rounded,
      action: FilledButton.icon(
        onPressed: onSignIn,
        icon: const Icon(Icons.login_rounded, size: 18),
        label: const Text('Sign in'),
      ),
    );
  }
}
