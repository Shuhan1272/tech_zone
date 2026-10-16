import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/utils/responsive.dart';
import '../../providers/account_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/common.dart';
import '../cart/cart_screen.dart';

/// Checkout review.
///
/// This screen stops short of placing an order, and says so plainly, because
/// the backend has no order API: the `order` app contains no models,
/// serializers, views or urls, and `config/urls.py` routes nothing for it.
/// Everything that *can* be confirmed — the line items, the server's prices
/// and the shipping address — is shown and verified here, so wiring up a
/// `POST /api/v1/orders/` later is the only remaining step.
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cart = context.watch<CartProvider>();
    final account = context.watch<AccountProvider>();
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
                  title: 'Place your order',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const UnavailableNotice(
                        title: 'Order placement is not available yet',
                        message:
                            'The TechZone backend has no order API: the '
                            'order app has no models, serializers, views or '
                            'URLs, and nothing is routed at '
                            '/api/v1/orders/. Your cart and address are saved '
                            'on the server, so nothing is lost — this step '
                            'will work as soon as the order endpoint exists.',
                        icon: Icons.receipt_long_outlined,
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        // Deliberately disabled: there is no endpoint to call,
                        // and faking a success would misreport the outcome.
                        onPressed: null,
                        icon: const Icon(Icons.lock_outline_rounded, size: 18),
                        label: const Text('Place order — not yet available'),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No payment integration is wired up either; the '
                        'backend defines no payment models or endpoints.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.45,
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
