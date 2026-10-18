import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/order.dart';
import 'common.dart';

/// The small status pill used by the order history and the order detail page.
///
/// The *text* is always the label the server sent, so a status this build has
/// not been taught about still reads correctly; only the colour and icon are
/// chosen locally.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final scheme = Theme.of(context).colorScheme;

    late final Color background;
    late final Color foreground;
    late final IconData icon;

    switch (order.status) {
      case OrderStatus.pending:
        background = scheme.secondaryContainer;
        foreground = scheme.onSecondaryContainer;
        icon = Icons.schedule_rounded;

      case OrderStatus.confirmed:
        background = palette.accent;
        foreground = palette.onBadge;
        icon = Icons.check_circle_outline_rounded;

      case OrderStatus.processing:
        background = palette.accent;
        foreground = palette.onBadge;
        icon = Icons.inventory_2_outlined;

      case OrderStatus.shipped:
        background = palette.accent;
        foreground = palette.onBadge;
        icon = Icons.local_shipping_outlined;

      case OrderStatus.delivered:
        background = palette.success;
        foreground = palette.onSuccess;
        icon = Icons.task_alt_rounded;

      case OrderStatus.cancelled:
        background = scheme.errorContainer;
        foreground = scheme.onErrorContainer;
        icon = Icons.cancel_outlined;

      case OrderStatus.unknown:
        background = scheme.secondaryContainer;
        foreground = scheme.onSecondaryContainer;
        icon = Icons.help_outline_rounded;
    }

    final label = order.statusDisplay.trim().isEmpty
        ? order.status.name
        : order.statusDisplay;

    return Badgelet(
      label: label,
      color: background,
      foreground: foreground,
      icon: icon,
    );
  }
}

/// "Cash on Delivery · Unpaid" — the payment state, stated plainly.
///
/// A cash-on-delivery order is unpaid until the money is actually collected,
/// and this never pretends otherwise.
class PaymentStateChip extends StatelessWidget {
  const PaymentStateChip({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final scheme = Theme.of(context).colorScheme;

    final paid = order.isPaid;

    final method = order.paymentMethodDisplay.trim().isEmpty
        ? order.paymentMethod
        : order.paymentMethodDisplay;

    final state = order.paymentStatusDisplay.trim().isEmpty
        ? order.paymentStatus
        : order.paymentStatusDisplay;

    return Badgelet(
      label: '$method · $state',
      color: paid ? palette.success : scheme.secondaryContainer,
      foreground: paid ? palette.onSuccess : scheme.onSecondaryContainer,
      icon: paid ? Icons.verified_outlined : Icons.payments_outlined,
    );
  }
}
