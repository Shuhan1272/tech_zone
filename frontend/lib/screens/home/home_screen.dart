import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../models/catalog.dart';
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Straight under the navigation, edge to edge. The supplied
          // artwork is used where there is room for the text baked into it;
          // narrower windows get the same banner built from widgets, which
          // reflows and stays readable.
          if (Responsive.isDesktop(context))
            const _HeroImageBand()
          else ...[
            const _HeroBand(),
            const _FeatureBand(),
          ],

          if (catalog.notices.isNotEmpty)
            PageContainer(
              vertical: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final notice in catalog.notices.take(2))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _NoticeBanner(notice: notice),
                    ),
                ],
              ),
            ),

          PageContainer(
            vertical: 36,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
        ],
      ),
    );
  }
}

/// Shape, colour and motion values shared across the banner.
class _HeroStyle {
  const _HeroStyle._();

  /// Ice blues behind the banner and the strip under it. Lighter than the
  /// page's lavender, which is what gives the banner its lift.
  static const Color wash = Color(0xFFF2F7FF);
  static const Color washDeep = Color(0xFFDCE9FF);
  static const Color band = Color(0xFFF5F7FC);
  static const Color chip = Color(0xFFE8EFFF);
  static const Color hairline = Color(0xFFE6ECF8);

  /// Feature-card icon tints, from the reference design.
  static const Color mintChip = Color(0xFFE8F7EF);
  static const Color mint = Color(0xFF22A45D);
  static const Color violetChip = Color(0xFFEFEBFB);
  static const Color violet = Color(0xFF7C6AE8);

  static const double cardRadius = 16;
  static const Duration hover = Duration(milliseconds: 180);

  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x0F1B3A6B), blurRadius: 18, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> lifted = [
    BoxShadow(color: Color(0x221B3A6B), blurRadius: 28, offset: Offset(0, 12)),
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

/// The banner as supplied artwork: `assets/images/hero-devices.png` drawn
/// edge to edge under the navigation.
///
/// The picture carries its own copy, buttons and feature cards as pixels, so
/// the only thing left for Flutter is to make them work: each one gets a
/// transparent hotspot over it, carrying the tap target, the hover cursor and
/// a semantics label, since a screen reader cannot read a bitmap.
///
/// Used on desktop only. The artwork is 2.34:1 with text sized for a 1920
/// frame; on a narrow window that text would render a few pixels tall, so
/// below the desktop breakpoint the live widget banner is shown instead.
class _HeroImageBand extends StatelessWidget {
  const _HeroImageBand();

  /// The artwork's own proportions, so it is never stretched.
  static const double _aspect = 1920 / 819;

  // Measured off the artwork in pixels and stored as fractions of its frame,
  // which keeps them correct at whatever width it ends up drawn.
  static const _hotspots = <({Rect area, String label, String route})>[
    (
      area: Rect.fromLTRB(0.0552, 0.5543, 0.2161, 0.6313),
      label: 'Shop all products',
      route: '/catalog',
    ),
    (
      area: Rect.fromLTRB(0.2318, 0.5519, 0.3406, 0.6288),
      label: 'See featured',
      route: '/catalog?featured=true',
    ),
    (
      area: Rect.fromLTRB(0.0453, 0.8059, 0.3380, 0.9499),
      label: 'Live stock — straight from the warehouse',
      route: '/catalog',
    ),
    (
      area: Rect.fromLTRB(0.3547, 0.8059, 0.6464, 0.9499),
      label: 'Per-variant pricing — discounts applied for you',
      route: '/catalog?featured=true',
    ),
    (
      area: Rect.fromLTRB(0.6641, 0.8059, 0.9552, 0.9499),
      label: 'Deep filters — brand, category, specification',
      route: '/catalog',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // The artwork is transparent in places, so the wash behind it is what
      // shows through rather than bare white.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, _HeroStyle.wash, _HeroStyle.washDeep],
          stops: [0, 0.45, 1],
        ),
      ),
      child: AspectRatio(
        aspectRatio: _aspect,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/hero-devices.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                // If the artwork is ever removed, fall back to the banner
                // built out of widgets rather than leaving a hole.
                errorBuilder: (context, error, stack) => const _HeroBand(),
              ),
            ),
            for (final spot in _hotspots)
              _Hotspot(
                area: spot.area,
                label: spot.label,
                onTap: () => context.go(spot.route),
              ),
          ],
        ),
      ),
    );
  }
}

