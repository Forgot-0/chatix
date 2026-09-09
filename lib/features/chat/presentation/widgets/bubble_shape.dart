import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';

/// The outline of a message bubble.
///
/// Three corners are soft; the fourth — the one on the author's side, at the
/// bottom of a run — is the *anchor*: pulled tight so the bubble points at
/// whoever sent it. Bubbles in the middle of a run meet on a smaller join
/// radius, which is what makes a run read as one block instead of a stack of
/// unrelated pills.
///
/// It is a [ShapeBorder], so the same outline can fill a [Material], stroke a
/// border and clip an attachment ([BubbleClipper]) without any of them
/// drifting apart.
@immutable
class BubbleShape extends ShapeBorder {
  const BubbleShape({
    required this.radius,
    required this.anchorRadius,
    required this.isOutgoing,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.joinRadius,
    this.side = BorderSide.none,
  });

  /// Takes its radii from the active theme.
  factory BubbleShape.of(
    BuildContext context, {
    required bool isOutgoing,
    bool isFirstInGroup = true,
    bool isLastInGroup = true,
    double? joinRadius,
    BorderSide side = BorderSide.none,
  }) {
    final chatix = ChatixTheme.of(context);
    return BubbleShape(
      radius: chatix.bubbleRadius,
      anchorRadius: chatix.bubbleAnchorRadius,
      isOutgoing: isOutgoing,
      isFirstInGroup: isFirstInGroup,
      isLastInGroup: isLastInGroup,
      joinRadius: joinRadius,
      side: side,
    );
  }

  /// The radius of a free corner.
  final double radius;

  /// The radius of the anchor corner — the tail of a run.
  final double anchorRadius;

  /// Which side the bubble is anchored to. Outgoing anchors right.
  final bool isOutgoing;

  final bool isFirstInGroup;
  final bool isLastInGroup;

  /// The radius where two bubbles of one run meet. Defaults to half of
  /// [radius]: softer than the anchor, tighter than a free corner.
  final double? joinRadius;

  final BorderSide side;

  double get _join => joinRadius ?? radius / 2;

  /// The four corners this bubble draws.
  ///
  /// The edge away from the author stays soft top to bottom — that silhouette
  /// is what the eye follows down a conversation.
  BorderRadius get borderRadius {
    final soft = Radius.circular(radius);
    final join = Radius.circular(_join);
    final anchor = Radius.circular(anchorRadius);

    final authorTop = isFirstInGroup ? soft : join;
    final authorBottom = isLastInGroup ? anchor : join;

    return BorderRadius.only(
      topLeft: isOutgoing ? soft : authorTop,
      topRight: isOutgoing ? authorTop : soft,
      bottomLeft: isOutgoing ? soft : authorBottom,
      bottomRight: isOutgoing ? authorBottom : soft,
    );
  }

  RRect _rrect(Rect rect, {double inset = 0}) {
    final rrect = borderRadius.toRRect(rect);
    return inset == 0 ? rrect : rrect.deflate(inset);
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect, inset: side.strokeInset));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawRRect(
      _rrect(rect, inset: side.strokeInset / 2),
      side.toPaint(),
    );
  }

  @override
  ShapeBorder scale(double t) => BubbleShape(
    radius: radius * t,
    anchorRadius: anchorRadius * t,
    isOutgoing: isOutgoing,
    isFirstInGroup: isFirstInGroup,
    isLastInGroup: isLastInGroup,
    joinRadius: _join * t,
    side: side.scale(t),
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is BubbleShape && a.isOutgoing == isOutgoing) {
      return BubbleShape(
        radius: _lerp(a.radius, radius, t),
        anchorRadius: _lerp(a.anchorRadius, anchorRadius, t),
        isOutgoing: isOutgoing,
        isFirstInGroup: t < 0.5 ? a.isFirstInGroup : isFirstInGroup,
        isLastInGroup: t < 0.5 ? a.isLastInGroup : isLastInGroup,
        joinRadius: _lerp(a._join, _join, t),
        side: BorderSide.lerp(a.side, side, t),
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is BubbleShape) return b.lerpFrom(this, t);
    return super.lerpTo(b, t);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BubbleShape &&
          other.radius == radius &&
          other.anchorRadius == anchorRadius &&
          other.isOutgoing == isOutgoing &&
          other.isFirstInGroup == isFirstInGroup &&
          other.isLastInGroup == isLastInGroup &&
          other._join == _join &&
          other.side == side;

  @override
  int get hashCode => Object.hash(
    radius,
    anchorRadius,
    isOutgoing,
    isFirstInGroup,
    isLastInGroup,
    _join,
    side,
  );
}

/// Clips a child — an image, a video still, a map preview — to the bubble it
/// sits in, so media never pokes out of the corners it shares with the fill.
class BubbleClipper extends CustomClipper<Path> {
  const BubbleClipper(this.shape);

  final BubbleShape shape;

  @override
  Path getClip(Size size) =>
      shape.getOuterPath(Rect.fromLTWH(0, 0, size.width, size.height));

  @override
  bool shouldReclip(covariant BubbleClipper oldClipper) =>
      oldClipper.shape != shape;
}
