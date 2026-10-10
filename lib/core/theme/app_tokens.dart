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

  /// [coral] taken down far enough to read as error text on a light ground.
  ///
  /// Coral itself is 2.9:1 on the light canvas — fine as a fill, well under
  /// AA as the word "failed". Dark themes keep the brighter one, where it
  /// already clears.
  static const Color coralDeep = Color(0xFFD1260F);

  /// Warnings and "needs attention" affordances.
  static const Color amber = Color(0xFFF5A524);

  /// Cool, corporate blue.
  static const Color azure = Color(0xFF2563C9);

  /// Warm green, far enough from [mint] to read as its own hue.
  static const Color moss = Color(0xFF4E9A3F);

  /// Pink end of the warm half.
  static const Color rose = Color(0xFFE0457B);

  /// Magenta-violet, the far end of the cool half.
  static const Color orchid = Color(0xFFB13FA8);

  /// The plate small text sits on when it is drawn over a photo — the time
  /// on a picture with no caption, a video's running time.
  ///
  /// The same in both themes: what it has to read against is the picture,
  /// and a picture does not change with the theme.
  static const Color mediaScrim = Color(0x73000000);

  /// Text and icons on [mediaScrim].
  static const Color onMediaScrim = Color(0xFFFFFFFF);

  /// The ground a video is drawn on while there is no frame to show (the
  /// API stores no poster), top to bottom.
  ///
  /// Dark in both themes, because that is what reads as "video" — but kept
  /// clear of the dark theme's chat canvas: a photo with no caption has no
  /// bubble around it, and a video tile the colour of the canvas would let
  /// the album fall apart into the wallpaper.
  static const Color videoGroundTop = Color(0xFF524B42);
  static const Color videoGroundBottom = Color(0xFF302B24);

  /// The eight curated accents offered in appearance settings.
  ///
  /// Eight rather than a free colour wheel, and spaced roughly evenly around
  /// it: every one of them has been checked to carry white or graphite text
  /// at the bubble lightness the generator pins it to, which an arbitrary
  /// hand-picked colour has not. The eyedropper is the escape hatch for
  /// anyone who wants something else, and it lands on this same ramp.
  static const List<Color> accentSeeds = <Color>[
    violet,
    azure,
    mint,
    moss,
    amber,
    coral,
    rose,
    orchid,
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

/// The ramp the dark theme swaps to when "black" is switched on.
///
/// Not a darker end of [AppNeutrals.dark] but its own short scale, because
/// the point of an OLED theme is the one colour the neutral ramp deliberately
/// avoids: true black, which costs no light at all on an emissive panel. The
/// steps above it stay warm and close together so that cards, sheets and the
/// composer are still distinguishable from the void behind them.
abstract final class AppAmoled {
  /// The ground. Actually black — anything else defeats the point.
  static const Color canvas = Color(0xFF000000);

  /// Raised surfaces, darkest first.
  static const List<Color> surfaces = <Color>[
    Color(0xFF0A0908),
    Color(0xFF121110),
    Color(0xFF1A1816),
    Color(0xFF232120),
  ];

  /// Hairlines. Visible on black, where the neutral border is not.
  static const Color border = Color(0xFF2A2724);

  static Color step(int index) => surfaces[index.clamp(0, surfaces.length - 1)];
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

/// How big a message may be, measured against the feed it is drawn in.
///
/// Every width here is a share of the *feed's* viewport, never of the
/// window: in a two-pane layout the feed is a fraction of the window, and a
/// bubble sized off the window spills across the whole conversation. The
/// fixed caps are what keep a desktop-width feed from producing a desktop-
/// width photo.
abstract final class ChatLayout {
  /// A text bubble takes at most this share of the feed…
  static const double bubbleWidthFactor = 0.80;

  /// …and never more than this, however wide the feed is: past it a line of
  /// text gets too long to read comfortably.
  static const double bubbleMaxWidth = 560;

  /// A photo, a video or an album takes at most this share of the feed…
  static const double mediaWidthFactor = 0.72;

  /// …capped at this on a phone-width feed…
  static const double mediaMaxWidthCompact = 380;

  /// …and at this once the feed is at least [mediaWideFrom] across.
  static const double mediaMaxWidthWide = 420;

  /// The feed width from which [mediaMaxWidthWide] applies.
  static const double mediaWideFrom = 600;

  /// A picture is never taller than this share of the feed's height…
  static const double mediaHeightFactor = 0.5;

  /// …nor than this, so a tall feed on a monitor is not one portrait.
  static const double mediaMaxHeight = 440;

  /// Below these a picture is cropped rather than shrunk further: a sliver
  /// of a panorama is still recognisably a picture, a 40 px strip is not.
  static const double mediaMinWidth = 140;
  static const double mediaMinHeight = 100;

  /// The gap between tiles of an album, and the corners on either side of
  /// it. The album's outer corners are the bubble's own.
  static const double albumSeam = 2;
  static const double albumSeamRadius = 3;

  /// Inset of the time-and-ticks plate drawn over a picture, and the air
  /// inside it.
  static const double mediaMetaInset = 6;
  static const EdgeInsets mediaMetaPadding = EdgeInsets.symmetric(
    horizontal: 6,
    vertical: 2,
  );

  /// The air between the last word of a message and its time, when the two
  /// share a line.
  static const double metaGap = 6;

  /// Between the "edited" mark, the time and the ticks.
  static const double metaItemGap = AppSpacing.x1;

  /// The delivery ticks beside the time.
  static const double metaTickSize = 14;

  /// The picture in a reply's quote: its side, its corners, and the air
  /// between it and the quote's rule.
  static const double replyThumbnailSize = 36;
  static const double replyThumbnailRadius = AppRadii.xs;
  static const double replyThumbnailInset = 6;

  /// The round button a document in a bubble leads with — download, its
  /// progress, then the kind of file — and the glyph inside it.
  static const double documentButtonSize = 44;
  static const double documentGlyphSize = 22;

  /// The ring drawn around that button while a document comes down.
  static const double documentRingStroke = 2.5;

  /// How many lines a document's name may take before it is cut in the
  /// middle, keeping its extension in sight.
  static const int documentNameMaxLines = 2;

  /// The air above and below an attachment's row inside a bubble, and
  /// between a document's name and its size.
  static const double attachmentRowPaddingY = 2;

  /// How far a bubble keeps from the side of the feed it hangs off.
  static const double bubbleInsetX = AppSpacing.x3;

  /// Beside a run of incoming messages in a group, how far the author's face
  /// sits from the edge of the feed…
  static const double avatarInset = AppSpacing.x2;

  /// …and the air between that face and the bubbles it belongs to.
  static const double avatarGap = AppSpacing.x2;

  /// The width held open on the left of a group's incoming messages for a
  /// face [diameter] across: inset, face, gap. Measured to the bubble's own
  /// edge, so the bubble's [bubbleInsetX] is part of it, not added to it.
  static double avatarGutterFor(double diameter) =>
      avatarInset + diameter + avatarGap;

  /// Past this feed width the conversation stops following the window and
  /// sits in a centred column of [columnMaxWidth]: messages strung across
  /// a 1600 px pane read as two conversations, one at each edge.
  static const double columnFrom = 1000;
  static const double columnMaxWidth = 860;

  /// The width of the column messages and the composer sit in, for a pane
  /// [paneWidth] across. The wallpaper behind them still fills the pane.
  static double columnWidthFor(double paneWidth) =>
      paneWidth > columnFrom ? columnMaxWidth : paneWidth;

  /// The widest a text bubble may be in a feed [feedWidth] across.
  static double bubbleMaxWidthFor(double feedWidth) =>
      _min(feedWidth * bubbleWidthFactor, bubbleMaxWidth);

  /// The widest a picture or an album may be in a feed [feedWidth] across.
  static double mediaMaxWidthFor(double feedWidth) => _min(
    feedWidth * mediaWidthFactor,
    feedWidth >= mediaWideFrom ? mediaMaxWidthWide : mediaMaxWidthCompact,
  );

  /// The tallest a picture or an album may be in a feed [feedHeight] tall.
  static double mediaMaxHeightFor(double feedHeight) =>
      _min(feedHeight * mediaHeightFactor, mediaMaxHeight);

  static double _min(double a, double b) => a < b ? a : b;
}

/// How wide a page's content grows on a wide pane.
abstract final class AppContentWidths {
  /// Forms and the pages built like them — editing a profile, settings.
  /// Past this a text field is a line drawn across a monitor, and a label
  /// sits a long way from the value it names.
  static const double form = 680;
}

/// How wide dialogs grow.
abstract final class AppDialogSizes {
  /// The narrowest a dialog may be — Material's own default, restated for
  /// the dialogs that set their own constraints and so replace it.
  static const double minWidth = 280;

  /// The widest a dialog holding a list to pick from may be — a forward
  /// target, a person. On a phone it takes the screen less the dialog's own
  /// insets; on a desktop it stops here, because a row of avatar and title
  /// stretched across a monitor puts the two a hand's width apart.
  static const double pickerMaxWidth = 440;
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
///
/// Every duration and curve the app animates with is one of these. A widget
/// reaching for a `Duration(milliseconds: 240)` of its own is how a design
/// system drifts: six hand-picked numbers within 40 ms of each other read as
/// sloppiness rather than as intent, and none of them can be tuned at once.
/// The scale below is deliberately short — if a new piece of motion does not
/// fit it, the question is usually what it is trying to say, not which
/// millisecond it needs.
abstract final class AppMotion {
  /// Taps, ripples, small state flips.
  static const Duration fast = Duration(milliseconds: 120);

  /// The default: bubbles arriving, banners, list reflow.
  static const Duration base = Duration(milliseconds: 220);

  /// Page transitions, sheets, anything travelling a long distance.
  static const Duration slow = Duration(milliseconds: 320);

  /// A beat longer than [slow], for the few one-shots that are meant to be
  /// watched rather than got out of the way: a reaction landing, a sent
  /// message settling into the feed.
  static const Duration expressive = Duration(milliseconds: 480);

  /// One breath of something that is happening right now — the recording
  /// bar's pulse, a live indicator.
  static const Duration pulse = Duration(milliseconds: 900);

  /// One turn of an ambient loop: typing dots, a shimmer sweep, a connection
  /// banner. Slow on purpose; a loop faster than this reads as a flicker.
  static const Duration loop = Duration(milliseconds: 1200);

  /// How long a one-shot stays put before it lets go — a jumped-to message
  /// staying lit, a toast holding still.
  static const Duration dwell = Duration(milliseconds: 1400);

  static const Curve curve = Curves.easeOutCubic;

  /// For the "leaving" half of a transition.
  static const Curve reverseCurve = Curves.easeInCubic;

  /// For a value that travels and stops in one gesture — a slider settling,
  /// a header collapsing — where easing only one end looks lopsided.
  static const Curve standard = Curves.easeInOutCubic;

  /// Arrival with a little weight behind it. Used where something has
  /// travelled and lands: never for something merely appearing.
  static const Curve arrive = Curves.easeOutBack;

  /// The spring a dragged thing returns on.
  ///
  /// Under-damped just enough to overshoot once at speed and not at all when
  /// let go gently, which is what makes a gesture feel attached to the finger
  /// rather than animated at it.
  static const SpringDescription gestureSpring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 26,
  );

  /// A heavier spring for something with a longer way to travel — a sheet
  /// snapping shut, a bubble taking off. Critically damped: no overshoot,
  /// because the thing that overshoots here is a whole card.
  static const SpringDescription travelSpring = SpringDescription(
    mass: 1,
    stiffness: 260,
    damping: 32,
  );
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
      ratio(background, Colors.white) >=
          ratio(background, AppNeutrals.light[11])
      ? Colors.white
      : AppNeutrals.light[11];

  /// A quieter [foreground] that still clears [minimum] against [background].
  ///
  /// The clock, the "edited" mark and the delivery ticks are meant to sit
  /// back from the message, and the obvious way to do that — a fixed alpha
  /// on the body colour — silently drops them below AA on most accents: at
  /// `alpha: 0.66`, white on the violet gradient is 3.4:1, and small text
  /// needs 4.5:1. So the alpha is a starting point rather than a promise,
  /// and it is walked back towards opaque until the ratio holds.
  ///
  /// Returns an opaque colour: the caller is spared compositing it, and the
  /// ratio measured here is the one the eye actually gets.
  ///
  /// [alsoOn] are other grounds the same colour will be drawn on — the far
  /// stop of a gradient — and the ratio has to hold over each of them too.
  static Color mutedOn(
    Color background,
    Color foreground, {
    double alpha = 0.66,
    double minimum = 4.5,
    List<Color> alsoOn = const <Color>[],
  }) {
    // Worst case is fully opaque, which is what `foregroundOn` already
    // guarantees — so this terminates with a readable colour or with the
    // body colour itself.
    for (var step = alpha; step < 1; step += 0.02) {
      final blended = Color.alphaBlend(
        foreground.withValues(alpha: step),
        background,
      );
      if (minRatio(blended, <Color>[background, ...alsoOn]) >= minimum) {
        return blended;
      }
    }

    return Color.alphaBlend(foreground, background);
  }

  /// White for a glyph on [background] wherever white reaches [minimum] —
  /// 3:1, what WCAG asks of an icon — and the darkest neutral otherwise.
  ///
  /// Not [foregroundOn]: that picks whichever reads *better*, which for
  /// body text is right, but turns the arrow on a red or blue disc black
  /// when white was perfectly legible and is what such a disc is expected
  /// to carry.
  static Color iconOn(Color background, {double minimum = 3.0}) =>
      ratio(background, Colors.white) >= minimum
      ? Colors.white
      : AppNeutrals.light[11];

  /// The worst contrast [foreground] gets over any of [grounds] — the number
  /// that matters for something drawn across a gradient.
  static double minRatio(Color foreground, Iterable<Color> grounds) {
    var worst = double.infinity;
    for (final ground in grounds) {
      final value = ratio(ground, foreground);
      if (value < worst) worst = value;
    }
    return worst;
  }
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