/// A transparent, clickable patch over a region of the artwork.
class _Hotspot extends StatelessWidget {
  const _Hotspot({
    required this.area,
    required this.label,
    required this.onTap,
  });

  /// Where the patch sits, as fractions of the artwork frame.
  final Rect area;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Align places a fractionally sized child by its centre, so the left edge
    // of a child of width w at alignment x is ((1 + x) / 2) * (1 - w).
    // Inverted here to put the patch exactly where it was measured.
    double offset(double start, double extent) =>
        extent >= 1 ? 0 : (2 * start) / (1 - extent) - 1;

    return Align(
      alignment: Alignment(
        offset(area.left, area.width),
        offset(area.top, area.height),
      ),
      child: FractionallySizedBox(
        widthFactor: area.width,
        heightFactor: area.height,
        child: Semantics(
          button: true,
          label: label,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

/// The landing banner, edge to edge, with its content on the page grid.
///
/// Full-bleed because the reference design runs the wash to the window edges
/// while the copy stays on the same column as the rest of the page.
class _HeroBand extends StatelessWidget {
  const _HeroBand();

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final gutter = Responsive.gutter(context);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, _HeroStyle.wash, _HeroStyle.washDeep],
          stops: [0, 0.45, 1],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: Responsive.maxContentWidth,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              isDesktop ? 40 : 28,
              gutter,
              isDesktop ? 40 : 32,
            ),
            child: isDesktop
                ? const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 5, child: _HeroCopy()),
                      SizedBox(width: 28),
                      Expanded(flex: 7, child: _HeroArt()),
                    ],
                  )
                : const Column(
                    children: [
                      _HeroCopy(centred: true),
                      SizedBox(height: 26),
                      _HeroArt(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Left column: eyebrow, headline, description, the two calls to action and
/// the three trust lines under them.
class _HeroCopy extends StatelessWidget {
  const _HeroCopy({this.centred = false});

  /// Stacked layouts read better centred; the two-column one does not.
  final bool centred;

  static const _trust = <(IconData, String, String)>[
    (Icons.local_shipping_outlined, 'Fast & reliable', 'delivery'),
    (Icons.verified_user_outlined, '100% authentic', 'products'),
    (Icons.headset_mic_outlined, 'Dedicated', 'customer support'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = Responsive.of(context);
    final align = centred ? TextAlign.center : TextAlign.start;

    final headlineSize = switch (size) {
      ScreenSize.mobile => 34.0,
      ScreenSize.tablet => 46.0,
      ScreenSize.desktop => 52.0,
      ScreenSize.wide => 58.0,
    };

    return Column(
      crossAxisAlignment: centred
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        const _HeroEyebrow(),
        const SizedBox(height: 22),
        // Two lines, the second in electric blue, exactly as referenced.
        Text.rich(
          TextSpan(
            children: const [
              TextSpan(text: 'Upgrade Your\n'),
              TextSpan(
                text: 'Everyday Tech',
                style: TextStyle(color: AppColors.electricBlue),
              ),
            ],
            style: TextStyle(
              color: AppColors.charcoal,
              fontSize: headlineSize,
              fontWeight: FontWeight.w800,
              height: 1.08,
              letterSpacing: -1.4,
            ),
          ),
          textAlign: align,
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'Laptops, desktops, home appliances and everyday gadgets — '
            'with live stock, real prices and the latest technology.',
            textAlign: align,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
              fontSize: 16.5,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          alignment: centred ? WrapAlignment.center : WrapAlignment.start,
          children: [
            FilledButton.icon(
              onPressed: () => context.go('/catalog'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 54),
                padding: const EdgeInsets.symmetric(horizontal: 26),
                textStyle: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.storefront_rounded, size: 19),
              // Flexible label: the button already sits inside the button's
              // own Flexible, so on a narrow phone the text has to be able
              // to give way rather than push the arrow off the edge.
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Shop all products',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, size: 17),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/catalog?featured=true'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 54),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                backgroundColor: AppColors.white,
                side: const BorderSide(
                  color: AppColors.electricBlue,
                  width: 1.4,
                ),
                textStyle: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.star_outline_rounded, size: 19),
              label: const Text('See featured'),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 26,
          runSpacing: 14,
          alignment: centred ? WrapAlignment.center : WrapAlignment.start,
          children: [
            for (final (icon, title, detail) in _trust)
              _TrustPoint(icon: icon, title: title, detail: detail),
          ],
        ),
      ],
    );
  }
}

/// One of the three short reassurances under the buttons.
class _TrustPoint extends StatelessWidget {
  const _TrustPoint({
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _HeroStyle.hairline),
            boxShadow: _HeroStyle.soft,
          ),
          child: Icon(icon, size: 18, color: AppColors.electricBlue),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.charcoal,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Right column: the device artwork on its platform, over the decorative
/// washes.
class _HeroArt extends StatelessWidget {
  const _HeroArt();

  @override
  Widget build(BuildContext context) {
    return const AspectRatio(
      aspectRatio: 1.75,
      child: Stack(
        children: [
          // Decorative washes, the soft blue shapes behind the devices.
          Align(
            alignment: Alignment(0.55, -0.35),
            child: FractionallySizedBox(
              widthFactor: 0.78,
              heightFactor: 0.95,
              child: _Blob(Color(0x33BBD4FF)),
            ),
          ),
          Align(
            alignment: Alignment(-0.35, 0.25),
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 0.6,
              child: _Blob(Color(0x2A9FC3FF)),
            ),
          ),

          // The platform the devices stand on.
          Align(
            alignment: Alignment(0.05, 0.86),
            child: FractionallySizedBox(
              widthFactor: 0.72,
              heightFactor: 0.2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFFDCE8FF), Color(0x00DCE8FF)],
                  ),
                ),
              ),
            ),
          ),

          Positioned.fill(child: _HeroDevices()),
        ],
      ),
    );
  }
}

