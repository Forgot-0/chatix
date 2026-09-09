import 'package:flutter/material.dart';

import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/core/theme/theme_generator.dart';

/// Convenience entry points to the generated themes.
///
/// The app itself reads `lightThemeProvider` / `darkThemeProvider`, which
/// follow the user's appearance settings. These statics are for the places
/// that just need *a* ChatiX theme: tests, goldens and previews.
abstract final class AppTheme {
  static ThemeData light([
    AppearanceSettings settings = const AppearanceSettings(),
  ]) => ThemeGenerator.build(settings, Brightness.light);

  static ThemeData dark([
    AppearanceSettings settings = const AppearanceSettings(),
  ]) => ThemeGenerator.build(settings, Brightness.dark);

  static final ThemeData lightTheme = light();

  static final ThemeData darkTheme = dark();
}
