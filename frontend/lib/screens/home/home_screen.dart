import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../models/catalog.dart';
import '../../models/product.dart';
import '../../providers/catalog_provider.dart';
import '../../services/product_service.dart';
import '../../widgets/common.dart';
import '../../widgets/product_card.dart';

/// Storefront landing page: live notices, category tiles and the product
/// grid, which runs straight into a "Show all" link to the full catalogue.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ProductListProvider _products;

  @override
  void initState() {
    super.initState();
    final service = context.read<ProductService>();

    // One listing: the store's products, newest first. Enough for the four
    // rows the widest breakpoint draws before the "Show all" button.
    _products = ProductListProvider(service);
    // Not awaited: the screen renders the provider's own loading state.
    unawaited(
      _products.applyQuery(
        const ProductQuery(sort: ProductSort.newest, pageSize: 24),
      ),
    );
  }

  @override
  void dispose() {
    _products.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();

    return AutoRefresh(
      onRefresh: () {
        // Both halves of the page: the reference data behind the category
        // tiles and the image index, and the product grid itself.
        catalog.load(force: true, silent: true);
        _products.refreshSilently();
      },
      child: _buildPage(context, catalog),
    );
  }

  Widget _buildPage(BuildContext context, CatalogProvider catalog) {
    // The listing is provided around the whole page, not just the grid: the
    // hero's showcase is built from the same products, so the artwork is real
    // catalogue photography rather than stock images.
    return ChangeNotifierProvider.value(
      value: _products,
      child: PageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final notice in catalog.notices.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _NoticeBanner(notice: notice),
              ),
            const _Hero(),
            const SizedBox(height: 36),
            if (catalog.isLoading && catalog.categories.isEmpty)
              const LoadingState(message: 'Loading the TechZone catalog…')
            else if (catalog.error != null && catalog.categories.isEmpty)
              ErrorState(
                message: catalog.error!,
                onRetry: () => catalog.load(force: true),
              )
            else ...[
              if (catalog.categories.isNotEmpty) ...[
                const SectionHeader(
                  title: 'Shop by category',
                  subtitle: 'Browse the full TechZone range.',
                ),
                _CategoryTiles(categories: catalog.categories),
                const SizedBox(height: 36),
              ],
              const _ProductSection(),
            ],
          ],
        ),
      ),
    );
  }
}

/// The landing banner: the storefront's pitch on the left, real catalogue
/// photography on the right, over a strip of what the store actually does.
///
/// The artwork is not a stock image. It is the newest products the API just
/// returned, drawn from the same image index the grid below uses, so the
/// banner can never show a picture the shop does not sell — and never a
/// broken external URL.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    // Three products for the showcase. Fewer (or none, before the first
    // response lands) simply leaves the cards on their placeholder.
    final showcase = context
        .watch<ProductListProvider>()
        .products
        .take(3)
        .toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_HeroStyle.radius),
            border: Border.all(color: AppColors.softBlue),
            // White into ice blue, on the diagonal: the panel lifts off the
            // page without ever becoming a dark block.
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.white,
                AppColors.lavenderPalest,
                AppColors.lavender,
              ],
              stops: [0, 0.55, 1],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14233876),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            // passthrough, so the content below is laid out at the banner's
            // full width instead of shrinking to its widest line.
            fit: StackFit.passthrough,
            children: [
              const Positioned(top: -110, right: -70, child: _HeroGlow(300)),
              const Positioned(bottom: -120, left: -80, child: _HeroGlow(240)),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 40 : 22,
                  vertical: isDesktop ? 44 : 30,
                ),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(flex: 6, child: _HeroCopy()),
                          const SizedBox(width: 40),
                          Expanded(
                            flex: 5,
                            child: _HeroShowcase(products: showcase),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          const _HeroCopy(centred: true),
                          const SizedBox(height: 30),
                          _HeroShowcase(products: showcase),
                        ],
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _HeroPoints(),
      ],
    );
  }
}

/// Shared shape and motion values, so the banner's parts stay in step.
class _HeroStyle {
  const _HeroStyle._();

  static const double radius = 18;
  static const double cardRadius = 16;
  static const Duration hover = Duration(milliseconds: 180);

  static const List<BoxShadow> cardRest = [
    BoxShadow(color: Color(0x0F233876), blurRadius: 16, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> cardHover = [
    BoxShadow(color: Color(0x24233876), blurRadius: 26, offset: Offset(0, 12)),
  ];
}

/// Tracks the pointer over its child and hands the state to [builder].
///
/// Hover only exists on desktop, so this is purely additive: on a phone the
/// builder is simply never called with `true`.
class _Hoverable extends StatefulWidget {
  const _Hoverable({required this.builder});

  final Widget Function(BuildContext context, bool hovered) builder;

  @override
  State<_Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<_Hoverable> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.builder(context, _hovered),
    );
  }
}

