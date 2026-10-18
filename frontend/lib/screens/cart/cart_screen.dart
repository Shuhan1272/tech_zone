import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../models/cart.dart';
import '../../models/discount.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../widgets/common.dart';

/// The shopping cart.
///
/// Quantity changes and removals go straight to `/cart/items/{id}/` and the
/// cart is refetched, so what is shown always reflects the server. Totals are
/// summed from the server's own per-unit `discounted_price`.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<AuthProvider>().isSignedIn) {
        context.read<CartProvider>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cart = context.watch<CartProvider>();

    if (!auth.isSignedIn) {
      return PageContainer(
        child: EmptyState(
          title: 'Sign in to see your cart',
          message:
              'Your TechZone cart is tied to your account, so you need to be '
              'signed in to view or change it.',
          icon: Icons.shopping_cart_outlined,
          action: FilledButton.icon(
            onPressed: () => context.push('/login?next=/cart'),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Sign in'),
          ),
        ),
      );
    }

    if (cart.isLoading && cart.isEmpty) {
      return const PageContainer(
        child: LoadingState(message: 'Loading your cart…'),
      );
    }

    if (cart.error != null && cart.isEmpty) {
      return PageContainer(
        child: ErrorState(message: cart.error!, onRetry: () => cart.load()),
      );
    }

    if (cart.isEmpty) {
      return PageContainer(
        child: EmptyState(
          title: 'Your cart is empty',
          message: 'Browse the catalog and add something you like.',
          icon: Icons.remove_shopping_cart_outlined,
          action: FilledButton.icon(
            onPressed: () => context.go('/catalog'),
            icon: const Icon(Icons.storefront_rounded, size: 18),
            label: const Text('Start shopping'),
          ),
        ),
      );
    }

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your cart',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: cart.isLoading
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Empty your cart?'),
                            content: const Text(
                              'This removes every item from your cart. '
                              'It cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Keep items'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Empty cart'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !context.mounted) return;
                        final failure = await cart.clearCart();
                        if (failure != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            appSnackBar(context, ok: false, message: failure),
                          );
                        }
                      },
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Empty cart'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${cart.lineCount} ${cart.lineCount == 1 ? 'line' : 'lines'} · '
            '${cart.totalQuantity} ${cart.totalQuantity == 1 ? 'item' : 'items'}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          SplitLayout(
            secondaryWidth: 350,
            primary: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in cart.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CartLineTile(item: item),
                  ),
              ],
            ),
            secondary: const OrderSummaryCard(showCheckoutButton: true),
          ),
        ],
      ),
    );
  }
}

/// One cart line: thumbnail, name, variant, unit price, stepper and remove.
class CartLineTile extends StatelessWidget {
  const CartLineTile({super.key, required this.item, this.readOnly = false});

  final CartItem item;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<CartProvider>();
    final pending = cart.isItemPending(item.id);
    final isMobile = Responsive.isMobile(context);

