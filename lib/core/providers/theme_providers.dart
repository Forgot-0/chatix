import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/accessibility/accessibility_providers.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/core/theme/theme_generator.dart';
import 'package:chatix/core/theme/theme_service.dart';

final themeServiceProvider = Provider<ThemeService>((ref) {
  return ThemeService(ref.watch(sharedPreferencesProvider));
});

/// The single source of truth for how the app looks.
///
/// Every setter writes through to storage and updates state at once, so the
/// UI reflects the change on the next frame and survives a restart.
class AppearanceController extends Notifier<AppearanceSettings> {
  @override
  AppearanceSettings build() => ref.watch(themeServiceProvider).load();

  Future<void> setThemeMode(AppThemeMode mode) =>
      _apply(state.copyWith(themeMode: mode));

  Future<void> setAmoled(bool enabled) =>
      _apply(state.copyWith(amoled: enabled));

  Future<void> setDensity(AppDensity density) =>
      _apply(state.copyWith(density: density));

  Future<void> setAccentSeed(Color seed) =>
      _apply(state.copyWith(accentSeed: seed));

  Future<void> setWallpaper(AppWallpaper wallpaper) =>
      _apply(state.copyWith(wallpaperId: wallpaper.id));

  Future<void> setWallpaperIntensity(double value) =>
      _apply(state.copyWith(wallpaperIntensity: value));

  Future<void> setWallpaperPattern(double value) =>
      _apply(state.copyWith(wallpaperPattern: value));

  Future<void> setBubbleRadius(double value) =>
      _apply(state.copyWith(bubbleRadius: value));

  Future<void> setBubbleAnchored(bool anchored) =>
      _apply(state.copyWith(bubbleAnchored: anchored));

  Future<void> setTextScale(double scale) =>
      _apply(state.copyWith(textScale: scale));

  Future<void> reset() => _apply(const AppearanceSettings());

  /// Follows a slider without writing to disk.
  ///
  /// A drag emits a value per frame; persisting each one would mean sixty
  /// encodes and sixty writes a second for a setting that is only finished
  /// when the finger lifts. The app still re-themes on every frame — that is
  /// the point of a slider — and [commit] is what makes the result outlive
  /// the session. Callers pair them: `onChanged` previews, `onChangeEnd`
  /// commits.
  void preview(AppearanceSettings next) {
    if (next != state) state = next;
  }

  void previewWallpaperIntensity(double value) =>
      preview(state.copyWith(wallpaperIntensity: value));

  void previewWallpaperPattern(double value) =>
      preview(state.copyWith(wallpaperPattern: value));

  void previewBubbleRadius(double value) =>
      preview(state.copyWith(bubbleRadius: value));

  /// Writes down whatever the last [preview] left on screen.
  Future<void> commit() => ref.read(themeServiceProvider).save(state);

  Future<void> _apply(AppearanceSettings next) async {
    if (next == state) return;
    state = next;
    await ref.read(themeServiceProvider).save(next);
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceController, AppearanceSettings>(
      AppearanceController.new,
    );

/// The light theme for the current appearance settings.
final lightThemeProvider = Provider<ThemeData>((ref) {
  return ThemeGenerator.build(
    ref.watch(appearanceProvider),
    Brightness.light,
    highContrast: ref.watch(systemHighContrastProvider),
  );
});

/// The dark theme for the current appearance settings.
final darkThemeProvider = Provider<ThemeData>((ref) {
  return ThemeGenerator.build(
    ref.watch(appearanceProvider),
    Brightness.dark,
    highContrast: ref.watch(systemHighContrastProvider),
  );
});

/// Which of the two [MaterialApp] should show.
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(appearanceProvider.select((s) => s.themeMode.material));
});

/// The user's own text scale, applied on top of the platform's.
final textScaleProvider = Provider<double>((ref) {
  return ref.watch(appearanceProvider.select((s) => s.textScale));
});
