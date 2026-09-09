import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// How the app picks between the light and dark theme.
///
/// Mirrors [ThemeMode], but is ours to persist: [ThemeMode] is a framework
/// type and we do not want its index order baked into stored preferences.
enum AppThemeMode {
  system,
  light,
  dark;

  ThemeMode get material => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  static AppThemeMode fromName(String? value) => AppThemeMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => AppThemeMode.system,
  );
}

/// How much air the UI gives its rows and message bubbles.
enum AppDensity {
  compact,
  cozy,
  comfortable;

  /// Vertical padding inside a message bubble.
  double get bubblePaddingY => switch (this) {
    AppDensity.compact => 6,
    AppDensity.cozy => 9,
    AppDensity.comfortable => 13,
  };

  /// Horizontal padding inside a message bubble.
  double get bubblePaddingX => switch (this) {
    AppDensity.compact => 10,
    AppDensity.cozy => 12,
    AppDensity.comfortable => 14,
  };

  /// Gap between two runs of messages by different authors.
  double get groupGap => switch (this) {
    AppDensity.compact => 6,
    AppDensity.cozy => 10,
    AppDensity.comfortable => 16,
  };

  /// Gap between consecutive messages from the same author. Always tighter
  /// than [groupGap] — that difference is what makes a run read as a run.
  double get stackGap => switch (this) {
    AppDensity.compact => 1,
    AppDensity.cozy => 2,
    AppDensity.comfortable => 4,
  };

  /// Extra vertical padding for list rows (chats, members, settings).
  double get listRowPadding => switch (this) {
    AppDensity.compact => 2,
    AppDensity.cozy => 6,
    AppDensity.comfortable => 10,
  };

  /// Fed to [ThemeData.visualDensity], which is what moves the framework's
  /// own components (buttons, list tiles, checkboxes).
  VisualDensity get visualDensity => switch (this) {
    AppDensity.compact => VisualDensity.compact,
    AppDensity.cozy => VisualDensity.standard,
    AppDensity.comfortable => const VisualDensity(vertical: 1),
  };

  static AppDensity fromName(String? value) => switch (value) {
    // Values written by the pre-tokens build, kept readable across upgrades.
    'cosy' => AppDensity.cozy,
    'spacious' => AppDensity.comfortable,
    _ => AppDensity.values.firstWhere(
      (density) => density.name == value,
      orElse: () => AppDensity.cozy,
    ),
  };
}

/// The chat background. Stored by [id] rather than by index so the set can be
/// reordered or extended without invalidating what people already picked.
enum AppWallpaper {
  /// Colour blooms plus a faint diagonal lattice.
  aurora('aurora'),

  /// Colour blooms only.
  mesh('mesh'),

  /// Flat surface, no pattern.
  plain('plain');

  const AppWallpaper(this.id);

  final String id;

  bool get hasBlooms => this != AppWallpaper.plain;

  bool get hasLattice => this == AppWallpaper.aurora;

  static const AppWallpaper fallback = AppWallpaper.aurora;

  static AppWallpaper fromId(String? value) => AppWallpaper.values.firstWhere(
    (wallpaper) => wallpaper.id == value,
    orElse: () => fallback,
  );
}

/// Everything the user can change about how ChatiX looks.
///
/// Persisted as a whole by `ThemeService`; the generated [ThemeData] is a pure
/// function of this object, which is what makes appearance changes apply
/// without a restart.
@immutable
class AppearanceSettings {
  const AppearanceSettings({
    this.themeMode = AppThemeMode.system,
    this.density = AppDensity.cozy,
    this.accentSeed = AppPalette.violet,
    this.wallpaperId = 'aurora',
    this.textScale = 1,
  });

  factory AppearanceSettings.fromJson(Map<String, Object?> json) {
    final seed = json['accentSeed'];
    return AppearanceSettings(
      themeMode: AppThemeMode.fromName(json['themeMode'] as String?),
      density: AppDensity.fromName(json['density'] as String?),
      accentSeed: seed is int ? Color(seed) : AppPalette.violet,
      wallpaperId: AppWallpaper.fromId(json['wallpaperId'] as String?).id,
      textScale: clampTextScale(
        (json['textScale'] as num?)?.toDouble() ?? defaultTextScale,
      ),
    );
  }

  static const double minTextScale = 0.85;
  static const double maxTextScale = 1.3;
  static const double defaultTextScale = 1;

  /// The steps offered in settings; the slider is discrete so the value stays
  /// something a designer can reason about.
  static const List<double> textScaleSteps = <double>[0.85, 1, 1.15, 1.3];

  static double clampTextScale(double value) =>
      value.clamp(minTextScale, maxTextScale).toDouble();

  final AppThemeMode themeMode;
  final AppDensity density;
  final Color accentSeed;
  final String wallpaperId;
  final double textScale;

  AppWallpaper get wallpaper => AppWallpaper.fromId(wallpaperId);

  AppearanceSettings copyWith({
    AppThemeMode? themeMode,
    AppDensity? density,
    Color? accentSeed,
    String? wallpaperId,
    double? textScale,
  }) {
    return AppearanceSettings(
      themeMode: themeMode ?? this.themeMode,
      density: density ?? this.density,
      accentSeed: accentSeed ?? this.accentSeed,
      wallpaperId: wallpaperId ?? this.wallpaperId,
      textScale: textScale == null ? this.textScale : clampTextScale(textScale),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'themeMode': themeMode.name,
    'density': density.name,
    'accentSeed': accentSeed.toARGB32(),
    'wallpaperId': wallpaperId,
    'textScale': textScale,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppearanceSettings &&
          other.themeMode == themeMode &&
          other.density == density &&
          other.accentSeed == accentSeed &&
          other.wallpaperId == wallpaperId &&
          other.textScale == textScale;

  @override
  int get hashCode =>
      Object.hash(themeMode, density, accentSeed, wallpaperId, textScale);

  @override
  String toString() =>
      'AppearanceSettings(themeMode: ${themeMode.name}, '
      'density: ${density.name}, accentSeed: $accentSeed, '
      'wallpaperId: $wallpaperId, textScale: $textScale)';
}
