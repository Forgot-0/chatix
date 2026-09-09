import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/chatix_palette.dart';

class AppTheme {
  static const String fontFamily = 'Manrope';

  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  static ThemeData lightTheme = light(ChatDensity.cosy);
  static ThemeData darkTheme = dark(ChatDensity.cosy);

  static ThemeData light(ChatDensity density) =>
      _build(Brightness.light, density);

  static ThemeData dark(ChatDensity density) =>
      _build(Brightness.dark, density);

  static ThemeData _build(Brightness brightness, ChatDensity density) {
    final isDark = brightness == Brightness.dark;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: ChatixPalette.violet,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? const Color(0xFF9E8CFF) : ChatixPalette.violet,
          secondary: ChatixPalette.mint,
          error: ChatixPalette.coral,
          surface: isDark
              ? ChatixPalette.graphite900
              : ChatixPalette.graphite50,
          onSurface: isDark
              ? ChatixPalette.graphite50
              : ChatixPalette.graphite900,
          surfaceContainerLowest: isDark
              ? ChatixPalette.graphite900
              : Colors.white,
          surfaceContainer: isDark
              ? ChatixPalette.graphite800
              : ChatixPalette.graphite100,
          surfaceContainerHigh: isDark
              ? ChatixPalette.graphite700
              : ChatixPalette.graphite100,
          surfaceContainerHighest: isDark
              ? ChatixPalette.graphite700
              : ChatixPalette.graphite200,
          outline: isDark
              ? ChatixPalette.graphite400
              : ChatixPalette.graphite400,
          outlineVariant: isDark
              ? ChatixPalette.graphite600
              : ChatixPalette.graphite200,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scheme.surface,
    );

    return base.copyWith(
      extensions: [
        isDark ? ChatixTheme.dark(density) : ChatixTheme.light(density),
      ],
      textTheme: base.textTheme.copyWith(
        labelSmall: base.textTheme.labelSmall?.copyWith(
          fontFeatures: tabularFigures,
        ),
        labelMedium: base.textTheme.labelMedium?.copyWith(
          fontFeatures: tabularFigures,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SharedAxisTransitionBuilder(),
          TargetPlatform.iOS: _SharedAxisTransitionBuilder(),
        },
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
    );
  }
}

class _SharedAxisTransitionBuilder extends PageTransitionsBuilder {
  const _SharedAxisTransitionBuilder();

  @override
  Duration get transitionDuration => ChatixTheme.duration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: ChatixTheme.curve,
      reverseCurve: ChatixTheme.curve.flipped,
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
