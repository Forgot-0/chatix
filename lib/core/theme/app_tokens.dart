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

  /// The media viewer's ground. Black in both themes, like [mediaScrim]:
  /// what it frames is a picture, and a picture looks its own colours only
  /// against black.
  static const Color viewerGround = Color(0xFF000000);

  /// The shade the viewer's bars sit on, at the screen's edge; it fades to
  /// [viewerShadeClear] towards the middle, so the bars read over a white
  /// sky without boxing the picture in.
  static const Color viewerShade = Color(0xCC000000);
  static const Color viewerShadeClear = Color(0x00000000);

  /// Secondary and tertiary text on the viewer: the date under the author,
  /// a video's running time.
  static const Color onViewerMuted = Color(0xB3FFFFFF);
  static const Color onViewerFaint = Color(0x8AFFFFFF);

  /// A video's seek track: the whole length, and what has come down so far.
  static const Color viewerTrack = Color(0x3DFFFFFF);
  static const Color viewerTrackBuffered = Color(0x66FFFFFF);

  /// A QR code's tile and its modules. The same in both themes: a scanner
  /// wants dark modules on a light ground, and inverted codes are the ones
  /// cheap readers miss. The ink is the brand's deep end, dark enough to
  /// read as black to a camera.
  static const Color qrGround = Color(0xFFFFFFFF);
  static const Color qrInk = indigo;

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

/// The ChatiX mark: one outgoing bubble with its anchor corner, and an X.
///
/// Every length is a share of the mark's side, so the one drawing serves a
/// 16 px favicon and a 1024 px store icon alike. The colours are the brand's
/// own and deliberately do not follow the accent picked in appearance
/// settings: a logo that turns green for someone who likes green is no longer
/// the logo.
abstract final class AppBrandMark {
  /// The three soft corners — the same share of the side as a default
  /// bubble's 20 px radius is of a 64 px bubble.
  static const double cornerRadius = 0.31;

  /// The anchor corner, bottom right, where an outgoing bubble points.
  static const double anchorRadius = 0.09;

  /// How far each arm of the X reaches from the centre, along either axis.
  static const double glyphReach = 0.19;

  /// How hard each half of the X bows towards the other: where its curve's
  /// control point sits past the centre, as a share of [glyphReach].
  ///
  /// The X is two strokes leaning in — ")(" pushed together, the two sides
  /// of a conversation — and not a straight cross, because a white cross on
  /// a coloured square is the close button.
  static const double glyphBow = 0.9;

  /// The stroke the X is drawn with.
  static const double glyphStroke = 0.115;

  /// Where the gradient starts (top left) and ends (bottom right).
  static const Color gradientStart = AppPalette.violet;
  static const Color gradientEnd = AppPalette.indigo;

  /// The soft light in the top-left of the bubble: the same bloom the mesh
  /// wallpapers are built from, small enough to read as depth, not as a
  /// second colour.
  static const Color bloom = AppPalette.violetSoft;
  static const double bloomAlpha = 0.55;

  /// The X. White in every theme: it sits on the gradient, never on a ground.
  static const Color glyph = Color(0xFFFFFFFF);

  /// The mark above a sign-in or sign-up form.
  static const double authSize = 64;

  /// The mark the welcome screen opens on.
  static const double welcomeSize = 112;
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

  /// The round badge with a play glyph over a video's poster in the feed,
  /// and the glyph inside it.
  static const double videoPlayBadgeSize = 44;
  static const double videoPlayGlyphSize = 28;

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

/// The full-screen photo and video viewer.
abstract final class MediaViewerLayout {
  /// A double tap zooms to this, centred on where it landed; a second one
  /// goes back.
  static const double doubleTapScale = 2.5;

  /// How far a pinch may zoom.
  static const double maxScale = 5;

  /// Past this scale the picture counts as zoomed: it pans instead of paging
  /// and cannot be dragged away.
  static const double zoomedFrom = 1.01;

  /// How far down the viewer has to be dragged before letting go closes
  /// it…
  static const double dismissDistance = 120;

  /// …or how fast it has to be flung, from anywhere.
  static const double dismissVelocity = 700;

  /// The drag over which the conversation comes back into view.
  static const double fadeDistance = 320;

  /// The faintest the picture gets while dragged: still a picture being
  /// carried, not a ghost.
  static const double dragMinOpacity = 0.3;

  /// The bars hide once the drag has gone this share of [fadeDistance].
  static const double barsHideAt = 0.1;