/// A soft circular wash used behind the hero artwork.
class _Blob extends StatelessWidget {
  const _Blob(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

/// The device composite in the banner, drawn rather than photographed.
///
/// A laptop in the centre, over-ear headphones to its left, a phone to its
/// right, a smartwatch and an earbud case in front. Everything is vector, so
/// it is sharp at any size and on any display, costs no download, and can
/// never point at a URL that breaks.
///
/// If `assets/images/hero-devices.png` is ever supplied it takes over; this
/// is what the banner shows otherwise.
/// Drawn, not photographed: the artwork in `assets/images/hero-devices.png`
/// is the whole banner, copy and buttons included, so it belongs to
/// [_HeroImageBand]. Dropping it into this column instead would squeeze a
/// second set of headlines and cards into a corner of the first.
class _HeroDevices extends StatelessWidget {
  const _HeroDevices();

  /// Each device gets a slot in the frame: where its centre sits, and how
  /// much of the frame it takes. Laid out with Align and fractions so the
  /// composition holds together at every width.
  static const _pieces =
      <({Alignment at, double width, double height, CustomPainter painter})>[
        (
          at: Alignment(-0.74, 0.30),
          width: 0.33,
          height: 0.62,
          painter: _HeadphonesPainter(),
        ),
        (
          at: Alignment(0.10, -0.06),
          width: 0.60,
          height: 0.78,
          painter: _LaptopPainter(),
        ),
        (
          at: Alignment(0.88, 0.20),
          width: 0.17,
          height: 0.70,
          painter: _PhonePainter(),
        ),
        (
          at: Alignment(-0.26, 0.86),
          width: 0.13,
          height: 0.40,
          painter: _WatchPainter(),
        ),
        (
          at: Alignment(0.26, 0.92),
          width: 0.15,
          height: 0.24,
          painter: _EarbudsPainter(),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final piece in _pieces)
          Align(
            alignment: piece.at,
            child: FractionallySizedBox(
              widthFactor: piece.width,
              heightFactor: piece.height,
              child: CustomPaint(
                painter: piece.painter,
                child: const SizedBox.expand(),
              ),
            ),
          ),
      ],
    );
  }
}

/// Palette for the drawn devices. Dark bodies on a bright banner, the way
/// product photography of black hardware reads.
class _Device {
  const _Device._();

