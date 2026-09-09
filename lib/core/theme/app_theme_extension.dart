import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/theme/theme_config.dart';

/// The half of the ChatiX design system that [ColorScheme] has no room for.
///
/// Message bubbles, date chips, reaction chips, the composer ground and the
/// per-author accents all need colours that Material does not name. They are
/// derived from the active [ColorScheme] — so a user-picked accent flows
/// through them — and reached from widgets via [ChatixTheme.of].
@immutable
class ChatixTheme extends ThemeExtension<ChatixTheme> {
  const ChatixTheme({
    required this.brightness,
    required this.bubbleOutgoingGradient,
    required this.bubbleOutgoingForeground,
    required this.bubbleIncoming,
    required this.bubbleIncomingForeground,
    required this.bubbleIncomingBorder,
    required this.chatBackground,
    required this.dateChip,
    required this.unreadDivider,
    required this.reactionChip,
    required this.reactionChipSelected,
    required this.onlineDot,
    required this.authorPalette,
    required this.composerSurface,
    required this.wallpaperSeed,
    required this.success,
    required this.danger,
    required this.attention,
    required this.bubbleRadius,
    required this.bubbleAnchorRadius,
    required this.density,
  });

  /// Which ground these colours were tuned for. Kept on the extension so
  /// widgets can pick a variant without a second [Theme.of] lookup.
  final Brightness brightness;

  /// Fill of a message you sent.
  final LinearGradient bubbleOutgoingGradient;

  /// Text and icons on [bubbleOutgoingGradient].
  final Color bubbleOutgoingForeground;

  /// Fill of a message someone else sent.
  final Color bubbleIncoming;

  /// Text and icons on [bubbleIncoming].
  final Color bubbleIncomingForeground;

  /// Hairline around an incoming bubble. Transparent in dark, where the
  /// bubble separates from the ground by elevation instead.
  final Color bubbleIncomingBorder;

  /// The ground a conversation is painted on.
  final Color chatBackground;

  /// The floating "Today" / "12 May" pill between message groups.
  final Color dateChip;

  /// The rule of the "unread messages" marker.
  final Color unreadDivider;

  /// A reaction chip you have not reacted with.
  final Color reactionChip;

  /// A reaction chip carrying your own reaction.
  final Color reactionChipSelected;

  /// The presence dot on an avatar.
  final Color onlineDot;

  /// Eight accents, indexed by author, for names in group chats.
  final List<Color> authorPalette;

  /// The ground under the message composer.
  final Color composerSurface;

  /// Accent the chat wallpaper blooms from.
  final Color wallpaperSeed;

  /// Delivered/read ticks, confirmations.
  final Color success;

  /// Destructive actions, failed sends.
  final Color danger;

  /// Warnings, pending states.
  final Color attention;

  /// Radius of a bubble's free corners. The geometry that turns these two
  /// numbers into corners lives in `BubbleShape`, next to the bubbles.
  final double bubbleRadius;

  /// Radius of the corner that anchors a bubble to its author's side.
  final double bubbleAnchorRadius;

  /// How much air messages and rows get.
  final AppDensity density;

  /// The band the outgoing gradient's head is held inside.
  static const double _headLightness = 0.62;
  static const double _headMinLightness = 0.42;
  static const double _headMinSaturation = 0.55;

  static const Duration fastDuration = AppMotion.fast;
  static const Duration duration = AppMotion.base;
  static const Duration slowDuration = AppMotion.slow;
  static const Curve curve = AppMotion.curve;

  /// The accent for [userId], stable across sessions and readable on the
  /// current ground. Falls back to a neutral for an unknown author.
  Color authorColor(int? userId) {
    if (userId == null) return AppNeutrals.outline(brightness);
    return authorPalette[userId.abs() % authorPalette.length];
  }

  /// The extension carried by the ambient theme, or a default one if the
  /// widget is being rendered outside a ChatiX theme (bare test harnesses).
  static ChatixTheme of(BuildContext context) =>
      Theme.of(context).extension<ChatixTheme>() ?? _fallback;

