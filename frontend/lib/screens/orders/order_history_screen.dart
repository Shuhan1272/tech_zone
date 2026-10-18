import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/order_status_chip.dart';

/// Order history: every order this customer has placed, newest first.
///
/// The list payload is deliberately compact — it carries a one-line summary
/// and the total, not the items — so a row links through to the detail page
/// rather than trying to show everything at once.
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Loading is kicked off after the first frame, never during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!context.read<AuthProvider>().isSignedIn) return;
      context.read<OrderProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final orders = context.watch<OrderProvider>();
    final theme = Theme.of(context);

    if (!auth.isSignedIn) {
      return PageContainer(
        child: EmptyState(
          title: 'Sign in to see your orders',
          message: 'Your order history is tied to your TechZone account.',
          icon: Icons.lock_outline_rounded,
          action: FilledButton.icon(
            onPressed: () => context.push('/login?next=/account/orders'),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Sign in'),
          ),
        ),
      );
    }

    if (orders.isLoadingHistory && orders.isEmpty) {
      return const PageContainer(
        child: LoadingState(message: 'Loading your orders…'),
      );
    }

    if (orders.historyError != null && orders.isEmpty) {
      return PageContainer(
        child: ErrorState(
          message: orders.historyError!,
          onRetry: () => context.read<OrderProvider>().loadHistory(force: true),
        ),
      );
    }

    if (orders.isEmpty) {
      return PageContainer(
        child: EmptyState(
          title: 'No orders yet',
          message:
              'When you place your first order it will show up here, with '
              'its order number and delivery details.',
          icon: Icons.receipt_long_outlined,
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
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/account'),
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: const Text('Back to account'),
            ),
          ),
          const SizedBox(height: 6),
          SectionHeader(
            title: 'Your orders',
            subtitle: orders.count == 1 ? '1 order' : '${orders.count} orders',
            action: IconButton(
              tooltip: 'Refresh',
              onPressed: orders.isLoadingHistory
                  ? null
                  : () =>
                        context.read<OrderProvider>().loadHistory(force: true),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          if (orders.historyError != null) ...[
            UnavailableNotice(
              title: 'Could not refresh',
              message: orders.historyError!,
              icon: Icons.cloud_off_rounded,
            ),
            const SizedBox(height: 14),
          ],
          for (final order in orders.orders)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OrderRow(order: order),
            ),
          if (orders.hasMore) ...[
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: orders.isLoadingMore
                  ? null
                  : () => context.read<OrderProvider>().loadMore(),
              icon: orders.isLoadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded, size: 18),
              label: Text(
                orders.isLoadingMore ? 'Loading…' : 'Load more orders',
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Need to change or cancel an order? Contact us with your order '
            'number and we will sort it out.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/account/orders/${order.orderNumber}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderNumber,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          Formatters.dateTime(order.placedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  OrderStatusChip(order: order),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.summary.isEmpty
                              ? 'Order details'
                              : order.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          order.totalQuantity == 1
                              ? '1 item'
                              : '${order.totalQuantity} items',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.money(order.grandTotal),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: palette.price,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'View details',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 17,
                            color: palette.accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