  static const Color shell = Color(0xFF2B3140);
  static const Color shellLight = Color(0xFF454D60);
  static const Color metal = Color(0xFFC6D0E2);
  static const Color metalLight = Color(0xFFE8EDF6);
  static const Color screenDeep = Color(0xFF14306E);
  static const Color screenMid = Color(0xFF2563EB);
  static const Color screenLit = Color(0xFF7FB2FF);
  static const Color shadow = Color(0x1A1B3A6B);
}

/// Soft contact shadow under a device.
void _dropShadow(Canvas canvas, Rect area, {double spread = 1}) {
  final oval = Rect.fromCenter(
    center: Offset(area.center.dx, area.bottom),
    width: area.width * 0.9 * spread,
    height: area.height * 0.1,
  );
  canvas.drawOval(
    oval,
    Paint()
      ..color = _Device.shadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
  );
}

Paint _fill(
  Rect rect,
  List<Color> colors, {
  Alignment begin = Alignment.topLeft,
  Alignment end = Alignment.bottomRight,
}) {
  return Paint()
    ..shader = LinearGradient(
      begin: begin,
      end: end,
      colors: colors,
    ).createShader(rect);
}

/// An open laptop, seen head on: lid, screen, and the base in front of it.
class _LaptopPainter extends CustomPainter {
  const _LaptopPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _dropShadow(canvas, Rect.fromLTWH(0, 0, w, h));

    // ---- lid ----------------------------------------------------------
    final lid = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.09, 0, w * 0.82, h * 0.78),
      Radius.circular(w * 0.018),
    );
    canvas.drawRRect(
      lid,
      _fill(lid.outerRect, const [_Device.shellLight, _Device.shell]),
    );

    // ---- screen -------------------------------------------------------
    final screenRect = Rect.fromLTWH(w * 0.105, h * 0.022, w * 0.79, h * 0.70);
    final screen = RRect.fromRectAndRadius(
      screenRect,
      Radius.circular(w * 0.008),
    );
    canvas.drawRRect(
      screen,
      _fill(
        screenRect,
        const [_Device.screenDeep, _Device.screenMid, _Device.screenDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );

    // A pair of crossing ribbons, the way a stock wallpaper looks.
    canvas.save();
    canvas.clipRRect(screen);
    final ribbon = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [_Device.screenLit, Color(0x0040A0FF)],
      ).createShader(screenRect);

    for (final (start, control, end, width)
        in <(Offset, Offset, Offset, double)>[
          (
            Offset(screenRect.left, screenRect.bottom),
            screenRect.center,
            Offset(screenRect.right, screenRect.top),
            h * 0.10,
          ),
          (
            Offset(screenRect.left, screenRect.top + screenRect.height * 0.25),
            Offset(screenRect.center.dx, screenRect.center.dy + h * 0.1),
            Offset(screenRect.right, screenRect.bottom),
            h * 0.055,
          ),
        ]) {
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy),
        ribbon..strokeWidth = width,
      );
    }
    canvas.restore();

    // Camera dot in the top bezel.
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.012),
      w * 0.004,
      Paint()..color = _Device.metal.withValues(alpha: 0.7),
    );

    // ---- base ---------------------------------------------------------
    // Slightly wider than the lid and tapering forward, which is what reads
    // as depth without drawing a full perspective.
    final base = Path()
      ..moveTo(w * 0.07, h * 0.78)
      ..lineTo(w * 0.93, h * 0.78)
      ..lineTo(w, h * 0.90)
      ..quadraticBezierTo(w * 0.5, h * 0.945, 0, h * 0.90)
      ..close();
    canvas.drawPath(
      base,
      _fill(
        Rect.fromLTWH(0, h * 0.78, w, h * 0.17),
        const [_Device.metalLight, _Device.metal],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );

    // The trackpad notch on the front lip.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.905),
          width: w * 0.12,
          height: h * 0.012,
        ),
        Radius.circular(h * 0.01),
      ),
      Paint()..color = _Device.metal.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Over-ear headphones, seen head on.
class _HeadphonesPainter extends CustomPainter {
  const _HeadphonesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _dropShadow(canvas, Rect.fromLTWH(0, 0, w, h), spread: 0.8);

