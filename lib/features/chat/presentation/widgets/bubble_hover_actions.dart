import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/motion/motion.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The pill a pointer brings up beside a bubble: reply, and react.
///
/// The two things done to a message most often, one click away instead of
/// behind a right click — the desktop's answer to swiping a bubble and
/// double-tapping it. Either button is left out when it has nothing to do.
class BubbleHoverActions extends StatelessWidget {
  const BubbleHoverActions({super.key, this.onReply, this.onReact});

  final VoidCallback? onReply;

  /// Called with the button's centre on screen, where the reactions open.
  final ValueChanged<Offset>? onReact;

  bool get isEmpty => onReply == null && onReact == null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: context.motion(AppMotion.fast),
      curve: AppMotion.curve,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Material(
        color: scheme.surfaceContainerHigh,
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(DesktopSizes.hoverPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onReply != null)
                _HoverButton(
                  icon: Icons.reply_rounded,
                  tooltip: l10n.messageReply,
                  onPressed: (_) => onReply!(),
                ),
              if (onReact != null)
                _HoverButton(
                  icon: Icons.add_reaction_outlined,
                  tooltip: l10n.messageReact,
                  onPressed: onReact!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverButton extends StatelessWidget {
  const _HoverButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final ValueChanged<Offset> onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: DesktopSizes.hoverButton,
        height: DesktopSizes.hoverButton,
      ),
      iconSize: DesktopSizes.hoverIcon,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      icon: Icon(icon),
      onPressed: () {
        final box = context.findRenderObject() as RenderBox?;
        final centre = box == null
            ? Offset.zero
            : box.localToGlobal(box.size.center(Offset.zero));
        onPressed(centre);
      },
    );
  }
}

/// The two children of [BubbleHoverLayout].
enum BubbleHoverSlot { bubble, actions }

/// Lays [bubble] out exactly as an `Align` to its side would, and [actions]
/// beside it, level with its bottom edge.
///
/// The actions take no room of their own: the row is as tall as the bubble
/// with or without them, so a pointer passing over the feed never moves a
/// message. They sit in the space the row already has beside the bubble,
/// and on a pane too narrow for that they overlap the bubble's inner edge
/// rather than leave the row.
class BubbleHoverLayout
    extends SlottedMultiChildRenderObjectWidget<BubbleHoverSlot, RenderBox> {
  const BubbleHoverLayout({
    super.key,
    required this.isMine,
    required this.bubble,
    this.actions,
  });

  /// Outgoing bubbles hang off the right edge, and their actions come up on
  /// their left; incoming ones the other way round.
  final bool isMine;

  final Widget bubble;
  final Widget? actions;

  @override
  Iterable<BubbleHoverSlot> get slots => BubbleHoverSlot.values;

  @override
  Widget? childForSlot(BubbleHoverSlot slot) => switch (slot) {
    BubbleHoverSlot.bubble => bubble,
    BubbleHoverSlot.actions => actions,
  };

  @override
  RenderBubbleHoverLayout createRenderObject(BuildContext context) =>
      RenderBubbleHoverLayout(isMine: isMine);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderBubbleHoverLayout renderObject,
  ) {
    renderObject.isMine = isMine;
  }
}

class RenderBubbleHoverLayout extends RenderBox
    with SlottedContainerRenderObjectMixin<BubbleHoverSlot, RenderBox> {
  RenderBubbleHoverLayout({required bool isMine}) : _isMine = isMine;

  bool get isMine => _isMine;
  bool _isMine;
  set isMine(bool value) {
    if (_isMine == value) return;
    _isMine = value;
    markNeedsLayout();
  }

  RenderBox? get _bubble => childForSlot(BubbleHoverSlot.bubble);
  RenderBox? get _actions => childForSlot(BubbleHoverSlot.actions);

  @override
  Iterable<RenderBox> get children => [?_bubble, ?_actions];

  static BoxParentData _dataOf(RenderBox child) =>
      child.parentData! as BoxParentData;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  @override
  void performLayout() {
    final bubble = _bubble;
    if (bubble == null) {
      size = constraints.smallest;
      return;
    }

    bubble.layout(constraints.loosen(), parentUsesSize: true);
    size = _sizeFor(constraints, bubble.size);

    // Where `Align(alignment: centerLeft / centerRight)` would put it: in a
    // feed the row is as tall as the bubble, so that is simply the top.
    final bubbleOffset = (isMine ? Alignment.centerRight : Alignment.centerLeft)
        .alongOffset(
          Offset(
            size.width - bubble.size.width,
            size.height - bubble.size.height,
          ),
        );
    _dataOf(bubble).offset = bubbleOffset;

    final actions = _actions;
    if (actions == null) return;

    actions.layout(BoxConstraints.loose(size), parentUsesSize: true);
    final room = actions.size.width;

    final left = isMine
        ? math.max(0.0, bubbleOffset.dx - DesktopSizes.hoverGap - room)
        : math.min(
            bubbleOffset.dx + bubble.size.width + DesktopSizes.hoverGap,
            math.max(0.0, size.width - room),
          );
    final top =
        bubbleOffset.dy +
        math.max(0.0, bubble.size.height - actions.size.height);
    _dataOf(actions).offset = Offset(left, top);
  }

  /// `Align`'s own sizing: as big as the constraints allow wherever they
  /// are bounded, the bubble's size wherever they are not.
  static Size _sizeFor(BoxConstraints constraints, Size bubble) =>
      constraints.constrain(
        Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : bubble.width,
          constraints.hasBoundedHeight ? constraints.maxHeight : bubble.height,
        ),
      );

  @override
  double computeMinIntrinsicWidth(double height) =>
      _bubble?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _bubble?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _bubble?.getMinIntrinsicHeight(width) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _bubble?.getMaxIntrinsicHeight(width) ?? 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final bubble = _bubble;
    if (bubble == null) return constraints.smallest;

    return _sizeFor(constraints, bubble.getDryLayout(constraints.loosen()));
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final bubble = _bubble;
    if (bubble == null) return null;
    final distance = bubble.getDistanceToActualBaseline(baseline);
    return distance == null ? null : distance + _dataOf(bubble).offset.dy;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(child, offset + _dataOf(child).offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // The pill is drawn over the bubble when the two overlap, so it is
    // asked first.
    for (final child in [?_actions, ?_bubble]) {
      final hit = result.addWithPaintOffset(
        offset: _dataOf(child).offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
