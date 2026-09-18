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

/// A procedural chat background. Stored by [id] rather than by index so the
/// gallery can be reordered or extended without invalidating what people
/// already picked.
///
/// Nothing here is an asset. Every style is a recipe the painter follows,
/// coloured entirely from the user's accent — which is what lets the whole
/// gallery re-tint the moment the accent changes, at no download and no
/// bundle size. The recipes live in `core/ui/wallpaper`.
enum AppWallpaper {
  /// Flat surface, no pattern.
  plain('plain'),

  /// A handful of wide, soft colour blooms.
  mesh('mesh'),

  /// Blooms plus a faint diagonal lattice.
  aurora('aurora'),

  /// Many smaller blooms, hue-shifted around the accent.
  nebula('nebula'),

  /// Sweeping horizontal bands.
  ribbons('ribbons'),

  /// Angular facets struck from one corner.
  prism('prism'),

  /// Concentric rings around an off-canvas centre.
  halo('halo'),

  /// Stacked arcs rising from the bottom edge.
  dunes('dunes');

  const AppWallpaper(this.id);

  final String id;

  /// Whether the style paints radial colour at all.
  bool get hasBlooms => this != AppWallpaper.plain;

  /// Whether the style overlays the diagonal hairlines.
  bool get hasLattice => this == AppWallpaper.aurora;

