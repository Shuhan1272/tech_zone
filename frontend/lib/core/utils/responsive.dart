import 'package:flutter/widgets.dart';

/// Breakpoints for the storefront layout.
///
/// Flutter Web is the initial target, but the same widgets must work on a
/// phone once Android ships, so every screen is built from these rather than
/// from a desktop-only assumption.
enum ScreenSize { mobile, tablet, desktop, wide }

class Responsive {
  const Responsive._();

  static const double mobileMax = 640;
  static const double tabletMax = 1024;
  static const double desktopMax = 1440;

  /// Maximum content width, so text does not sprawl on an ultrawide monitor.
  static const double maxContentWidth = 1320;

  static ScreenSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static ScreenSize fromWidth(double width) {
    if (width <= mobileMax) return ScreenSize.mobile;
    if (width <= tabletMax) return ScreenSize.tablet;
    if (width <= desktopMax) return ScreenSize.desktop;
    return ScreenSize.wide;
  }

  static bool isMobile(BuildContext context) =>
      of(context) == ScreenSize.mobile;

  static bool isTablet(BuildContext context) =>
      of(context) == ScreenSize.tablet;

  /// True when there is room for a persistent sidebar and a full nav bar.
  static bool isDesktop(BuildContext context) {
    final size = of(context);
    return size == ScreenSize.desktop || size == ScreenSize.wide;
  }

  /// Horizontal page gutter. Mobile keeps a 16px edge as required.
  static double gutter(BuildContext context) {
    switch (of(context)) {
      case ScreenSize.mobile:
        return 16;
      case ScreenSize.tablet:
        return 24;
      case ScreenSize.desktop:
      case ScreenSize.wide:
        return 32;
    }
  }

  /// Product grid columns, chosen per breakpoint.
  ///
  /// Tuned for a dense storefront grid: as many tiles across as fit while
  /// each one still holds a readable two-line title and its price.
  static int gridColumns(BuildContext context, {bool hasSidebar = false}) {
    switch (of(context)) {
      case ScreenSize.mobile:
        return 2;
      case ScreenSize.tablet:
        return hasSidebar ? 3 : 4;
      case ScreenSize.desktop:
        return hasSidebar ? 4 : 5;
      case ScreenSize.wide:
        return hasSidebar ? 5 : 6;
    }
  }

  /// Picks one of three values by breakpoint.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    switch (of(context)) {
      case ScreenSize.mobile:
        return mobile;
      case ScreenSize.tablet:
        return tablet ?? mobile;
      case ScreenSize.desktop:
      case ScreenSize.wide:
        return desktop ?? tablet ?? mobile;
    }
  }
}

/// Centres page content and applies the breakpoint gutter.
class PageContainer extends StatelessWidget {
  const PageContainer({
    super.key,
    required this.child,
    this.maxWidth = Responsive.maxContentWidth,
    this.vertical = 24,
  });

  final Widget child;
  final double maxWidth;
  final double vertical;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.gutter(context),
            vertical: vertical,
          ),
          child: child,
        ),
      ),
    );
  }
}
