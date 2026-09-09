import 'package:flutter/material.dart';

import 'package:chatix/core/theme/chatix_palette.dart';

enum ChatDensity {
  compact,
  cosy,
  spacious;

  static ChatDensity fromName(String? value) => ChatDensity.values.firstWhere(
    (d) => d.name == value,
    orElse: () => ChatDensity.cosy,
  );

  double get bubblePaddingY => switch (this) {
    ChatDensity.compact => 6,
    ChatDensity.cosy => 9,
    ChatDensity.spacious => 13,
  };

  double get bubblePaddingX => switch (this) {
    ChatDensity.compact => 10,
    ChatDensity.cosy => 12,
    ChatDensity.spacious => 14,
  };

  double get groupGap => switch (this) {
    ChatDensity.compact => 6,
    ChatDensity.cosy => 10,
    ChatDensity.spacious => 16,
  };

  double get stackGap => switch (this) {
    ChatDensity.compact => 1,
    ChatDensity.cosy => 2,
    ChatDensity.spacious => 4,
  };
}

@immutable
class ChatixTheme extends ThemeExtension<ChatixTheme> {
  const ChatixTheme({
    required this.outgoingGradient,
    required this.outgoingForeground,
    required this.incomingSurface,
    required this.incomingForeground,
    required this.incomingHairline,
    required this.bubbleRadius,
    required this.bubbleAnchorRadius,
    required this.density,
    required this.wallpaperSeed,
    required this.success,
    required this.danger,
    required this.attention,
  });

  final LinearGradient outgoingGradient;
  final Color outgoingForeground;

  final Color incomingSurface;
  final Color incomingForeground;

  final Color incomingHairline;

  final double bubbleRadius;

  final double bubbleAnchorRadius;

  final ChatDensity density;

  final Color wallpaperSeed;

  final Color success;
  final Color danger;
  final Color attention;

  static const Curve curve = Curves.easeOutCubic;
  static const Duration duration = Duration(milliseconds: 220);
  static const Duration fastDuration = Duration(milliseconds: 120);

  BorderRadius bubbleBorderRadius({required bool isMine}) {
    final soft = Radius.circular(bubbleRadius);
    final anchor = Radius.circular(bubbleAnchorRadius);
    return BorderRadius.only(
      topLeft: soft,
      topRight: soft,
      bottomLeft: isMine ? soft : anchor,
      bottomRight: isMine ? anchor : soft,
    );
  }

  BorderRadius stackedBorderRadius({
    required bool isMine,
    required bool isFirstInGroup,
    required bool isLastInGroup,
  }) {
    final soft = Radius.circular(bubbleRadius);
    final anchor = Radius.circular(bubbleAnchorRadius);
    final tight = Radius.circular(bubbleAnchorRadius);

    return BorderRadius.only(
      topLeft: isMine || isFirstInGroup ? soft : tight,
      topRight: !isMine || isFirstInGroup ? soft : tight,
      bottomLeft: isMine ? soft : (isLastInGroup ? anchor : tight),
      bottomRight: !isMine ? soft : (isLastInGroup ? anchor : tight),
    );
  }

  static ChatixTheme of(BuildContext context) =>
      Theme.of(context).extension<ChatixTheme>() ?? light(ChatDensity.cosy);

  static ChatixTheme light(ChatDensity density) => ChatixTheme(
    outgoingGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [ChatixPalette.violet, ChatixPalette.indigo],
    ),
    outgoingForeground: Colors.white,
    incomingSurface: Colors.white,
    incomingForeground: ChatixPalette.graphite900,
    incomingHairline: ChatixPalette.graphite200,
    bubbleRadius: 20,
    bubbleAnchorRadius: 6,
    density: density,
    wallpaperSeed: ChatixPalette.violet,
    success: ChatixPalette.mint,
    danger: ChatixPalette.coral,
    attention: ChatixPalette.amber,
  );

  static ChatixTheme dark(ChatDensity density) => ChatixTheme(
    outgoingGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF7B65FF), Color(0xFF4B36C9)],
    ),
    outgoingForeground: Colors.white,
    incomingSurface: ChatixPalette.graphite700,
    incomingForeground: ChatixPalette.graphite50,
    incomingHairline: Colors.transparent,
    bubbleRadius: 20,
    bubbleAnchorRadius: 6,
    density: density,
    wallpaperSeed: ChatixPalette.indigo,
    success: ChatixPalette.mint,
    danger: ChatixPalette.coral,
    attention: ChatixPalette.amber,
  );

  @override
  ChatixTheme copyWith({
    LinearGradient? outgoingGradient,
    Color? outgoingForeground,
    Color? incomingSurface,
    Color? incomingForeground,
    Color? incomingHairline,
    double? bubbleRadius,
    double? bubbleAnchorRadius,
    ChatDensity? density,
    Color? wallpaperSeed,
    Color? success,
    Color? danger,
    Color? attention,
  }) {
    return ChatixTheme(
      outgoingGradient: outgoingGradient ?? this.outgoingGradient,
      outgoingForeground: outgoingForeground ?? this.outgoingForeground,
      incomingSurface: incomingSurface ?? this.incomingSurface,
      incomingForeground: incomingForeground ?? this.incomingForeground,
      incomingHairline: incomingHairline ?? this.incomingHairline,
      bubbleRadius: bubbleRadius ?? this.bubbleRadius,
      bubbleAnchorRadius: bubbleAnchorRadius ?? this.bubbleAnchorRadius,
      density: density ?? this.density,
      wallpaperSeed: wallpaperSeed ?? this.wallpaperSeed,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      attention: attention ?? this.attention,
    );
  }

  @override
  ChatixTheme lerp(ThemeExtension<ChatixTheme>? other, double t) {
    if (other is! ChatixTheme) return this;
    return ChatixTheme(
      outgoingGradient:
          LinearGradient.lerp(outgoingGradient, other.outgoingGradient, t) ??
          outgoingGradient,
      outgoingForeground: Color.lerp(
        outgoingForeground,
        other.outgoingForeground,
        t,
      )!,
      incomingSurface: Color.lerp(incomingSurface, other.incomingSurface, t)!,
      incomingForeground: Color.lerp(
        incomingForeground,
        other.incomingForeground,
        t,
      )!,
      incomingHairline: Color.lerp(
        incomingHairline,
        other.incomingHairline,
        t,
      )!,
      bubbleRadius: bubbleRadius,
      bubbleAnchorRadius: bubbleAnchorRadius,
      density: t < 0.5 ? density : other.density,
      wallpaperSeed: Color.lerp(wallpaperSeed, other.wallpaperSeed, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      attention: Color.lerp(attention, other.attention, t)!,
    );
  }
}
