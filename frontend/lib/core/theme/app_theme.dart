import 'package:flutter/material.dart';

/// TechZone's visual language: a light storefront on lavender.
///
/// The palette is fixed, not generated:
///
/// * `#E0E5FF` light lavender — the page behind everything
/// * `#FFFFFF` pure white — product cards and every raised surface
/// * `#2563EB` electric blue — discount/savings badges, buttons, active states
/// * `#EA3323` red — the current price a customer pays
/// * `#DCE6FF` soft blue — borders, dividers and quiet fills
/// * `#22C55E` green — in-stock labels and success
/// * `#222222` charcoal — product names and body text
///
/// `ColorScheme.fromSeed` is deliberately not used: it derives containers and
/// surfaces from a seed hue and would drift off these values.
class AppColors {
  const AppColors._();

  // The brand colours, exactly as specified.
  static const Color lavender = Color(0xFFE0E5FF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color electricBlue = Color(0xFF2563EB);
  static const Color priceRed = Color(0xFFEA3323);
  static const Color softBlue = Color(0xFFDCE6FF);
  static const Color green = Color(0xFF22C55E);
  static const Color charcoal = Color(0xFF222222);

  // Tints and shades of those, for the places a brand colour on its own
  // would not clear 4.5:1 or would read too loud.
  static const Color blueDeep = Color(0xFF1D4ED8);
  static const Color blueDarkest = Color(0xFF1E3A8A);
  static const Color lavenderDeep = Color(0xFFCFD7FA);
  static const Color lavenderPale = Color(0xFFEDF0FF);
  static const Color lavenderPalest = Color(0xFFF4F6FF);

  static const Color greenDeep = Color(0xFF15803D);
  static const Color greenDarkest = Color(0xFF14532D);
  static const Color greenTint = Color(0xFFDCFCE7);

  /// Error red. A shade deeper than [priceRed] so a failure message clears
  /// 4.5:1 as small text, and so a price never reads as an error.
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerDarkest = Color(0xFF7F1D1D);
  static const Color dangerTint = Color(0xFFFEE2E2);

  /// Review stars. Outside the palette on purpose: green would read as
  /// "in stock" and blue as a link, and a gold star is what a star means.
  static const Color rating = Color(0xFFFBBF24);

  // Text and line neutrals, blue-tinted so they sit with the lavender.
  static const Color charcoalMuted = Color(0xFF475569);
  static const Color slate = Color(0xFF94A3B8);
}

/// Brand colours that have no `ColorScheme` slot of their own.
///
/// `ColorScheme` covers primary/secondary/error, but the storefront also needs
/// the price red, a green that is safe as *text*, and the hero gradient. They
/// live here so no screen hardcodes a hex value.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.accent,
    required this.price,
    required this.badge,
    required this.onBadge,
    required this.success,
    required this.onSuccess,
    required this.successText,
    required this.imagePlate,
    required this.heroStart,
    required this.heroEnd,
    required this.rating,
  });

  /// Electric blue for links, brand labels and other small accented text.
  final Color accent;

  /// The price a customer pays today.
  final Color price;

  /// Discount and savings badge fill, and its foreground.
  final Color badge;
  final Color onBadge;

  /// Brand green as a fill: in-stock pills and success snackbars.
  final Color success;
  final Color onSuccess;

  /// Brand green at a lightness that is legible as small text.
  final Color successText;

  /// Surface behind product and category photos. White, so a card reads as
  /// one clean rectangle.
  final Color imagePlate;

  /// Hero banner wash: white into lavender, never a dark block.
  final Color heroStart;
  final Color heroEnd;

  /// Review-star gold.
  final Color rating;

  static const AppPalette storefront = AppPalette(
    accent: AppColors.electricBlue,
    price: AppColors.priceRed,
    badge: AppColors.electricBlue,
    onBadge: AppColors.white,
    success: AppColors.green,
    onSuccess: AppColors.charcoal,
    successText: AppColors.greenDeep,
    imagePlate: AppColors.white,
    heroStart: AppColors.white,
    heroEnd: AppColors.lavender,
    rating: AppColors.rating,
  );

  /// The palette for the nearest theme, falling back to [storefront] so a
  /// widget rendered outside [AppTheme] still gets brand colours.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? storefront;

  @override
  AppPalette copyWith({
    Color? accent,
    Color? price,
    Color? badge,
    Color? onBadge,
    Color? success,
    Color? onSuccess,
    Color? successText,
    Color? imagePlate,
    Color? heroStart,
    Color? heroEnd,
    Color? rating,
  }) {
    return AppPalette(
      accent: accent ?? this.accent,
      price: price ?? this.price,
      badge: badge ?? this.badge,
      onBadge: onBadge ?? this.onBadge,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successText: successText ?? this.successText,
      imagePlate: imagePlate ?? this.imagePlate,
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
      rating: rating ?? this.rating,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      accent: Color.lerp(accent, other.accent, t)!,
      price: Color.lerp(price, other.price, t)!,
      badge: Color.lerp(badge, other.badge, t)!,
      onBadge: Color.lerp(onBadge, other.onBadge, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      imagePlate: Color.lerp(imagePlate, other.imagePlate, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      rating: Color.lerp(rating, other.rating, t)!,
    );
  }
}

class AppTheme {
  const AppTheme._();

  /// Corner radius for cards and other raised surfaces. Small, because a
  /// dense grid of tiles reads better with a tight corner.
  static const double radius = 10;

  static const ColorScheme _scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.electricBlue,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.softBlue,
    onPrimaryContainer: AppColors.blueDarkest,
    secondary: AppColors.greenDeep,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.greenTint,
    onSecondaryContainer: AppColors.greenDarkest,
    tertiary: AppColors.blueDeep,
    onTertiary: AppColors.white,
    tertiaryContainer: AppColors.lavenderPale,
    onTertiaryContainer: AppColors.charcoal,
    error: AppColors.danger,
    onError: AppColors.white,
    errorContainer: AppColors.dangerTint,
    onErrorContainer: AppColors.dangerDarkest,
    surface: AppColors.white,
    onSurface: AppColors.charcoal,
    onSurfaceVariant: AppColors.charcoalMuted,
    surfaceContainerLowest: AppColors.white,
    surfaceContainerLow: AppColors.lavenderPalest,
    surfaceContainer: AppColors.lavenderPale,
    surfaceContainerHigh: AppColors.lavender,
    surfaceContainerHighest: AppColors.softBlue,
    outline: AppColors.slate,
    outlineVariant: AppColors.softBlue,
    shadow: AppColors.charcoal,
    scrim: AppColors.charcoal,
    inverseSurface: AppColors.charcoal,
    onInverseSurface: AppColors.white,
    inversePrimary: AppColors.softBlue,
    // Material would otherwise blend `primary` into every raised surface,
    // which is what pulls a generated theme off its own palette.
    surfaceTint: Colors.transparent,
  );

  /// The storefront theme. There is one: the design is light throughout, so
  /// no dark variant is offered.
  static ThemeData light() => _build();

  static ThemeData _build() {
    const scheme = _scheme;
    const palette = AppPalette.storefront;

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Lavender behind everything; white is reserved for cards and chrome.
      scaffoldBackgroundColor: AppColors.lavender,
      canvasColor: AppColors.lavender,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      extensions: const [palette],
      textTheme: base.textTheme.apply(
        fontFamilyFallback: const ['Segoe UI', 'Roboto', 'Arial'],
        bodyColor: AppColors.charcoal,
        displayColor: AppColors.charcoal,
      ),
      // The header band is the one place electric blue is a surface rather
      // than an accent: it anchors the light page under it.
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.electricBlue,
        foregroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: AppColors.softBlue),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
      ),
      // White tile, soft blue hairline, no shadow: the grid stays flat and
      // the lavender gutters do the separating.
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: AppColors.softBlue),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        hintStyle: const TextStyle(color: AppColors.charcoalMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.softBlue),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.softBlue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.electricBlue,
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.electricBlue,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.lavenderDeep,
          disabledForegroundColor: AppColors.charcoalMuted,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.electricBlue,
          backgroundColor: AppColors.white,
          side: const BorderSide(color: AppColors.lavenderDeep),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.electricBlue,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.charcoal),
      ),
      // A selected chip is an active state, so it takes electric blue —
      // green stays reserved for stock.
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.lavenderPale,
        selectedColor: AppColors.softBlue,
        checkmarkColor: AppColors.blueDarkest,
        labelStyle: const TextStyle(
          color: AppColors.charcoal,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        secondaryLabelStyle: const TextStyle(
          color: AppColors.blueDarkest,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        side: const BorderSide(color: AppColors.softBlue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.electricBlue;
          }
          return AppColors.white;
        }),
        checkColor: const WidgetStatePropertyAll(AppColors.white),
        side: const BorderSide(color: AppColors.slate, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.electricBlue;
          }
          return AppColors.slate;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.white;
          return AppColors.charcoalMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.electricBlue;
          }
          return AppColors.lavenderDeep;
        }),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.electricBlue,
        unselectedLabelColor: AppColors.charcoalMuted,
        indicatorColor: AppColors.electricBlue,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.electricBlue,
        linearTrackColor: AppColors.softBlue,
        circularTrackColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.softBlue,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.charcoalMuted,
        textColor: AppColors.charcoal,
        selectedColor: AppColors.electricBlue,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: AppColors.charcoalMuted,
        collapsedIconColor: AppColors.charcoalMuted,
        textColor: AppColors.charcoal,
        collapsedTextColor: AppColors.charcoal,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.charcoal,
        contentTextStyle: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: AppColors.softBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: AppColors.white, fontSize: 12),
      ),
    );
  }
}