  /// From this width up the viewer has room for a strip of thumbnails and
  /// for arrows at its sides — the same line the shell draws between a
  /// phone and a tablet.
  static const double wideFrom = 600;

  /// A caption longer than this many lines is folded, with a way to open it.
  static const int captionFoldedLines = 3;

  /// Past this a caption is a line across a monitor.
  static const double captionMaxWidth = 640;

  /// The "More" / "Less" under a folded caption: a line's height, flush
  /// with the caption's edge.
  static const double captionToggleHeight = 32;

  /// An opened caption scrolls rather than grow past this share of the
  /// viewer's height: the picture is still what the screen is for.
  static const double captionOpenMaxHeightFactor = 0.4;

  /// One thumbnail in the strip, the gap between two, and their corners.
  static const double thumbnailSize = 48;
  static const double thumbnailGap = AppSpacing.x1;
  static const double thumbnailRadius = AppRadii.xs;

  /// The ring around the thumbnail of what is open…
  static const double thumbnailRing = 2;

  /// …and how far the others step back from it.
  static const double thumbnailIdleOpacity = 0.6;

  /// The strip's own height: a thumbnail and air above and below it.
  static const double stripHeight = thumbnailSize + AppSpacing.x2 * 2;

  /// The arrows at the sides of a wide viewer.
  static const double arrowButtonSize = 48;
  static const double arrowIconSize = 32;

  /// How much mouse-wheel travel turns one page. A notch on most mice is
  /// 100; a touchpad's trickle has to add up to a deliberate swipe first.
  static const double wheelStep = 40;

  /// The round play button over a paused video, and its glyph.
  static const double playButtonSize = 64;
  static const double playIconSize = 36;

  /// The seek bar: its track, the knob, and the bubble that names the time
  /// the knob is being dragged to.
  static const double seekTrackHeight = 3;
  static const double seekThumbRadius = 7;
  static const double seekBarHeight = 32;
  static const double seekBubbleGap = AppSpacing.x1;

  /// The touch halo around the seek knob — and so how far the track is
  /// inset from either end of the bar.
  static const double seekOverlayRadius = 14;

  /// A video's controls stop growing here: a seek bar across a whole
  /// monitor is a long way for the eye from the play button to the time.
  static const double controlsMaxWidth = 720;

  /// The volume slider beside the mute button on a desktop.
  static const double volumeSliderWidth = 96;

  /// The spinner shown while a file is still coming down.
  static const double spinnerSize = 28;
  static const double spinnerStroke = 2;
}

/// How wide a page's content grows on a wide pane.
abstract final class AppContentWidths {
  /// Forms and the pages built like them — editing a profile, settings.
  /// Past this a text field is a line drawn across a monitor, and a label
  /// sits a long way from the value it names.
  static const double form = 680;

  /// The photo preview before sending: past this an album is a wall of
  /// pixels and the caption a line across the monitor.
  static const double mediaPreview = 640;

  /// A person's profile: the actions, the facts and the shared media in one
  /// column. As wide as the contacts list it is usually opened from.
  static const double profile = 720;

  /// Signing in, signing up and resetting a password: one short column of
  /// fields, as wide as a phone held upright. Wider, and the fields read as
  /// a form somebody forgot to finish laying out.
  static const double auth = 420;
}

/// What a desktop draws that a phone has no use for: hover chrome, the
/// Ctrl+K palette, the drop zone, scrollbars.
abstract final class DesktopSizes {
  /// The narrowest and shortest the window may be dragged to on macOS,
  /// Windows and Linux — a phone-sized window, still one usable pane. The
  /// native runners carry the same two numbers.
  static const Size minWindow = Size(380, 560);

  /// The round buttons that come up beside a hovered bubble — reply and
  /// react — and the glyphs inside them…
  static const double hoverButton = 30;
  static const double hoverIcon = 17;

  /// …the air between them and the bubble's edge, and the inset of the
  /// pill they sit in.
  static const double hoverGap = AppSpacing.x1 + 2;
  static const double hoverPadding = 2;

  /// The Ctrl+K palette: how wide it grows, how far below the top of the
  /// window it opens, how tall its list may get, and one row of it.
  static const double paletteMaxWidth = 560;
  static const double paletteTopInset = 72;
  static const double paletteMaxListHeight = 392;
  static const double paletteRowHeight = 56;

