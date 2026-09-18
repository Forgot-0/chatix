import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/theme/theme_config.dart';

/// Turns [AppearanceSettings] into [ThemeData].
///
/// This is the only place that knows how tokens map onto Material's slots.
/// It is a pure function of its input, which is what lets the app rebuild the
/// theme on every settings change without a restart.
abstract final class ThemeGenerator {
  /// Builds the theme for [brightness] under [settings].
  ///
  /// [highContrast] comes from the platform, not from [settings]: it is the
  /// system's accessibility switch, and the app's job is to answer it, not to
  /// offer a second copy of it in its own preferences.
  static ThemeData build(
    AppearanceSettings settings,
    Brightness brightness, {
    bool highContrast = false,
  }) {
    final amoled = settings.amoled && brightness == Brightness.dark;
    final scheme = schemeFor(
      settings.accentSeed,
      brightness,
      amoled: amoled,
      highContrast: highContrast,
    );
    final density = settings.density;
    final isDark = brightness == Brightness.dark;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.fontFamily,
      visualDensity: density.visualDensity,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        ChatixTheme.fromScheme(
          scheme: scheme,
          density: density,
          accent: settings.accentSeed,
          bubbleRadius: settings.bubbleRadius,
          bubbleAnchorRadius: settings.bubbleAnchorRadius,
          wallpaperStyle: settings.wallpaper,
          wallpaperIntensity: settings.wallpaperIntensity,
          wallpaperPattern: settings.wallpaperPattern,
          amoled: amoled,
          highContrast: highContrast,
        ),
      ],
      textTheme: _textTheme(base.textTheme),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _SharedAxisTransitionBuilder(),
          TargetPlatform.iOS: _SharedAxisTransitionBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          fontFamily: AppTypography.fontFamily,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x5,
            vertical: AppSpacing.x3 + 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg - 2),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x5,
            vertical: AppSpacing.x3 + 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg - 2),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x5,
            vertical: AppSpacing.x3 + 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg - 2),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        border: _inputBorder(),
        enabledBorder: _inputBorder(),
        focusedBorder: _inputBorder(color: scheme.primary, width: 1.5),
        errorBorder: _inputBorder(color: scheme.error),
        focusedErrorBorder: _inputBorder(color: scheme.error, width: 1.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x3 + 2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppElevations.surfaceOf(
          brightness,
          scheme.surfaceContainer,
          isDark ? 1 : 0,
        ),
        shadowColor: isDark ? Colors.transparent : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: density.listRowPadding,
        ),
        minVerticalPadding: density.listRowPadding,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg - 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xxl - 4),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        thickness: 1,
        space: 1,
        color: scheme.outlineVariant,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        elevation: 0,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppNeutrals.step(brightness, isDark ? 8 : 10),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
    );
  }

  /// The [ColorScheme] for [seed]. Material's tonal palette shifts a seed
  /// noticeably, so the brand accent is put back on `primary` verbatim in
  /// light and lifted just enough to stay legible in dark; the surfaces come
  /// from the warm graphite ramp rather than Material's cool default.
  static ColorScheme schemeFor(
    Color seed,
    Brightness brightness, {
    bool amoled = false,
    bool highContrast = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? _liftForDark(seed) : seed;
    final black = amoled && isDark;

    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: _foregroundOn(primary),
      secondary: AppPalette.mint,
      onSecondary: _foregroundOn(AppPalette.mint),
      tertiary: AppPalette.amber,
      onTertiary: _foregroundOn(AppPalette.amber),
      error: AppPalette.coral,
      onError: _foregroundOn(AppPalette.coral),
      surface: black ? AppAmoled.canvas : AppNeutrals.canvas(brightness),
      onSurface: highContrast
          ? (isDark ? Colors.white : Colors.black)
          : AppNeutrals.text(brightness),
      onSurfaceVariant: highContrast
          ? AppNeutrals.step(brightness, isDark ? 1 : 9)
          : AppNeutrals.textMuted(brightness),
      surfaceContainerLowest: black
          ? AppAmoled.canvas
          : AppNeutrals.step(brightness, isDark ? 11 : 0),
      surfaceContainerLow: black
          ? AppAmoled.step(0)
          : AppNeutrals.step(brightness, isDark ? 10 : 1),
      surfaceContainer: black
          ? AppAmoled.step(1)
          : AppNeutrals.step(brightness, isDark ? 9 : 2),
      surfaceContainerHigh: black
          ? AppAmoled.step(2)
          : AppNeutrals.step(brightness, isDark ? 8 : 3),
      surfaceContainerHighest: black
          ? AppAmoled.step(3)
          : AppNeutrals.step(brightness, isDark ? 7 : 4),
      outline: highContrast
          ? AppNeutrals.step(brightness, isDark ? 2 : 8)
          : AppNeutrals.outline(brightness),
      outlineVariant: highContrast
          ? AppNeutrals.step(brightness, isDark ? 4 : 6)
          : (black ? AppAmoled.border : AppNeutrals.border(brightness)),
    );
  }

  /// Digits that do not shuffle: every style that carries a clock, a counter
  /// or a duration asks for tabular figures.
  static TextTheme _textTheme(TextTheme base) => base.copyWith(
    labelSmall: base.labelSmall?.copyWith(
      fontFeatures: AppTypography.tabularFigures,
    ),
    labelMedium: base.labelMedium?.copyWith(
      fontFeatures: AppTypography.tabularFigures,
    ),
    labelLarge: base.labelLarge?.copyWith(
      fontFeatures: AppTypography.tabularFigures,
    ),
  );

  static OutlineInputBorder _inputBorder({Color? color, double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg - 2),
        borderSide: color == null
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );

  /// Pulls an accent up to a lightness that stays readable on a dark ground.
  static Color _liftForDark(Color seed) {
    final hsl = HSLColor.fromColor(seed);
    return hsl
        .withLightness(hsl.lightness < 0.7 ? 0.7 : hsl.lightness)
        .withSaturation(hsl.saturation > 0.9 ? 0.9 : hsl.saturation)
        .toColor();
  }

  static Color _foregroundOn(Color background) =>
      AppContrast.foregroundOn(background);
}

/// Screens arrive with a short rise and a fade — the same curve and duration
/// as everything else in the system, so navigation feels like the rest of it.
class _SharedAxisTransitionBuilder extends PageTransitionsBuilder {
  const _SharedAxisTransitionBuilder();

  @override
  Duration get transitionDuration => AppMotion.base;

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Reduced motion gets the page, not a gentler version of the animation:
    // a smaller movement is still a movement.
    if (context != null &&
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      return child;
    }

    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.curve,
      reverseCurve: AppMotion.reverseCurve,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
