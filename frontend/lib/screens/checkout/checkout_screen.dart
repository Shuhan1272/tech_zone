import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../providers/account_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/common.dart';
import '../cart/cart_screen.dart';

/// Checkout.
///
/// Places the cart as an order through `POST /api/v1/orders/`. Note what this
/// screen does *not* send: no prices, no totals, no item list. The server
/// reads the cart itself, prices it from the catalogue, checks stock, writes
/// the order and empties the cart — all in one transaction — so the only
/// thing the client decides is the payment method.
///
/// Cash on delivery is the only method, and an order comes back *unpaid*:
/// placing an order does not pay for it, and nothing here pretends it does.
///
/// Success is whatever the server says it is. The cart is cleared and the
/// customer is moved on only after an order number comes back.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.read<AuthProvider>().isSignedIn) return;
      context.read<CartProvider>().load();
      context.read<AccountProvider>().load();
    });
  }

  /// Sends the order, then acts only on what the server answered.
  Future<void> _placeOrder() async {
    final orders = context.read<OrderProvider>();
    final cart = context.read<CartProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    // The provider refuses a re-entrant call too; the disabled button is only
    // the visible half of the same guard.
    if (orders.isPlacing) return;

    final order = await orders.placeOrder();

    if (!mounted) return;

    if (order == null) {
      messenger.showSnackBar(
        appSnackBar(
          context,
          message:
              orders.placeError ??
              'We could not place your order. Please try again.',
          ok: false,
        ),
      );

      // The server is the authority on the cart, so re-read it rather than
      // guessing what the failure did or did not change.
      await cart.load();
      return;
    }

    messenger.showSnackBar(
      appSnackBar(
        context,
        message:
            'Order ${order.orderNumber} placed. '
            'Pay ${Formatters.money(order.grandTotal)} on delivery.',
        ok: true,
      ),
    );

    router.go('/account/orders/${order.orderNumber}');

    // Only now is the cart cleared locally: the backend emptied it inside the
    // same transaction that wrote the order.
    cart.load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cart = context.watch<CartProvider>();
    final account = context.watch<AccountProvider>();
    final orders = context.watch<OrderProvider>();
    final theme = Theme.of(context);

    if (!auth.isSignedIn) {
      return PageContainer(
        child: EmptyState(
          title: 'Sign in to check out',
          message: 'You need an account to review and place an order.',
          icon: Icons.lock_outline_rounded,
          action: FilledButton.icon(
            onPressed: () => context.push('/login?next=/checkout'),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Sign in'),
          ),
        ),
      );
    }

    if (cart.isLoading && cart.isEmpty) {
      return const PageContainer(
        child: LoadingState(message: 'Loading your order…'),
      );
    }

    if (cart.isEmpty) {
      return PageContainer(
        child: EmptyState(
          title: 'Nothing to check out',
          message: 'Your cart is empty. Add something first.',
          icon: Icons.remove_shopping_cart_outlined,
          action: FilledButton.icon(
            onPressed: () => context.go('/catalog'),
            icon: const Icon(Icons.storefront_rounded, size: 18),
            label: const Text('Browse products'),
          ),
        ),
      );
    }

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Checkout',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Review your items and delivery details.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          SplitLayout(
            secondaryWidth: 350,
            primary: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepCard(
                  step: 1,
                  title: 'Delivery address',
                  trailing: TextButton.icon(
                    onPressed: () => context.push('/account/address'),
                    icon: Icon(
                      account.hasAddress
                          ? Icons.edit_outlined
                          : Icons.add_rounded,
                      size: 17,
                    ),
                    label: Text(account.hasAddress ? 'Edit' : 'Add'),
                  ),
                  child: account.isLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: LinearProgressIndicator(),
                        )
                      : account.hasAddress
                      ? _AddressBlock(account: account)
                      : UnavailableNotice(
                          title: 'No delivery address on file',
                          message:
                              'Add a shipping address to your account so '
                              'your order can be delivered.',
                          icon: Icons.location_off_outlined,
                        ),
                ),
                const SizedBox(height: 14),
                _StepCard(
                  step: 2,
                  title: 'Items (${cart.totalQuantity})',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in cart.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CartLineTile(item: item, readOnly: true),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => context.push('/cart'),
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: const Text('Edit cart'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _StepCard(
                  step: 3,
                  title: 'Payment and confirmation',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _CashOnDeliveryBlock(),
                      if (orders.placeError != null) ...[
                        const SizedBox(height: 14),
                        UnavailableNotice(
                          title: 'Order not placed',
                          message: orders.placeError!,
                          icon: Icons.error_outline_rounded,
                        ),
                      ],
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        // Disabled while a submission is in flight, so a
                        // second tap cannot start a second order.
                        onPressed:
                            orders.isPlacing ||
                                !account.hasAddress ||
                                cart.isEmpty
                            ? null
                            : _placeOrder,
                        icon: orders.isPlacing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          orders.isPlacing
                              ? 'Placing your order…'
                              : 'Place order — '
                                    '${Formatters.money(cart.orderTotal)}',
                        ),
                      ),
                      if (!account.hasAddress) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Add a delivery address in step 1 before placing '
                          'your order.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        'Your order is confirmed by TechZone before anything '
                        'is reserved for you. You will get an order number '
                        'you can quote to us.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            secondary: const OrderSummaryCard(),
          ),
        ],
      ),
    );
  }
}

/// The payment method, of which there is exactly one.
///
/// Rendered as a selected option rather than plain text so that adding bKash
/// or a card later is a matter of adding siblings, not redesigning the step.
class _CashOnDeliveryBlock extends StatelessWidget {
  const _CashOnDeliveryBlock();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: palette.accent, width: 1.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.radio_button_checked_rounded,
                size: 20,
                color: palette.accent,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cash on Delivery',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Pay in cash when your order reaches you. Nothing is '
                      'charged now.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.payments_outlined, size: 20, color: palette.accent),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 15,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Online payment is not available yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddressBlock extends StatelessWidget {
  const _AddressBlock({required this.account});

  final AccountProvider account;

  @override
  Widget build(BuildContext context) {
    final address = account.address!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          address.recipient,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (address.company.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(address.company, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 6),
        Text(
          address.formatted,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.child,
    this.trailing,
  });

  final int step;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$step',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