  /// The "drop to send" plate over a chat while files are dragged in: how
  /// far it keeps from the pane's edges, its outline, and its glyph.
  static const double dropInset = AppSpacing.x3;
  static const double dropBorder = 2;
  static const double dropIcon = 44;

  /// Scrollbars: a hairline while the pointer is elsewhere, a grip once it
  /// is over the track.
  static const double scrollbarThickness = 6;
  static const double scrollbarHoverThickness = 10;

  /// The thumb at rest, washed into the page, and under the pointer or a
  /// drag, firm enough to aim at.
  static const double scrollbarAlpha = 0.3;
  static const double scrollbarActiveAlpha = 0.55;
  static const double scrollbarMargin = 2;

  /// How strongly a hovered row is washed with the text colour: enough to
  /// say "this is what a click lands on", not enough to read as selected.
  static const double hoverOverlay = 0.06;
}

/// The round buttons under a profile's header — write, call, mute, more.
abstract final class QuickActionSizes {
  /// The button itself, a circle.
  static const double button = 52;
  static const double icon = 24;

  /// The column one action owns, button and word together. The row is
  /// these columns side by side and centred, so two actions stay a pair
  /// rather than drifting to the edges of a wide pane.
  static const double slot = 84;

  /// Between the button and the word under it.
  static const double labelGap = 6;
}

/// A person's profile page.
abstract final class ProfileLayout {
  /// The camera on the corner of one's own face, and the ring of page
  /// colour that keeps it from melting into the photo.
  static const double cameraBadge = 36;
  static const double cameraIcon = 18;
  static const double cameraRing = 2;

  /// How far from the right edge the collapsed name stops when the bar
  /// carries a text button ("Edit", "Bearbeiten") on that side.
  static const double barTrailingInset = 128;

  /// A row of the facts card: the value, and the word for it under it.
  static const double infoRowMinHeight = 60;
  static const double infoLineGap = 2;

  /// The card around the facts, rounded like the rest of the app's cards.
  static const double cardRadius = AppRadii.lg;

  /// The code a camera reads, and the white tile under it — white in both
  /// themes, because a scanner wants dark modules on a light ground.
  static const double qrSize = 220;
  static const double qrPadding = AppSpacing.x4;
  static const double qrTileRadius = AppRadii.xl;

  /// How strongly the "you blocked them" note is washed with the danger
  /// colour over the card it would otherwise be.
  static const double blockedTint = 0.12;
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

/// Popup menus — the "⋮" of a chat and the choices it opens.
abstract final class AppMenuSizes {
  /// The glyph a menu line starts with: a step under the app bar's own 24,
  /// so the words lead and the glyphs keep the column.
  static const double iconSize = 20;

  /// Between that glyph and the words.
  static const double iconGap = AppSpacing.x4;

  /// The narrowest a menu is drawn: wide enough that a short menu does not
  /// look like a tooltip next to a long one…
  static const double minWidth = 220;

  /// …and the widest, where "Mute until I turn it back on" still fits on a
  /// line in the languages that say it at length.
  static const double maxWidth = 320;
}

/// The composer's input row: the field's pill and what sits inside it.
abstract final class ComposerSizes {
  /// The pill the field is drawn in — Android's 48 dp target, the stricter
  /// of the two platforms' guidelines.
  static const double fieldMinHeight = 48;

  /// The emoji button at the start of the pill: as tall as the pill, a
  /// little narrower than square so the text does not start far from the
  /// edge.
  static const Size emojiButton = Size(40, fieldMinHeight);

  static const double emojiIconSize = 24;

  /// The glyph before the sentence that stands where the composer would be
  /// when the reader cannot write.
  static const double lockedIconSize = 16;

  /// From this width the locked bar's button sits on the sentence's line
  /// ("You blocked this user · Unblock"); below it, under the sentence.
  static const double lockedActionInlineFrom = 480;
}

/// The list of people an `@` being typed could mean, floating over the
/// bottom of the conversation.
/// The contacts tab.
abstract final class ContactsLayout {
  /// How wide the list grows on a wide pane before it centres: rows longer
  /// than this put the name and its button too far apart to read as one.
  static const double maxWidth = 720;

  /// The pill search field at the top.
  static const double searchHeight = 44;

  /// The tinted circle behind an action row's icon — as wide as a person's
  /// face below it, so actions and names start on the same line.
  static const double actionBadge = 40;
  static const double actionIcon = 22;

  /// The mutual-contact mark after a name.
  static const double mutualIcon = 15;

  /// Between a row's name and the line under it.
  static const double lineGap = 2;