    // ---- headband -----------------------------------------------------
    final bandWidth = w * 0.13;
    final band = Path()
      ..moveTo(bandWidth * 0.5, h * 0.62)
      ..quadraticBezierTo(w * 0.5, -h * 0.14, w - bandWidth * 0.5, h * 0.62);
    canvas.drawPath(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = bandWidth
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_Device.shellLight, _Device.shell],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // ---- ear cups -----------------------------------------------------
    for (final dx in <double>[w * 0.145, w * 0.855]) {
      final cup = Rect.fromCenter(
        center: Offset(dx, h * 0.70),
        width: w * 0.30,
        height: h * 0.46,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(cup, Radius.circular(w * 0.11)),
        _fill(cup, const [_Device.shellLight, _Device.shell]),
      );

      // The pad inside it.
      final pad = Rect.fromCenter(
        center: cup.center,
        width: cup.width * 0.56,
        height: cup.height * 0.64,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(pad, Radius.circular(w * 0.07)),
        Paint()..color = const Color(0xFF171C26),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A smartphone standing on its edge, screen toward the viewer.
class _PhonePainter extends CustomPainter {
  const _PhonePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _dropShadow(canvas, Rect.fromLTWH(0, 0, w, h), spread: 0.7);

    final bodyRect = Rect.fromLTWH(0, 0, w, h);
    final body = RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.17));
    canvas.drawRRect(
      body,
      _fill(bodyRect, const [_Device.metalLight, _Device.metal]),
    );

    final screenRect = bodyRect.deflate(w * 0.055);
    final screen = RRect.fromRectAndRadius(
      screenRect,
      Radius.circular(w * 0.13),
    );
    canvas.drawRRect(
      screen,
      _fill(
        screenRect,
        const [_Device.screenDeep, _Device.screenMid, _Device.screenLit],
        begin: Alignment.topCenter,
        end: Alignment.bottomRight,
      ),
    );

    // Camera island, top left on the back edge the viewer can just see.
    final island = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.045, w * 0.34, h * 0.14),
      Radius.circular(w * 0.1),
    );
    canvas.drawRRect(
      island,
      Paint()..color = _Device.shell.withValues(alpha: 0.55),
    );
    for (var i = 0; i < 2; i++) {
      canvas.drawCircle(
        Offset(w * 0.24 + i * w * 0.15, h * 0.115),
        w * 0.05,
        Paint()..color = const Color(0xFF0E1420),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A smartwatch, face on, straps running out of frame.
class _WatchPainter extends CustomPainter {
  const _WatchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _dropShadow(canvas, Rect.fromLTWH(0, 0, w, h), spread: 0.6);

    // Straps, above and below the case.
    final strap = Paint()..color = _Device.shell;
    for (final rect in <Rect>[
      Rect.fromLTWH(w * 0.22, 0, w * 0.56, h * 0.42),
      Rect.fromLTWH(w * 0.22, h * 0.6, w * 0.56, h * 0.4),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(w * 0.12)),
        strap,
      );
    }

    // Case.
    final caseRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.5),
      width: w,
      height: h * 0.46,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(caseRect, Radius.circular(w * 0.26)),
      _fill(caseRect, const [_Device.shellLight, _Device.shell]),
    );

    // Face.
    final faceRect = caseRect.deflate(w * 0.09);
    canvas.drawRRect(
      RRect.fromRectAndRadius(faceRect, Radius.circular(w * 0.2)),
      _fill(
        faceRect,
        const [_Device.screenMid, _Device.screenDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );

    // Two bars standing in for the time readout.
    final tick = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (final dx in <double>[
      faceRect.left + faceRect.width * 0.26,
      faceRect.left + faceRect.width * 0.58,
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(dx, faceRect.center.dy - h * 0.045, w * 0.16, h * 0.09),
          Radius.circular(w * 0.03),
        ),
        tick,
      );
    }

    // Crown.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.97, h * 0.44, w * 0.08, h * 0.1),
        Radius.circular(w * 0.03),
      ),
      Paint()..color = _Device.metal,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A charging case with one bud resting beside it.
