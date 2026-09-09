/// Raw design tokens for the ChatiX design system.
///
/// Everything here is a primitive: a colour, a number, a duration. Nothing in
/// this file knows about [ThemeData] or about light/dark semantics — that
/// mapping lives in `theme_generator.dart` and `app_theme_extension.dart`.
/// Widgets should read semantic values off the theme rather than reaching for
/// tokens directly; the tokens exist so the theme has a single vocabulary.
library;

import 'package:flutter/material.dart';

/// The brand accents.
abstract final class AppPalette {
  /// Primary accent. Every generated [ColorScheme] seeds from this unless the
  /// user picked another accent in appearance settings.
  static const Color violet = Color(0xFF6E56F8);

  /// Deep end of the outgoing-bubble gradient.
  static const Color indigo = Color(0xFF4B36C9);

  /// Lifted violet, readable as `primary` on dark surfaces.
  static const Color violetSoft = Color(0xFF9E8CFF);

  /// Secondary accent: delivered/read ticks, success, wallpaper bloom.
  static const Color mint = Color(0xFF22C7A9);

  /// Destructive and error states.
  static const Color coral = Color(0xFFF2624F);

  /// Warnings and "needs attention" affordances.
  static const Color amber = Color(0xFFF5A524);

  /// Accents offered in appearance settings, violet first.
  static const List<Color> accentSeeds = <Color>[
    violet,
    mint,
    coral,
    amber,
    Color(0xFF2563C9), // azure
    Color(0xFFB13FA8), // orchid
  ];
}

/// Warm graphite neutrals, twelve steps, lightest to darkest.
///
/// Both ramps are ordered the same way, so an index always means the same
/// *tone*, never the same *role*: a light theme draws its grounds from the low
/// indices and its text from the high ones, a dark theme does the reverse.
/// The named getters below are the roles; use those, not raw indices.
abstract final class AppNeutrals {
  /// Ramp used when painting light surfaces.
  static const List<Color> light = <Color>[
    Color(0xFFFCFAF8), // 0
    Color(0xFFF8F5F1), // 1
    Color(0xFFF1EDE7), // 2
    Color(0xFFE7E2DA), // 3
    Color(0xFFD9D2C9), // 4
    Color(0xFFC4BCB1), // 5
    Color(0xFFA79E92), // 6
    Color(0xFF877E72), // 7
    Color(0xFF6A6156), // 8
    Color(0xFF4B443B), // 9
    Color(0xFF2E2924), // 10
    Color(0xFF14120F), // 11
  ];

  /// Ramp used when painting dark surfaces. Warmer and less contrasty at the
  /// dark end than [light] reversed would be, so large fills stay comfortable.
  static const List<Color> dark = <Color>[
    Color(0xFFF7F4F0), // 0
    Color(0xFFE4DFD8), // 1
    Color(0xFFCBC4BB), // 2
    Color(0xFFABA398), // 3
    Color(0xFF8A8277), // 4
    Color(0xFF6B6359), // 5
    Color(0xFF524B42), // 6
    Color(0xFF3D372F), // 7
    Color(0xFF302B24), // 8
    Color(0xFF241F1A), // 9
    Color(0xFF1B1815), // 10
    Color(0xFF100F0D), // 11
  ];

  /// Number of steps in either ramp.
  static const int steps = 12;

  static List<Color> ramp(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static Color step(Brightness brightness, int index) =>
      ramp(brightness)[index.clamp(0, steps - 1)];

  /// The app background.
  static Color canvas(Brightness brightness) =>
      brightness == Brightness.dark ? dark[10] : light[1];

  /// Cards, sheets, bubbles — anything sitting on [canvas].
  static Color surface(Brightness brightness) =>
      brightness == Brightness.dark ? dark[8] : light[0];

  /// Inputs, chips, quiet fills.
  static Color surfaceMuted(Brightness brightness) =>
      brightness == Brightness.dark ? dark[7] : light[2];

  /// Hairlines and dividers.
  static Color border(Brightness brightness) =>
      brightness == Brightness.dark ? dark[6] : light[3];

  /// Icons and borders that need to be seen.
  static Color outline(Brightness brightness) =>
      brightness == Brightness.dark ? dark[4] : light[6];

  /// Secondary text.
  static Color textMuted(Brightness brightness) =>
      brightness == Brightness.dark ? dark[3] : light[8];

  /// Primary text.
  static Color text(Brightness brightness) =>
      brightness == Brightness.dark ? dark[0] : light[11];
}

/// Corner radii. [full] is a large finite value rather than `double.infinity`
/// so it can be fed to [BorderRadius.circular] and still lerp.
abstract final class AppRadii {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double full = 999;

  static const List<double> scale = <double>[xs, sm, md, lg, xl, xxl, full];
}

/// The 4pt spacing scale.
abstract final class AppSpacing {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x7 = 28;
  static const double x8 = 32;