  /// Space for one letter heading.
  static const double letterHeight = 32;

  /// The glyph of a note above a list — the block list's "what blocking
  /// does today".
  static const double noteIcon = 20;
}

/// "New message", "New group", "New channel": the people picker and the
/// details step.
abstract final class NewChatLayout {
  /// The photo button beside a new chat's name — between a list row's face
  /// and a profile header's, so it reads as "this chat's picture" without
  /// pushing the name field off a phone.
  static const double photoSize = 64;
  static const double photoIcon = 26;

  /// The pencil badge on a picked photo.
  static const double photoBadge = 22;
  static const double photoBadgeIcon = 13;

  /// The round tick at the end of a row in the picker.
  static const double checkSize = 22;
  static const double checkIcon = 16;
  static const double checkBorder = 2;

  /// The box of picked people grows up to this, then scrolls, so the list
  /// under it never disappears behind a hundred chips.
  static const double chipsMaxHeight = 136;

  /// A chip: its face, its name's longest run, the cross after it.
  static const double chipHeight = 32;
  static const double chipNameMaxWidth = 140;
  static const double chipCloseIcon = 16;

  /// The search field inside the chip box keeps at least this much of a
  /// line to itself, so there is always room to type after the chips.
  static const double inlineFieldMinWidth = 140;
}

/// A search box that is really a button (`AppSearchPill`): it looks like the
/// field you type into and opens the screen where you do.
abstract final class SearchPillSizes {
  /// As tall as the contacts tab's own field, so the two tabs line up.
  static const double height = ContactsLayout.searchHeight;

  /// The slot the magnifier sits in — an input decoration's prefix slot, so
  /// the hint starts where typed text starts in a real field.
  static const double iconSlot = 48;
}

/// The chats list: its header, the marks on its rows, room for the FAB.
abstract final class ChatsListLayout {
  /// The title row — the large "Chats", or the connection state in its place.
  static const double titleBarHeight = 56;

  /// Around the search pill: a little above it, a little more below.
  static const double searchPaddingTop = AppSpacing.x1;
  static const double searchPaddingBottom = AppSpacing.x2;

  /// The part of the header that scrolls away and floats back.
  static const double searchBlockHeight =
      searchPaddingTop + SearchPillSizes.height + searchPaddingBottom;

  /// How far type in the header may grow. Chrome of a fixed height cannot
  /// honour an unbounded scale — the rows below it scale freely, and the
  /// folder strip stops at the same point.
  static const double maxTextScale = 1.3;

  /// The spinner beside "Connecting…", the glyph beside "Waiting for
  /// network…".
  static const double statusGlyph = 16;
  static const double statusStroke = 2;
  static const double statusGap = AppSpacing.x3;

  /// The unread count and the `@` beside it: one height, so they read as a
  /// pair.
  static const double badgeHeight = 20;

  /// The pin, the crossed-out bell, the block mark.
  static const double markerGlyph = 15;

  /// Under the last row on a phone: clear of the round FAB, which would
  /// otherwise sit on that row's badge.
  static const double fabClearance = 88;

  /// Under the last row where there is no FAB.
  static const double endPadding = AppSpacing.x2;
}

/// Settings: the profile card on top, the rounded groups of rows under it,
/// and the coloured square every row leads with.
abstract final class SettingsLayout {
  /// The coloured square, its corners, and the white glyph inside it — the
  /// size of a line of title text and a half, so a row reads by its colour
  /// before its words.
  static const double plateSize = 30;
  static const double plateRadius = AppRadii.sm;
  static const double plateIcon = 18;

  /// Between the square and the title.
  static const double plateGap = AppSpacing.x4;

  /// A row with one line of text: a touch target and a little air.
  static const double rowMinHeight = 52;

  /// Between a row's title and the line under it.
  static const double lineGap = 2;

  /// The spinner a row ends with while what it started is under way.
  static const double rowSpinner = 18;

  /// A group's own inset from the pane's edges, its corners, and the air
  /// between two groups.
  static const double groupInset = AppSpacing.x4;
  static const double groupRadius = AppRadii.lg;
  static const double groupGap = AppSpacing.x5;

  /// The hairline between two rows starts where their titles start, so the
  /// squares read as one column, the way a grouped list does it.
  static const double rowDividerIndent = AppSpacing.x4 + plateSize + plateGap;