/// Left column: the pitch and its two calls to action.
class _HeroCopy extends StatelessWidget {
  const _HeroCopy({this.centred = false});

  /// Stacked layouts read better centred; the two-column one does not.
  final bool centred;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final align = centred ? TextAlign.center : TextAlign.start;

    return Column(
      crossAxisAlignment: centred
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        const _HeroEyebrow(),
        SizedBox(height: isMobile ? 16 : 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            'Technology that keeps up with you',
            textAlign: align,
            style:
                (isMobile
                        ? theme.textTheme.headlineSmall
                        : theme.textTheme.displaySmall)
                    ?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: -0.9,
                    ),
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Text(
            'Laptops, desktops, cameras, home appliances and everyday '
            'gadgets — with live stock and real prices.',
            textAlign: align,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ),
        SizedBox(height: isMobile ? 22 : 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: centred ? WrapAlignment.center : WrapAlignment.start,
          children: [
            FilledButton.icon(
              onPressed: () => context.go('/catalog'),
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: const Text('Shop all products'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/catalog?featured=true'),
              icon: const Icon(Icons.star_outline_rounded, size: 18),
              label: const Text('See featured'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Right column: one large product card flanked by two smaller ones.
class _HeroShowcase extends StatelessWidget {
  const _HeroShowcase({required this.products});

  final List<Product> products;

  Product? _at(int index) => index < products.length ? products[index] : null;

  @override
  Widget build(BuildContext context) {
    // Capped so the collage keeps its proportions on an ultrawide monitor
    // and does not tower over the copy beside it.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: AspectRatio(
          aspectRatio: 1.12,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 11,
                child: _ShowcaseCard(product: _at(0), large: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _ShowcaseCard(product: _at(1))),
                    const SizedBox(height: 12),
                    Expanded(child: _ShowcaseCard(product: _at(2))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One product tile in the hero collage.
///
/// Tapping it opens that product, so the artwork is part of the storefront
/// rather than decoration.
class _ShowcaseCard extends StatelessWidget {
  const _ShowcaseCard({required this.product, this.large = false});

  final Product? product;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final item = product;

    final imageUrl = item == null
        ? null
        : context.select<CatalogProvider, String?>(
            (catalog) => catalog.primaryImageFor(item.id),
          );

    final variant = item?.primaryVariant;

    return _Hoverable(
      builder: (context, hovered) => AnimatedContainer(
        duration: _HeroStyle.hover,
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, hovered ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(_HeroStyle.cardRadius),
          border: Border.all(
            color: hovered ? AppColors.electricBlue : AppColors.softBlue,
          ),
          boxShadow: hovered ? _HeroStyle.cardHover : _HeroStyle.cardRest,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: item == null
                ? null
                : () => context.push('/product/${item.slug}', extra: item),
            child: Padding(
              padding: EdgeInsets.all(large ? 14 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: RemoteImage(
                      url: imageUrl,
                      label: item?.name,
                      placeholderIcon: Icons.devices_other_rounded,
                    ),
                  ),
                  if (large && item != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.charcoal,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      Formatters.money(variant?.discountedPrice),
                      maxLines: 1,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: palette.price,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A blurred-looking disc of brand blue, used behind the hero copy.
class _HeroGlow extends StatelessWidget {
  const _HeroGlow(this.size);

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.electricBlue.withValues(alpha: 0.10),
            AppColors.electricBlue.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// Small pill above the headline.
class _HeroEyebrow extends StatelessWidget {
  const _HeroEyebrow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.softBlue),
        borderRadius: BorderRadius.circular(100),
        boxShadow: _HeroStyle.cardRest,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 15, color: AppColors.electricBlue),
          SizedBox(width: 5),
          // Flexible so the pill narrows with the page instead of pushing
          // past it on a small phone or at a large text scale.
          Flexible(
            child: Text(
              'Live stock · Real prices',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.electricBlue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The three things the storefront does, as one strip under the banner.
class _HeroPoints extends StatelessWidget {
  const _HeroPoints();

  static const _points = <(IconData, String, String)>[
    (Icons.inventory_2_outlined, 'Live stock', 'Straight from the warehouse'),
    (Icons.sell_outlined, 'Per-variant pricing', 'Discounts applied for you'),
    (Icons.tune_rounded, 'Deep filters', 'Brand, category, specification'),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    if (isMobile) {
      return Column(
        children: [
          for (final (index, point) in _points.indexed) ...[
            if (index > 0) const SizedBox(height: 10),
            _HeroPoint(icon: point.$1, title: point.$2, detail: point.$3),
          ],
        ],
      );
    }

    // IntrinsicHeight so the three cards match the tallest of them; a bare
    // stretch would ask for infinite height inside the page's scrolling
    // column.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, point) in _points.indexed) ...[
            if (index > 0) const SizedBox(width: 14),
            Expanded(
              child: _HeroPoint(
                icon: point.$1,
                title: point.$2,
                detail: point.$3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroPoint extends StatelessWidget {
  const _HeroPoint({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Hoverable(
      builder: (context, hovered) => AnimatedContainer(
        duration: _HeroStyle.hover,
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, hovered ? -2 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(
            color: hovered ? AppColors.electricBlue : AppColors.softBlue,
          ),
          borderRadius: BorderRadius.circular(_HeroStyle.cardRadius),
          boxShadow: hovered ? _HeroStyle.cardHover : _HeroStyle.cardRest,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: _HeroStyle.hover,
              curve: Curves.easeOut,
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: hovered ? AppColors.electricBlue : AppColors.softBlue,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: hovered
                      ? const [AppColors.electricBlue, AppColors.blueDeep]
                      : const [AppColors.white, AppColors.lavenderPale],
                ),
              ),
              child: Icon(
                icon,
                size: 19,
                color: hovered ? AppColors.white : AppColors.electricBlue,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.charcoal,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Notice type drives the accent so promotions read differently from
    // system messages. Each one carries its own foreground, because these
    // fills are brand colours rather than surfaces.
    final scheme = theme.colorScheme;
    final (color, foreground, icon) = switch (notice.noticeType) {
      'promotion' => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.campaign_outlined,
      ),
      'order' => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.local_shipping_outlined,
      ),
      'system' => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.build_outlined,
      ),
      'announcement' => (
        scheme.surfaceContainerHigh,
        scheme.onSurface,
        Icons.info_outline_rounded,
      ),
      _ => (
        scheme.surfaceContainerHigh,
        scheme.onSurface,
        Icons.notifications_none_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: foreground),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                if (notice.message.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    notice.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.45,
                      color: foreground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact category tiles: an icon over a label, many to a row.
class _CategoryTiles extends StatelessWidget {
  const _CategoryTiles({required this.categories});

  final List<Category> categories;

  /// Gutter between tiles, horizontally and between rows.
  static const double _gap = 14;

  /// Height of the icon area inside a tile.
  static const double _iconHeight = 46;

  /// Most tiles a row may hold at this breakpoint.
  static int _maxColumns(BuildContext context) =>
      switch (Responsive.of(context)) {
        ScreenSize.mobile => 3,
        ScreenSize.tablet => 5,
        ScreenSize.desktop => 7,
        ScreenSize.wide => 8,
      };

  /// Tile height for a given tile width.
  ///
  /// Tiles stretch to fill their row, so with only a handful of categories a
  /// fixed height would leave each one a long letterbox. Tying height to
  /// width — within bounds — keeps the icon-over-label proportions of a full
  /// row whatever the catalogue holds.
  static double _tileHeight(double width) => (width * 0.8).clamp(112, 136);

  /// Columns to lay the tiles out in.
  ///
  /// Prefers a count that divides the list exactly, so no row is left with a
  /// hole in it; failing that, it spreads the tiles as evenly as the number
  /// of rows allows (13 tiles over 2 rows becomes 7 and 6, not 8 and 5).
  static int _columnsFor(BuildContext context, int count) {
    final max = _maxColumns(context);
    if (count <= max) return count;

    for (var columns = max; columns >= max - 2 && columns > 1; columns--) {
      if (count % columns == 0) return columns;
    }

    final rows = (count / max).ceil();
    return (count / rows).ceil();
  }

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final columns = _columnsFor(context, categories.length);

    // Computed, not measured with a LayoutBuilder: each tile is an InkWell,
    // and a LayoutBuilder rebuilding hoverable children from inside the layout
    // phase is what tears the frame apart when the pointer leaves one while
    // the page is changing. See Responsive.contentWidth.
    final tileWidth =
        (Responsive.contentWidth(context) - _gap * (columns - 1)) / columns;
    final tileHeight = _tileHeight(tileWidth);

    // Wrap rather than a grid: a short last row centres itself instead of
    // leaving a gap hanging off one end.
    return Wrap(
      spacing: _gap,
      runSpacing: _gap,
      alignment: WrapAlignment.center,
      children: [
        for (final category in categories)
          SizedBox(
            width: tileWidth,
            height: tileHeight,
            child: _CategoryTile(category: category),
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final Category category;

  /// Keyword → icon, longest-matching keyword first so "mobile accessories"
  /// does not land on the phone icon.
  static const _iconKeywords = <String, IconData>{
    'air condition': Icons.ac_unit_rounded,
    'mobile accessor': Icons.cable_rounded,
    'power station': Icons.battery_charging_full_rounded,
    'health': Icons.monitor_heart_outlined,
    'appliance': Icons.kitchen_outlined,
    'refriger': Icons.kitchen_outlined,
    'fridge': Icons.kitchen_outlined,
    'desktop': Icons.desktop_windows_outlined,
    'computer': Icons.desktop_windows_outlined,
    'laptop': Icons.laptop_outlined,
    'notebook': Icons.laptop_outlined,
    'monitor': Icons.monitor_outlined,
    'phone': Icons.smartphone_outlined,
    'mobile': Icons.smartphone_outlined,
    'tablet': Icons.tablet_mac_outlined,
    'watch': Icons.watch_outlined,
    'camera': Icons.photo_camera_outlined,
    'earbud': Icons.headphones_outlined,
    'headphone': Icons.headphones_outlined,
    'audio': Icons.speaker_outlined,
    'speaker': Icons.speaker_outlined,
    'router': Icons.router_outlined,
    'network': Icons.router_outlined,
    'wifi': Icons.wifi_rounded,
    'printer': Icons.print_outlined,
    'gaming': Icons.sports_esports_outlined,
    'game': Icons.sports_esports_outlined,
    'drone': Icons.airplanemode_active_rounded,
    'fan': Icons.mode_fan_off_outlined,
    'light': Icons.lightbulb_outline_rounded,
    'gadget': Icons.devices_other_outlined,
    'accessor': Icons.cable_rounded,
    'tv': Icons.tv_outlined,
    'ac': Icons.ac_unit_rounded,
  };

  /// Icon for a category with no artwork of its own.
  ///
  /// Only a fallback: an uploaded image always wins. It exists so a category
  /// nobody has given a picture to still reads as that category rather than
  /// as a generic box.
  static IconData _iconFor(String name) {
    final needle = name.toLowerCase();
    for (final entry in _iconKeywords.entries) {
      if (needle.contains(entry.key)) return entry.value;
    }
    return Icons.category_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.go('/catalog?category=${category.slug}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Square box: the category artwork is square, and it keeps the
              // fallback from spreading into a band across a wide tile.
              SizedBox(
                width: _CategoryTiles._iconHeight,
                height: _CategoryTiles._iconHeight,
                // With no artwork, draw the icon straight rather than letting
                // RemoteImage lay its tinted placeholder plate behind it —
                // these tiles sit beside line-art PNGs on plain white.
                child: category.imageUrl == null
                    ? Icon(
                        _iconFor(category.name),
                        size: 32,
                        color: AppColors.charcoal,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: RemoteImage(
                          url: category.imageUrl,
                          label: category.name,
                          placeholderIcon: _iconFor(category.name),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              // Flexible so a long name drops to one line rather than
              // overflowing the tile when the text scale is turned up.
              Flexible(
                child: Text(
                  category.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The home page's product grid, backed by its own [ProductListProvider].
///
/// A slice of the catalogue, then one full-width link into the rest of it —
/// rather than several curated strips the backend has no notion of.
class _ProductSection extends StatelessWidget {
  const _ProductSection();

  /// Rows drawn before the "Show all" button. The grid stays whole: the
  /// slice is a multiple of the column count, so the last row is never
  /// half-empty.
  static const int _rows = 4;

  @override
  Widget build(BuildContext context) {
    final list = context.watch<ProductListProvider>();
    final columns = Responsive.gridColumns(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'All products',
          subtitle: 'Everything in the TechZone store, newest first.',
        ),
        if (list.isLoading)
          const LoadingState()
        else if (list.error != null)
          ErrorState(message: list.error!, onRetry: list.refresh)
        else if (list.products.isEmpty)
          const EmptyState(
            title: 'Nothing here yet',
            message: 'No products have been published yet.',
            icon: Icons.inventory_2_outlined,
          )
        else ...[
          ProductGrid(
            products: list.products.take(columns * _rows).toList(),
            columns: columns,
          ),
          const SizedBox(height: 20),
          const _ShowAllButton(),
        ],
      ],
    );
  }
}

/// Full-width link to the catalogue, closing the home page's grid.
class _ShowAllButton extends StatelessWidget {
  const _ShowAllButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: () => context.go('/catalog'),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: const Text('Show all'),
      ),
    );
  }
}