    // The cart serializer has no slug or image, so the thumbnail comes from
    // the catalog's image index via the hydrated variant's product id.
    final productId = item.variant?.productId;
    final imageUrl = productId == null
        ? null
        : context.select<CatalogProvider, String?>(
            (catalog) => catalog.primaryImageFor(productId),
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: isMobile ? 64 : 84,
              height: isMobile ? 64 : 84,
              child: ImagePlate(
                padding: const EdgeInsets.all(6),
                borderRadius: BorderRadius.circular(8),
                child: RemoteImage(url: imageUrl, label: item.productName),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (item.variant != null)
                        Text(
                          item.variant!.optionSummary,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (item.hasDiscount)
                        Badgelet(
                          label: Formatters.discountBadge(
                            item.variant?.discountPercentage ?? 0,
                          ),
                          color: AppPalette.of(context).badge,
                          foreground: AppPalette.of(context).onBadge,
                        ),
                      if (item.availableStock != null &&
                          item.availableStock! <= 5)
                        Text(
                          'Only ${item.availableStock} left',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        Formatters.money(item.unitDiscountedPrice),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (item.hasDiscount) ...[
                        const SizedBox(width: 7),
                        Text(
                          Formatters.money(item.unitPrice),
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      Text(
                        '  each',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (readOnly)
                    Text(
                      'Quantity: ${item.quantity}',
                      style: theme.textTheme.bodySmall,
                    )
                  else
                    Row(
                      children: [
                        _StepperButton(
                          icon: Icons.remove_rounded,
                          tooltip: item.quantity > 1
                              ? 'Decrease quantity'
                              : 'Remove item',
                          onPressed: pending
                              ? null
                              : () => _run(context, cart.decrement(item)),
                        ),
                        Container(
                          width: 40,
                          alignment: Alignment.center,
                          child: pending
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  '${item.quantity}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                        _StepperButton(
                          icon: Icons.add_rounded,
                          tooltip: 'Increase quantity',
                          onPressed: pending || !item.canIncrease
                              ? null
                              : () => _run(context, cart.increment(item)),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          tooltip: 'Remove from cart',
                          onPressed: pending
                              ? null
                              : () => _run(context, cart.removeItem(item.id)),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.money(item.lineTotal),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppPalette.of(context).price,
                  ),
                ),
                if (item.lineSavings > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    '-${Formatters.money(item.lineSavings)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppPalette.of(context).accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Surfaces the server's rejection message, when there is one.
  Future<void> _run(BuildContext context, Future<String?> action) async {
    final failure = await action;
    if (failure == null || !context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(appSnackBar(context, ok: false, message: failure));
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      icon: Icon(icon, size: 16),
    );
  }
}

/// Totals panel, with the coupon field when the backend supports it.
class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({super.key, this.showCheckoutButton = false});

  final bool showCheckoutButton;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Order summary',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _SummaryRow(
              label: 'Items (${cart.totalQuantity})',
              value: Formatters.money(cart.cart.listSubtotal),
            ),
            if (cart.variantSavings > 0)
              _SummaryRow(
                label: 'Product discounts',
                value: '-${Formatters.money(cart.variantSavings)}',
                valueColor: AppPalette.of(context).accent,
              ),
            _SummaryRow(
              label: 'Subtotal',
              value: Formatters.money(cart.subtotal),
              emphasise: true,
            ),
            if (cart.couponDiscount > 0)
              _SummaryRow(
                label: 'Coupon ${cart.appliedDiscount?.discountCode ?? ''}',
                value: '-${Formatters.money(cart.couponDiscount)}',
                valueColor: AppPalette.of(context).accent,
              ),
            // Stated rather than left blank: no delivery charge is calculated
            // anywhere in TechZone, so the real figure is zero.
            _SummaryRow(label: 'Shipping', value: Formatters.money(0)),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  Formatters.money(cart.orderTotal),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppPalette.of(context).price,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Text(
            //   'Shipping is not calculated by the TechZone API, so it is not '
            //   'included here.',
            //   style: theme.textTheme.bodySmall?.copyWith(
            //     color: theme.colorScheme.onSurfaceVariant,
            //     height: 1.4,
            //   ),
            // ),
            const SizedBox(height: 18),
            const _CouponField(),
            if (showCheckoutButton) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => context.push('/checkout'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Proceed to checkout'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasise
        ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            value,
            style: style?.copyWith(
              color: valueColor ?? style.color,
              fontWeight: emphasise ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Coupon entry, enabled only when the backend's `/discounts/apply/` endpoint
/// actually answers. Otherwise it explains the gap rather than failing.
class _CouponField extends StatefulWidget {
  const _CouponField();

  @override
  State<_CouponField> createState() => _CouponFieldState();
}

class _CouponFieldState extends State<_CouponField> {
  final _controller = TextEditingController();
  bool _applying = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() => _applying = true);
    await context.read<CartProvider>().applyCoupon(code);
    if (mounted) setState(() => _applying = false);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final theme = Theme.of(context);

    if (cart.discountAvailability == DiscountAvailability.unknown) {
      return const SizedBox.shrink();
    }

    if (!cart.canApplyCoupon) {
      return const UnavailableNotice(
        title: 'Coupons Coming Soon',
        message:
            'We’re working on bringing you exciting discounts! '
            'Coupon codes will be available soon. Stay tuned for '
            'special offers on your favorite products.',
        icon: Icons.local_offer_outlined,
      );
    }
    final applied = cart.appliedDiscount;
    if (applied != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Icon(
              Icons.local_offer_rounded,
              size: 17,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    applied.discountName,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Saving ${Formatters.money(applied.discountAmount)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove coupon',
              onPressed: cart.removeCoupon,
              icon: const Icon(Icons.close_rounded, size: 17),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _apply(),
                decoration: const InputDecoration(
                  hintText: 'Coupon code',
                  isDense: true,
                  prefixIcon: Icon(Icons.local_offer_outlined, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 9),
            OutlinedButton(
              onPressed: _applying ? null : _apply,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              child: _applying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Apply'),
            ),
          ],
        ),
        if (cart.discountError != null) ...[
          const SizedBox(height: 8),
          Text(
            cart.discountError!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
