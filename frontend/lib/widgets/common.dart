import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/responsive.dart';

/// Full-width loading state used while a screen's first fetch is in flight.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Error state with an optional retry. Used for every failed fetch so network
/// problems always offer the same recovery path.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
    this.title = 'Something went wrong',
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 44, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 14),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty state for "no products matched", "cart is empty", and similar.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// Product/category image with a graceful placeholder.
///
/// Several `ImageField`s default to files like `products/default.jpg` that are
/// not present in `Backend/media/`, so a 404 must look deliberate rather than
/// broken.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.placeholderIcon = Icons.devices_other_rounded,
    this.label,
  });

  final String? url;
  final BoxFit fit;
  final IconData placeholderIcon;

  /// Used as the alt/semantic label and to seed the placeholder tint.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final src = url;

    if (src == null || src.isEmpty) {
      return _placeholder(context);
    }

    return Image.network(
      src,
      fit: fit,
      filterQuality: FilterQuality.low,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _shimmer(context);
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('IMAGE LOAD FAILED: $src');
        debugPrint('ERROR: $error');
        return _placeholder(context);
      },
    );
  }

  // Both fallbacks stay in the palette's pale blues rather than a grey, so a
  // missing photo still belongs on the lavender page.
  Widget _shimmer(BuildContext context) => const ColoredBox(
    color: AppColors.lavenderPalest,
    child: Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.electricBlue,
        ),
      ),
    ),
  );

  Widget _placeholder(BuildContext context) {
    // Vary the placeholder's depth from the label so a grid of them is not
    // uniform — lightness only, so no stray hue enters the palette.
    final seed = (label ?? '').hashCode.abs() % 3;
    final top = [
      AppColors.white,
      AppColors.lavenderPalest,
      AppColors.lavenderPale,
    ][seed];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, AppColors.softBlue],
        ),
      ),
      child: Center(
        child: Icon(placeholderIcon, size: 34, color: AppColors.charcoalMuted),
      ),
    );
  }
}

/// The white plate product and category photos sit on.
///
/// Catalogue photography is shot on white, so the image area matches the card
/// exactly and the tile reads as one clean rectangle. Padding is inside the
/// plate, so the plate — not the card — frames the image.
class ImagePlate extends StatelessWidget {
  const ImagePlate({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.of(context).imagePlate,
        borderRadius: borderRadius,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Result snackbar: brand green for success, error red for failure.
///
/// Both outcomes set their own foreground, because neither fill is readable
/// with the other's text colour.
SnackBar appSnackBar(
  BuildContext context, {
  required String message,
  required bool ok,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final palette = AppPalette.of(context);
  final scheme = Theme.of(context).colorScheme;
  final background = ok ? palette.success : scheme.error;
  final foreground = ok ? palette.onSuccess : scheme.onError;

  return SnackBar(
    backgroundColor: background,
    content: Text(
      message,
      style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
    ),
    action: actionLabel == null || onAction == null
        ? null
        : SnackBarAction(
            label: actionLabel,
            // The themed action colour is tuned for the dark default
            // snackbar, not for these fills.
            textColor: foreground,
            onPressed: onAction,
          ),
  );
}

/// Keeps a screen's data current without the customer reloading the page.
///
/// Calls [onRefresh] when the tab comes back into focus and on a slow timer
/// while it is visible, so a product added in the admin — or a photo uploaded
/// for one already listed — appears on its own. The callback is expected to
/// refetch quietly: this never shows a spinner of its own.
class AutoRefresh extends StatefulWidget {
  const AutoRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.interval = const Duration(seconds: 30),
  });

  final VoidCallback onRefresh;
  final Widget child;
  final Duration interval;

  @override
  State<AutoRefresh> createState() => _AutoRefreshState();
}

class _AutoRefreshState extends State<AutoRefresh> with WidgetsBindingObserver {
  Timer? _timer;

  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On the web this follows the browser tab's visibility. There is no point
    // polling a tab nobody is looking at, and letting requests pile up behind
    // a hidden tab is how a background refresh turns into a stall.
    if (state == AppLifecycleState.resumed) {
      _start();
      _refresh();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _refresh() {
    if (!mounted) return;

    final route = _route;
    if (route != null && !route.isCurrent) return;

    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Small pill label, e.g. a discount badge or stock status.
class Badgelet extends StatelessWidget {
  const Badgelet({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.foreground,
  });

  final String label;
  final Color? color;
  final Color? foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? scheme.secondaryContainer;
    final fg = foreground ?? scheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          // Flexible so a long savings label is clipped rather than
          // overflowing the tile it is pinned to.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Inline notice explaining that a backend capability is not available.
///
/// Used wherever the frontend is ready but the API is not — the discounts and
/// orders endpoints — so the gap is stated plainly instead of looking broken.
class UnavailableNotice extends StatelessWidget {
  const UnavailableNotice({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
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

/// Star rating display.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.rating, this.size = 15});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final starColor = AppPalette.of(context).rating;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = rating >= index + 1;
        final half = !filled && rating > index && rating < index + 1;
        return Icon(
          half
              ? Icons.star_half_rounded
              : filled
              ? Icons.star_rounded
              : Icons.star_outline_rounded,
          size: size,
          color: starColor,
        );
      }),
    );
  }
}

/// Responsive two-column layout: side by side on desktop, stacked elsewhere.
class SplitLayout extends StatelessWidget {
  const SplitLayout({
    super.key,
    required this.primary,
    required this.secondary,
    this.secondaryWidth = 360,
    this.gap = 24,
  });

  final Widget primary;
  final Widget secondary;
  final double secondaryWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (!Responsive.isDesktop(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primary,
          SizedBox(height: gap),
          secondary,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: primary),
        SizedBox(width: gap),
        SizedBox(width: secondaryWidth, child: secondary),
      ],
    );
  }
}