  /// The camera on the corner of the card's avatar: smaller than the one
  /// on the profile itself, which sits on a face twice the size.
  static const double cameraBadge = 26;
  static const double cameraIcon = 14;
  static const double cameraRing = 2;

  /// Between the card's avatar and the name beside it.
  static const double cardAvatarGap = AppSpacing.x4;

  /// The search field over the groups — as tall as every other search box.
  static const double searchHeight = SearchPillSizes.height;

  /// The value a row shows at its end — the current language — stops here,
  /// so a long one is cut before it pushes the title off the row.
  static const double valueMaxWidth = 160;

  /// The block over About's rows: the logo and the app's name.
  static const double aboutLogo = 72;

  /// The used share of the cache limit, as a bar.
  static const double usageBarHeight = 8;
}

abstract final class MentionListSizes {
  /// One person: a face, the name and the handle on a line.
  static const double rowHeight = 48;

  /// Four rows and half of a fifth, so a longer list shows that it scrolls
  /// without covering half the conversation.
  static const double visibleRows = 4.5;

  static const double maxHeight = rowHeight * visibleRows + AppSpacing.x1 * 2;
}

/// The emoji panel that takes the keyboard's place under the composer.
abstract final class EmojiPanelSizes {
  /// What the panel opens at before this device has ever shown a keyboard
  /// — every desktop, and a phone on its very first emoji.
  static const double defaultHeight = 300;

  /// Never shorter than this, whatever the keyboard was: under it the grid
  /// is a row and a half between the search field and the tabs…
  static const double minHeight = 220;

  /// …and never more than this share of the pane, so a tall keyboard on a
  /// short landscape window leaves the conversation some room.
  static const double maxHeightFactor = 0.55;

  /// A keyboard shorter than this is an accessory bar or a hardware
  /// keyboard's candidate strip, not a height worth opening the panel at.
  static const double minKeyboard = 120;

  /// One emoji's tap target. Rows are exactly this tall; columns share the
  /// width, so cells come out square or a little wider.
  static const double cell = 44;

  /// The glyph inside it.
  static const double glyph = 28;

  /// The search field along the top.
  static const double searchBarHeight = 48;

  /// A section's title above its part of the grid.
  static const double sectionHeaderHeight = 32;

  /// The strip of category icons along the bottom, and the icons in it.
  static const double tabBarHeight = 44;
  static const double tabIconSize = 22;

  /// While the panel's own search has the keyboard, the panel shrinks to
  /// this above it: the field, and one row of answers.
  static const double searchStripHeight =
      searchBarHeight + cell + AppSpacing.x2;
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

  /// One notch of a mouse wheel gliding the feed to where it points —
  /// shorter than [fast] keeps up with a quick spin, and anything at all is
  /// what stops a notch from reading as a jump.
  static const Duration wheel = Duration(milliseconds: 110);

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
    AppPlatePalette.violet,
    AppPlatePalette.mint,
    AppPlatePalette.coral,
    AppPlatePalette.amber,
    AppPlatePalette.azure,
    AppPlatePalette.orchid,
    AppPlatePalette.moss,
    AppPlatePalette.clay,
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

/// The grounds of the coloured squares settings rows lead with — a white
/// glyph on one of these, one hue per row.
///
/// The deep end of each hue, which is also the author palette's light-ground
/// ramp: every one of them carries white at 3:1 or better, which is what a
/// glyph needs, and none of them is so dark that it turns into a hole in a
/// dark theme. So the squares keep their colours in both themes, the way an
/// app icon does — a row is found by its colour, and a colour that changed
/// with the theme would have to be learned twice.
abstract final class AppPlatePalette {
  static const Color violet = Color(0xFF6E56F8);
  static const Color mint = Color(0xFF0E9F86);
  static const Color coral = Color(0xFFD1442F);
  static const Color amber = Color(0xFFB07400);
  static const Color azure = Color(0xFF2563C9);
  static const Color orchid = Color(0xFFB13FA8);
  static const Color moss = Color(0xFF4C7A21);
  static const Color clay = Color(0xFF9B5524);

  /// The brand's deep end, for the row that is about the app itself
  /// rather than about the reader.
  static const Color indigo = AppPalette.indigo;

  /// A warm grey from the neutral ramp, for rows that are information
  /// rather than a place to change something.
  static const Color graphite = Color(0xFF6A6156);

  /// Destructive rows: signing out.
  static const Color danger = AppPalette.coralDeep;

  /// The glyph on every square.
  static const Color glyph = Color(0xFFFFFFFF);
}