  /// The styles offered in the gallery, quietest first.
  static const List<AppWallpaper> gallery = AppWallpaper.values;

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
    this.amoled = false,
    this.density = AppDensity.cozy,
    this.accentSeed = AppPalette.violet,
    this.wallpaperId = 'aurora',
    this.wallpaperIntensity = defaultWallpaperIntensity,
    this.wallpaperPattern = defaultWallpaperPattern,
    this.bubbleRadius = defaultBubbleRadius,
    this.bubbleAnchored = true,
    this.textScale = 1,
  });

  /// Rebuilds settings from storage.
  ///
  /// Every field is read by shape rather than cast, and anything unreadable
  /// falls back to its default: these values come off disk, where a build
  /// from six months ago or a half-written file can leave anything at all,
  /// and a corrupt preference must never be the reason the app will not
  /// start.
  factory AppearanceSettings.fromJson(Map<String, Object?> json) {
    final seed = json['accentSeed'];

    return AppearanceSettings(
      themeMode: AppThemeMode.fromName(_string(json['themeMode'])),
      amoled: json['amoled'] == true,
      density: AppDensity.fromName(_string(json['density'])),
      accentSeed: seed is int ? Color(seed) : AppPalette.violet,
      wallpaperId: AppWallpaper.fromId(_string(json['wallpaperId'])).id,
      wallpaperIntensity: clampUnit(
        _number(json['wallpaperIntensity']) ?? defaultWallpaperIntensity,
      ),
      wallpaperPattern: clampUnit(
        _number(json['wallpaperPattern']) ?? defaultWallpaperPattern,
      ),
      bubbleRadius: clampBubbleRadius(
        _number(json['bubbleRadius']) ?? defaultBubbleRadius,
      ),
      bubbleAnchored: json['bubbleAnchored'] != false,
      textScale: clampTextScale(_number(json['textScale']) ?? defaultTextScale),
    );
  }

  static String? _string(Object? value) => value is String ? value : null;

  static double? _number(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : null;

  static const double minTextScale = 0.85;
  static const double maxTextScale = 1.3;
  static const double defaultTextScale = 1;

  /// The steps offered in settings; the slider is discrete so the value stays
  /// something a designer can reason about.
  static const List<double> textScaleSteps = <double>[0.85, 1, 1.15, 1.3];

  /// The band the bubble-corner slider runs over.
  ///
  /// Below 12 the fill stops reading as a bubble at all; above 24 a short
  /// message turns into a lozenge and the anchor corner has nothing left to
  /// point with. Both ends were picked against the smallest bubble the
  /// composer can produce — a single emoji.
  static const double minBubbleRadius = 12;
  static const double maxBubbleRadius = 24;
  static const double defaultBubbleRadius = 20;

  /// The corner a bubble is anchored on, when the anchor is switched on.
  static const double anchorRadius = 6;

  static const double defaultWallpaperIntensity = 0.5;
  static const double defaultWallpaperPattern = 0.5;

  static double clampTextScale(double value) =>
      value.clamp(minTextScale, maxTextScale).toDouble();

  static double clampBubbleRadius(double value) =>
      value.clamp(minBubbleRadius, maxBubbleRadius).toDouble();

  /// Both wallpaper sliders run 0..1; anything else is a corrupt preference.
  static double clampUnit(double value) => value.clamp(0.0, 1.0).toDouble();

  final AppThemeMode themeMode;

  /// Whether the dark theme goes all the way to black.
  ///
  /// Separate from [themeMode] rather than a fourth mode, because it is not a
  /// mode: it says what "dark" means, and someone following the system still
  /// wants their nights black. It only does anything on a dark ground.
  final bool amoled;

  final AppDensity density;
  final Color accentSeed;
  final String wallpaperId;

  /// How loudly the wallpaper pattern is painted, 0 (barely there) to 1.
  final double wallpaperIntensity;

  /// Which arrangement of the chosen style is drawn, 0 to 1.
  ///
  /// A continuous knob rather than a set of presets: each style reads it as
  /// its own thing — how many blooms, how tight the bands, how far the rings
  /// are apart — so one slider re-rolls the pattern without ever producing a
  /// layout that was not designed for.
  final double wallpaperPattern;

  /// The radius of a message bubble's free corners.
  final double bubbleRadius;

  /// Whether the corner on the author's side is pulled tight into an anchor.
  final bool bubbleAnchored;

  final double textScale;

  AppWallpaper get wallpaper => AppWallpaper.fromId(wallpaperId);

  /// The radius of the anchor corner: tight when the anchor is on, the same
  /// as every other corner when it is off.
  double get bubbleAnchorRadius => bubbleAnchored ? anchorRadius : bubbleRadius;

  AppearanceSettings copyWith({
    AppThemeMode? themeMode,
    bool? amoled,
    AppDensity? density,
    Color? accentSeed,
    String? wallpaperId,
    double? wallpaperIntensity,
    double? wallpaperPattern,
    double? bubbleRadius,
    bool? bubbleAnchored,
    double? textScale,
  }) {
    return AppearanceSettings(
      themeMode: themeMode ?? this.themeMode,
      amoled: amoled ?? this.amoled,
      density: density ?? this.density,
      accentSeed: accentSeed ?? this.accentSeed,
      wallpaperId: wallpaperId ?? this.wallpaperId,
      wallpaperIntensity: wallpaperIntensity == null
          ? this.wallpaperIntensity
          : clampUnit(wallpaperIntensity),
      wallpaperPattern: wallpaperPattern == null
          ? this.wallpaperPattern
          : clampUnit(wallpaperPattern),
      bubbleRadius: bubbleRadius == null
          ? this.bubbleRadius
          : clampBubbleRadius(bubbleRadius),
      bubbleAnchored: bubbleAnchored ?? this.bubbleAnchored,
      textScale: textScale == null ? this.textScale : clampTextScale(textScale),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'themeMode': themeMode.name,
    'amoled': amoled,
    'density': density.name,
    'accentSeed': accentSeed.toARGB32(),
    'wallpaperId': wallpaperId,
    'wallpaperIntensity': wallpaperIntensity,
    'wallpaperPattern': wallpaperPattern,
    'bubbleRadius': bubbleRadius,
    'bubbleAnchored': bubbleAnchored,
    'textScale': textScale,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppearanceSettings &&
          other.themeMode == themeMode &&
          other.amoled == amoled &&
          other.density == density &&
          other.accentSeed == accentSeed &&
          other.wallpaperId == wallpaperId &&
          other.wallpaperIntensity == wallpaperIntensity &&
          other.wallpaperPattern == wallpaperPattern &&
          other.bubbleRadius == bubbleRadius &&
          other.bubbleAnchored == bubbleAnchored &&
          other.textScale == textScale;

  @override
  int get hashCode => Object.hash(
    themeMode,
    amoled,
    density,
    accentSeed,
    wallpaperId,
    wallpaperIntensity,
    wallpaperPattern,
    bubbleRadius,
    bubbleAnchored,
    textScale,
  );

  @override
  String toString() =>
      'AppearanceSettings(themeMode: ${themeMode.name}, amoled: $amoled, '
      'density: ${density.name}, accentSeed: $accentSeed, '
      'wallpaperId: $wallpaperId, wallpaperIntensity: $wallpaperIntensity, '
      'wallpaperPattern: $wallpaperPattern, bubbleRadius: $bubbleRadius, '
      'bubbleAnchored: $bubbleAnchored, textScale: $textScale)';
}