  static final ChatixTheme _fallback = fromScheme(
    scheme: ColorScheme.fromSeed(seedColor: AppPalette.violet),
    density: AppDensity.cozy,
  );

  /// Derives every chat colour from [scheme], so the whole surface follows a
  /// user-picked accent instead of hard-coding violet.
  ///
  /// [accent] is the raw seed the user picked. It matters because a dark
  /// scheme's `primary` is a lifted, pale tone: right for buttons, far too
  /// washed out for a fill the size of a message bubble.
  static ChatixTheme fromScheme({
    required ColorScheme scheme,
    required AppDensity density,
    Color? accent,
  }) {
    final brightness = scheme.brightness;
    final isDark = brightness == Brightness.dark;

    final seed = HSLColor.fromColor(accent ?? scheme.primary);

    // The gradient runs from a saturated head to a deeper tail. The head is
    // pulled into a narrow band of lightness so that any accent — pale amber
    // or deep indigo — still reads as a bubble and not as a highlight.
    final head = seed
        .withLightness(seed.lightness.clamp(_headMinLightness, _headLightness))
        .withSaturation(
          seed.saturation < _headMinSaturation
              ? _headMinSaturation
              : seed.saturation,
        )
        .toColor();
    final tail = HSLColor.fromColor(head)
        .withLightness(
          (HSLColor.fromColor(head).lightness - 0.16).clamp(0.0, 1.0),
        )
        .toColor();

    final incoming = isDark
        ? AppElevations.surfaceOf(brightness, AppNeutrals.dark[8], 1)
        : AppNeutrals.light[0];

    return ChatixTheme(
      brightness: brightness,
      bubbleOutgoingGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[head, tail],
      ),
      bubbleOutgoingForeground: AppContrast.foregroundOn(head),
      bubbleIncoming: incoming,
      bubbleIncomingForeground: AppNeutrals.text(brightness),
      bubbleIncomingBorder: isDark
          ? Colors.transparent
          : AppNeutrals.border(brightness),
      chatBackground: AppNeutrals.canvas(brightness),
      dateChip: (isDark ? AppNeutrals.dark[7] : AppNeutrals.light[3])
          .withValues(alpha: 0.92),
      unreadDivider: scheme.primary.withValues(alpha: 0.4),
      reactionChip: AppNeutrals.surfaceMuted(brightness),
      reactionChipSelected: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.16),
        AppNeutrals.surface(brightness),
      ),
      onlineDot: AppPalette.mint,
      authorPalette: AppAuthorPalette.of(brightness),
      composerSurface: AppElevations.surfaceOf(
        brightness,
        isDark ? AppNeutrals.dark[9] : AppNeutrals.light[0],
        2,
      ),
      wallpaperSeed: scheme.primary,
      success: AppPalette.mint,
      danger: AppPalette.coral,
      attention: AppPalette.amber,
      bubbleRadius: AppRadii.xl,
      bubbleAnchorRadius: AppRadii.xs + 2,
      density: density,
    );
  }

  /// Convenience for tests, previews and the [of] fallback.
  static ChatixTheme light([AppDensity density = AppDensity.cozy]) =>
      fromScheme(
        scheme: ColorScheme.fromSeed(seedColor: AppPalette.violet),
        density: density,
      );

  /// Convenience for tests, previews and the [of] fallback.
  static ChatixTheme dark([AppDensity density = AppDensity.cozy]) => fromScheme(
    scheme: ColorScheme.fromSeed(
      seedColor: AppPalette.violet,
      brightness: Brightness.dark,
    ),
    density: density,
  );

  @override
  ChatixTheme copyWith({
    Brightness? brightness,
    LinearGradient? bubbleOutgoingGradient,
    Color? bubbleOutgoingForeground,
    Color? bubbleIncoming,
    Color? bubbleIncomingForeground,
    Color? bubbleIncomingBorder,
    Color? chatBackground,
    Color? dateChip,
    Color? unreadDivider,
    Color? reactionChip,
    Color? reactionChipSelected,
    Color? onlineDot,
    List<Color>? authorPalette,
    Color? composerSurface,
    Color? wallpaperSeed,
    Color? success,
    Color? danger,
    Color? attention,
    double? bubbleRadius,
    double? bubbleAnchorRadius,
    AppDensity? density,
  }) {
    return ChatixTheme(
      brightness: brightness ?? this.brightness,
      bubbleOutgoingGradient:
          bubbleOutgoingGradient ?? this.bubbleOutgoingGradient,
      bubbleOutgoingForeground:
          bubbleOutgoingForeground ?? this.bubbleOutgoingForeground,
      bubbleIncoming: bubbleIncoming ?? this.bubbleIncoming,
      bubbleIncomingForeground:
          bubbleIncomingForeground ?? this.bubbleIncomingForeground,
      bubbleIncomingBorder: bubbleIncomingBorder ?? this.bubbleIncomingBorder,
      chatBackground: chatBackground ?? this.chatBackground,
      dateChip: dateChip ?? this.dateChip,
      unreadDivider: unreadDivider ?? this.unreadDivider,
      reactionChip: reactionChip ?? this.reactionChip,
      reactionChipSelected: reactionChipSelected ?? this.reactionChipSelected,
      onlineDot: onlineDot ?? this.onlineDot,
      authorPalette: authorPalette ?? this.authorPalette,
      composerSurface: composerSurface ?? this.composerSurface,
      wallpaperSeed: wallpaperSeed ?? this.wallpaperSeed,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      attention: attention ?? this.attention,
      bubbleRadius: bubbleRadius ?? this.bubbleRadius,
      bubbleAnchorRadius: bubbleAnchorRadius ?? this.bubbleAnchorRadius,
      density: density ?? this.density,
    );
  }

  @override
  ChatixTheme lerp(ThemeExtension<ChatixTheme>? other, double t) {
    if (other is! ChatixTheme) return this;
    return ChatixTheme(
      brightness: t < 0.5 ? brightness : other.brightness,
      bubbleOutgoingGradient:
          LinearGradient.lerp(
            bubbleOutgoingGradient,
            other.bubbleOutgoingGradient,
            t,
          ) ??
          bubbleOutgoingGradient,
      bubbleOutgoingForeground: Color.lerp(
        bubbleOutgoingForeground,
        other.bubbleOutgoingForeground,
        t,
      )!,
      bubbleIncoming: Color.lerp(bubbleIncoming, other.bubbleIncoming, t)!,
      bubbleIncomingForeground: Color.lerp(
        bubbleIncomingForeground,
        other.bubbleIncomingForeground,
        t,
      )!,
      bubbleIncomingBorder: Color.lerp(
        bubbleIncomingBorder,
        other.bubbleIncomingBorder,
        t,
      )!,
      chatBackground: Color.lerp(chatBackground, other.chatBackground, t)!,
      dateChip: Color.lerp(dateChip, other.dateChip, t)!,
      unreadDivider: Color.lerp(unreadDivider, other.unreadDivider, t)!,
      reactionChip: Color.lerp(reactionChip, other.reactionChip, t)!,
      reactionChipSelected: Color.lerp(
        reactionChipSelected,
        other.reactionChipSelected,
        t,
      )!,
      onlineDot: Color.lerp(onlineDot, other.onlineDot, t)!,
      authorPalette: <Color>[
        for (var i = 0; i < authorPalette.length; i++)
          Color.lerp(
            authorPalette[i],
            i < other.authorPalette.length
                ? other.authorPalette[i]
                : authorPalette[i],
            t,
          )!,
      ],
      composerSurface: Color.lerp(composerSurface, other.composerSurface, t)!,
      wallpaperSeed: Color.lerp(wallpaperSeed, other.wallpaperSeed, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      attention: Color.lerp(attention, other.attention, t)!,
      bubbleRadius: lerpDouble(bubbleRadius, other.bubbleRadius, t),
      bubbleAnchorRadius: lerpDouble(
        bubbleAnchorRadius,
        other.bubbleAnchorRadius,
        t,
      ),
      density: t < 0.5 ? density : other.density,
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