  static const List<double> scale = <double>[x1, x2, x3, x4, x5, x6, x7, x8];
}

/// Four levels of lift.
///
/// Light themes cast a warm shadow. Dark themes do not: a black shadow on a
/// near-black ground is invisible, so elevation there is expressed by lifting
/// the surface towards white ([surfaceOf]) instead.
abstract final class AppElevations {
  /// Valid levels are 1..4; level 0 means "flat".
  static const int levels = 4;

  static const Color _shadowTint = Color(0xFF14120F);

  static const List<double> _shadowAlpha = <double>[0.05, 0.06, 0.08, 0.10];
  static const List<double> _blur = <double>[2, 8, 16, 32];
  static const List<double> _dy = <double>[1, 2, 6, 12];
  static const List<double> _spread = <double>[0, -1, -2, -4];

  /// How far a raised dark surface travels towards white, per level.
  static const List<double> _tintAlpha = <double>[0.04, 0.07, 0.10, 0.14];

  /// Shadows for [level] (1..4). Always empty in dark, by design.
  static List<BoxShadow> shadows(Brightness brightness, int level) {
    if (brightness == Brightness.dark || level <= 0) return const <BoxShadow>[];
    final i = level.clamp(1, levels) - 1;
    return <BoxShadow>[
      BoxShadow(
        color: _shadowTint.withValues(alpha: _shadowAlpha[i]),
        blurRadius: _blur[i],
        offset: Offset(0, _dy[i]),
        spreadRadius: _spread[i],
      ),
    ];
  }

  /// The colour a surface at [level] should paint itself.
  ///
  /// Light surfaces keep [base] and rely on [shadows]; dark surfaces are
  /// lightened, which is what makes depth readable without a shadow.
  static Color surfaceOf(Brightness brightness, Color base, int level) {
    if (brightness == Brightness.light || level <= 0) return base;
    final i = level.clamp(1, levels) - 1;
    return Color.alphaBlend(
      Colors.white.withValues(alpha: _tintAlpha[i]),
      base,
    );
  }
}

/// Animation timing. One curve for everything so motion feels of a piece.
abstract final class AppMotion {
  /// Taps, ripples, small state flips.
  static const Duration fast = Duration(milliseconds: 120);

  /// The default: bubbles arriving, banners, list reflow.
  static const Duration base = Duration(milliseconds: 220);

  /// Page transitions, sheets, anything travelling a long distance.
  static const Duration slow = Duration(milliseconds: 320);

  static const Curve curve = Curves.easeOutCubic;

  /// For the "leaving" half of a transition.
  static const Curve reverseCurve = Curves.easeInCubic;
}

/// Picks foregrounds by measured contrast rather than by eye.
///
/// A user-chosen accent can land anywhere on the lightness scale, so which of
/// white or graphite reads on it is not something the palette can decide in
/// advance — it has to be computed per colour.
abstract final class AppContrast {
  /// WCAG contrast ratio between two colours, 1 (identical) to 21.
  static double ratio(Color a, Color b) {
    final first = a.computeLuminance();
    final second = b.computeLuminance();
    final lighter = first > second ? first : second;
    final darker = first > second ? second : first;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// The more readable of white and the darkest neutral on [background].
  static Color foregroundOn(Color background) =>
      ratio(background, Colors.white) >= ratio(background, AppNeutrals.light[11])
      ? Colors.white
      : AppNeutrals.light[11];
}

/// Type tokens. The family is bundled in `assets/fonts` — see `pubspec.yaml`.
abstract final class AppTypography {
  static const String fontFamily = 'Manrope';

  /// Fixed-width digits. Applied to every style that renders a clock, a
  /// counter or a duration, so numbers do not shuffle as they tick.
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];
}

/// Per-author accents for group chats: eight hues, each tuned twice so the
/// same author reads at the same strength on either ground.
abstract final class AppAuthorPalette {
  static const List<Color> light = <Color>[
    Color(0xFF6E56F8), // violet
    Color(0xFF0E9F86), // mint
    Color(0xFFD1442F), // coral
    Color(0xFFB07400), // amber
    Color(0xFF2563C9), // azure
    Color(0xFFB13FA8), // orchid
    Color(0xFF4C7A21), // moss
    Color(0xFF9B5524), // clay
  ];

  static const List<Color> dark = <Color>[
    Color(0xFFB0A1FF), // violet
    Color(0xFF5FE0C6), // mint
    Color(0xFFFF9382), // coral
    Color(0xFFF5C46A), // amber
    Color(0xFF8FBAFF), // azure
    Color(0xFFF19CE9), // orchid
    Color(0xFFAEDC77), // moss
    Color(0xFFF0AC7B), // clay
  ];

  /// Both ramps carry this many entries.
  static const int size = 8;

  static List<Color> of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
