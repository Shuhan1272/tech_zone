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

/// One order in full: what was bought, at what price, and where it is going.
///
/// Every figure on this page was calculated by the server at the moment the
/// order was placed. Nothing is recomputed here, and nothing is read from the
/// live catalogue, so the page still shows what the customer actually agreed
/// to even after prices change.
class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key, required this.orderNumber});

  final String orderNumber;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(OrderDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderNumber != widget.orderNumber) _load();
  }

  void _load() {
    if (!mounted) return;
    if (!context.read<AuthProvider>().isSignedIn) return;
    context.read<OrderProvider>().loadDetail(widget.orderNumber);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final orders = context.watch<OrderProvider>();

    if (!auth.isSignedIn) {
      return PageContainer(
        child: EmptyState(
          title: 'Sign in to see this order',
          message: 'Orders are only visible to the account that placed them.',
          icon: Icons.lock_outline_rounded,
          action: FilledButton.icon(
            onPressed: () => context.push(
              '/login?next=/account/orders/${widget.orderNumber}',
            ),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Sign in'),
          ),
        ),
      );
    }

    final order = orders.detail(widget.orderNumber);
    final error = orders.detailError(widget.orderNumber);

    if (order == null && orders.isLoadingDetail(widget.orderNumber)) {
      return const PageContainer(
        child: LoadingState(message: 'Loading your order…'),
      );
    }

    if (order == null && error != null) {
      return PageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ErrorState(
              title: 'Order not available',
              message: error,
              onRetry: () => context.read<OrderProvider>().loadDetail(
                widget.orderNumber,
                force: true,
              ),
            ),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => context.go('/account/orders'),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('All orders'),
              ),
            ),
          ],
        ),
      );
    }

    if (order == null) {
      return const PageContainer(
        child: LoadingState(message: 'Loading your order…'),
      );
    }

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/account/orders'),
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: const Text('All orders'),
            ),
          ),
          const SizedBox(height: 6),
          _Heading(order: order),
          const SizedBox(height: 20),
          SplitLayout(
            secondaryWidth: 350,
            primary: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ItemsCard(order: order),
                const SizedBox(height: 14),
                _AddressCard(order: order),
                if (order.customerNote.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _NoteCard(note: order.customerNote),
                ],
              ],
            ),
            secondary: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummaryCard(order: order),
                const SizedBox(height: 12),
                _PaymentCard(order: order),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              order.orderNumber,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            OrderStatusChip(order: order),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Placed ${Formatters.dateTime(order.placedAt)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (order.status.isCancelled) ...[
          const SizedBox(height: 14),
          const UnavailableNotice(
            title: 'This order was cancelled',
            message:
                'The items have been returned to stock. Nothing was charged '
                'for this order.',
            icon: Icons.cancel_outlined,
          ),
        ],
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.title, required this.child, this.icon});

  final String title;
  final Widget child;
  final IconData? icon;

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
                if (icon != null) ...[
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _OrderCard(
      title: order.totalQuantity == 1
          ? 'Item (1)'
          : 'Items (${order.totalQuantity})',
      icon: Icons.inventory_2_outlined,
      child: order.items.isEmpty
          ? Text(
              'This order has no line items.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < order.items.length; i++) ...[
                  if (i > 0) const Divider(height: 22),
                  _ItemLine(item: order.items[i]),
                ],
              ],
            ),
    );
  }
}

class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final slug = item.productSlug;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Links back to the product where we still know its slug, but
              // the name shown is the snapshot, not today's catalogue name.
              if (slug != null && slug.isNotEmpty)
                InkWell(
                  onTap: () => context.push('/product/$slug'),
                  child: Text(
                    item.productName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: palette.accent,
                      height: 1.35,
                    ),
                  ),
                )
              else
                Text(
                  item.productName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              if (item.optionLabel.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  item.optionLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 5),
              Text(
                '${Formatters.money(item.unitPricePaid)} × ${item.quantity}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (item.hasDiscount) ...[
                const SizedBox(height: 4),
                Text(
                  'List ${Formatters.money(item.unitPrice)} — saved '
                  '${Formatters.money(item.lineSavings)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.successText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          Formatters.money(item.lineTotal),
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final address = order.shippingAddress;

    return _OrderCard(
      title: 'Delivery address',
      icon: Icons.location_on_outlined,
      child: address == null
          ? Text(
              'No delivery address was recorded for this order.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
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
                if (address.phone.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.call_outlined,
                        size: 15,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(address.phone, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'This is the address as it was when the order was placed. '
                  'Changing your account address later does not change it.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return _OrderCard(
      title: 'Your note',
      icon: Icons.sticky_note_2_outlined,
      child: Text(
        note,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return _OrderCard(
      title: 'Order summary',
      icon: Icons.receipt_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MoneyRow(
            label: 'Items (${order.totalQuantity})',
            value: Formatters.money(order.itemsSubtotal),
          ),
          if (order.productDiscountTotal > 0)
            _MoneyRow(
              label: 'Product discounts',
              value: '-${Formatters.money(order.productDiscountTotal)}',
              valueColor: palette.accent,
            ),
          if (order.couponDiscount > 0)
            _MoneyRow(
              label: 'Coupon',
              value: '-${Formatters.money(order.couponDiscount)}',
              valueColor: palette.accent,
            ),
          // Shown even though it is zero: a blank line would leave the
          // customer wondering what delivery costs.
          _MoneyRow(
            label: 'Shipping',
            value: Formatters.money(order.shippingFee),
          ),
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
                Formatters.money(order.grandTotal),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: palette.price,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _OrderCard(
      title: 'Payment',
      icon: Icons.payments_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: PaymentStateChip(order: order),
          ),
          const SizedBox(height: 10),
          Text(
            order.isCashOnDelivery && !order.isPaid
                ? 'Pay ${Formatters.money(order.grandTotal)} in cash when '
                      'your order is delivered.'
                : 'Payment handled outside the storefront.',
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

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