class _EarbudsPainter extends CustomPainter {
  const _EarbudsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _dropShadow(canvas, Rect.fromLTWH(0, 0, w, h), spread: 0.7);

    // Case.
    final caseRect = Rect.fromLTWH(0, h * 0.18, w * 0.66, h * 0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(caseRect, Radius.circular(w * 0.16)),
      _fill(
        caseRect,
        const [Colors.white, _Device.metalLight],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(caseRect, Radius.circular(w * 0.16)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.015
        ..color = _Device.metal,
    );
    // Lid seam.
    canvas.drawLine(
      Offset(caseRect.left + w * 0.06, caseRect.top + h * 0.22),
      Offset(caseRect.right - w * 0.06, caseRect.top + h * 0.22),
      Paint()
        ..strokeWidth = w * 0.012
        ..color = _Device.metal,
    );

    // A single bud, leaning against the case.
    canvas.drawCircle(
      Offset(w * 0.82, h * 0.52),
      w * 0.15,
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.76, h * 0.6, w * 0.11, h * 0.36),
        Radius.circular(w * 0.06),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(w * 0.82, h * 0.52),
      w * 0.15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.014
        ..color = _Device.metal,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small pill above the headline.
class _HeroEyebrow extends StatelessWidget {
  const _HeroEyebrow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 18, 9),
      decoration: BoxDecoration(
        color: _HeroStyle.chip,
        borderRadius: BorderRadius.circular(100),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 17, color: AppColors.electricBlue),
          SizedBox(width: 7),
          // Flexible so the pill narrows with the page instead of pushing
          // past it on a small phone or at a large text scale.
          Flexible(
            child: Text(
              'Live stock · Real prices',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.electricBlue,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The three feature cards, on their own band under the banner.
class _FeatureBand extends StatelessWidget {
  const _FeatureBand();

  static const _features = <(IconData, Color, Color, String, String, String)>[
    (
      Icons.inventory_2_outlined,
      _HeroStyle.mintChip,
      _HeroStyle.mint,
      'Live stock',
      'Straight from the warehouse',
      '/catalog',
    ),
    (
      Icons.local_offer_outlined,
      _HeroStyle.chip,
      AppColors.electricBlue,
      'Per-variant pricing',
      'Discounts applied for you',
      '/catalog?featured=true',
    ),
    (
      Icons.tune_rounded,
      _HeroStyle.violetChip,
      _HeroStyle.violet,
      'Deep filters',
      'Brand, category, specification',
      '/catalog',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final gutter = Responsive.gutter(context);

    final cards = [
      for (final (icon, chip, tint, title, detail, route) in _features)
        _FeatureCard(
          icon: icon,
          chip: chip,
          tint: tint,
          title: title,
          detail: detail,
          route: route,
        ),
    ];

    return Container(
      width: double.infinity,
      color: _HeroStyle.band,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: Responsive.maxContentWidth,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(gutter, 22, gutter, 26),
            child: isMobile
                ? Column(
                    children: [
                      for (final (index, card) in cards.indexed) ...[
                        if (index > 0) const SizedBox(height: 12),
                        card,
                      ],
                    ],
                  )
                // IntrinsicHeight so the three match the tallest of them; a
                // bare stretch would ask for infinite height inside the
                // page's scrolling column.
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, card) in cards.indexed) ...[
                          if (index > 0) const SizedBox(width: 20),
                          Expanded(child: card),
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

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.chip,
    required this.tint,
    required this.title,
    required this.detail,
    required this.route,
  });

  final IconData icon;
  final Color chip;
  final Color tint;
  final String title;
  final String detail;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Hoverable(
      builder: (context, hovered) => AnimatedContainer(
        duration: _HeroStyle.hover,
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, hovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(_HeroStyle.cardRadius),
          border: Border.all(
            color: hovered ? AppColors.electricBlue : _HeroStyle.hairline,
          ),
          boxShadow: hovered ? _HeroStyle.lifted : _HeroStyle.soft,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go(route),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: chip,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 24, color: tint),
                  ),
                  const SizedBox(width: 16),
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
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSlide(
                    duration: _HeroStyle.hover,
                    curve: Curves.easeOut,
                    offset: Offset(hovered ? 0.18 : 0, 0),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: hovered
                          ? AppColors.electricBlue
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
