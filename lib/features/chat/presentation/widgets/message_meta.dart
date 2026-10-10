import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/widgets/status_ticks.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The time, the "edited" mark and the ticks — and the way into the details.
///
/// It does not take a line of its own. [MessageMetaLayout] puts it on the
/// last line of whatever ends the bubble — the text, a document's size, the
/// row of reactions — at the bubble's far edge, so a short "ok" stays one
/// line tall. A last line too long to share it is followed by the time on a
/// line of its own, still at the edge.
///
/// Text needs nothing measured in advance: the layout asks the paragraph
/// where its last line ends. A row that is not text leaves a
/// [MessageMetaSpacer] instead, and that has to be the right size before
/// anything is laid out — so the row is measured with [measure], from the
/// same styles it is drawn with.
class MessageMeta extends StatelessWidget {
  const MessageMeta({
    super.key,
    required this.label,
    required this.color,
    this.isEdited = false,
    this.deliveryStatus,
    this.speakLabel = false,
    this.onTap,
  });

  /// The time, as the reader's clock writes it — or, on a message still
  /// going out, what is holding it up.
  final String label;

  final Color color;

  final bool isEdited;

  /// Ticks for your own message; null on anybody else's.
  final MessageDeliveryStatus? deliveryStatus;

  /// Whether a screen reader should read [label]. The time is already in
  /// the bubble's own header, so reading it again here would make every
  /// message say its time twice.
  final bool speakLabel;

  final VoidCallback? onTap;

  /// The size the row will be drawn at in [context], to the fraction of a
  /// pixel: the spacer reserves exactly this, and a spacer that is short by
  /// one glyph would let the time sit on the last word.
  static Size measure(
    BuildContext context, {
    required String label,
    bool isEdited = false,
    bool hasTicks = false,
  }) {
    final styles = _MetaStyles.of(context, color: null);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);

    Size measureText(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        locale: locale,
        textHeightBehavior: styles.heightBehavior,
        maxLines: 1,
      )..layout();
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final time = measureText(label, styles.label);
    var width = time.width;
    var height = time.height;

    if (isEdited) {
      final edited = measureText(
        AppLocalizations.of(context).messageEdited,
        styles.edited,
      );
      width += edited.width + ChatLayout.metaItemGap;
      height = math.max(height, edited.height);
    }

    if (hasTicks) {
      // An icon follows the text scale only where the icon theme asks it
      // to, which is how `Icon` itself decides.
      final tick = (IconTheme.of(context).applyTextScaling ?? false)
          ? scaler.scale(ChatLayout.metaTickSize)
          : ChatLayout.metaTickSize;
      width += (label.isEmpty ? 0 : ChatLayout.metaItemGap) + tick;
      height = math.max(height, tick);
    }

    return Size(width, height);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final styles = _MetaStyles.of(context, color: color);

    // The ticks and the italic "edited" are shapes; this is the sentence
    // they stand for. Joined rather than nested so a bubble with neither
    // still reads as a plain details button.
    final spoken = <String>[
      if (speakLabel) label,
      if (isEdited) l10n.messageEdited,
      if (deliveryStatus != null)
        switch (deliveryStatus!) {
          MessageDeliveryStatus.sending => l10n.messageSending,
          MessageDeliveryStatus.sent => l10n.messageSent,
          MessageDeliveryStatus.read => l10n.messageRead,
        },
      if (onTap != null) l10n.messageDetails,
    ];

    return Semantics(
      button: onTap != null,
      label: spoken.isEmpty ? null : spoken.join(', '),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "edited 09:02", as the clock is what the ticks belong to.
              if (isEdited) ...[
                Text(
                  l10n.messageEdited,
                  maxLines: 1,
                  softWrap: false,
                  style: styles.edited,
                  textHeightBehavior: styles.heightBehavior,
                ),
                const SizedBox(width: ChatLayout.metaItemGap),
              ],
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: styles.label,
                textHeightBehavior: styles.heightBehavior,
              ),
              if (deliveryStatus != null) ...[
                // A message still going out has no time yet; the clock
                // tick stands alone.
                if (label.isNotEmpty)
                  const SizedBox(width: ChatLayout.metaItemGap),
                StatusTicks(
                  status: deliveryStatus!,
                  color: color,
                  // Mint on an outgoing accent is 1–2.7:1. The second tick
                  // says "read" by its shape; the colour has to say "meta".
                  readColor: color,
                  size: ChatLayout.metaTickSize,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The styles the row is drawn in, shared by [MessageMeta.build] and
/// [MessageMeta.measure] so the two can never drift apart.
class _MetaStyles {
  const _MetaStyles(this.label, this.edited, this.heightBehavior);

  factory _MetaStyles.of(BuildContext context, {required Color? color}) {
    // What `Text` itself resolves: the ambient style under the theme's,
    // and bold throughout when the platform asks for bold text.
    final ambient = DefaultTextStyle.of(context);
    var base = ambient.style
        .merge(Theme.of(context).textTheme.labelSmall)
        .copyWith(color: color);
    if (MediaQuery.boldTextOf(context)) {
      base = base.merge(const TextStyle(fontWeight: FontWeight.bold));
    }

    return _MetaStyles(
      // Fixed-width digits: "11:11" and "10:08" take the same room, so a
      // column of clocks lines up and an edit does not shift its row.
      base.copyWith(fontFeatures: AppTypography.tabularFigures),
      base.copyWith(fontStyle: FontStyle.italic),
      ambient.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context) ??
          const TextHeightBehavior(),
    );
  }

  final TextStyle label;
  final TextStyle edited;
  final TextHeightBehavior heightBehavior;
}

/// The room a [MessageMeta] needs at the end of a row that is not text —
/// the reactions, a voice message's length: the row itself and the gap
/// that keeps it off whatever comes before.
@immutable
class MessageMetaReserve {
  const MessageMetaReserve(this.meta);

  /// Measures [MessageMeta] for [label] in [context].
  factory MessageMetaReserve.of(
    BuildContext context, {
    required String label,
    bool isEdited = false,
    bool hasTicks = false,
  }) => MessageMetaReserve(
    MessageMeta.measure(
      context,
      label: label,
      isEdited: isEdited,
      hasTicks: hasTicks,
    ),
  );

  /// The row, as [MessageMeta.measure] put it.
  final Size meta;

  /// The spacer: the row plus the gap before it.
  Size get size => Size(meta.width + ChatLayout.metaGap, meta.height);

  /// The spacer, as the last child of the row.
  Widget box({bool alignToEnd = true}) =>
      MessageMetaSpacer(size: size, alignToEnd: alignToEnd);

  @override
  bool operator ==(Object other) =>
      other is MessageMetaReserve && other.meta == meta;

  @override
  int get hashCode => meta.hashCode;
}

/// Marks the text whose last line the time shares.
///
/// Nothing is added to the text itself — no invisible character, no
/// placeholder — so the paragraph reads, copies, announces and matches in a
/// test exactly as it was written. [MessageMetaLayout] asks the paragraph
/// inside where its last line ends and decides from that: beside it, if the
/// bubble has the room, or on a line of its own below.
class MessageMetaAnchor extends SingleChildRenderObjectWidget {
  const MessageMetaAnchor({super.key, required Widget super.child});

  @override
  RenderMessageMetaAnchor createRenderObject(BuildContext context) =>
      RenderMessageMetaAnchor();
}

class RenderMessageMetaAnchor extends RenderProxyBox {
  /// The paragraph this anchor marks: the first one inside it.
  RenderParagraph? get paragraph {
    RenderParagraph? found;
    void visit(RenderObject child) {
      if (found != null) return;
      if (child is RenderParagraph) {
        found = child;
        return;
      }
      child.visitChildren(visit);
    }

    final self = child;
    if (self != null) visit(self);
    return found;
  }
}

/// Empty room for the time, left at the end of a row that is not text.
///
/// Paints nothing and says nothing; [MessageMetaLayout] finds it after
/// layout and puts the [MessageMeta] on its line.
class MessageMetaSpacer extends LeafRenderObjectWidget {
  const MessageMetaSpacer({
    super.key,
    required this.size,
    this.alignToEnd = true,
  });

  final Size size;

  /// Whether the time goes to the far edge of the bubble on this line, or
  /// exactly where the spacer is. The far edge is right for reactions; a
  /// voice message wants it under its waveform instead, clear of the speed
  /// control on the right.
  final bool alignToEnd;

  @override
  RenderMessageMetaSpacer createRenderObject(BuildContext context) =>
      RenderMessageMetaSpacer(size: size, alignToEnd: alignToEnd);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMessageMetaSpacer renderObject,
  ) {
    renderObject
      ..spacerSize = size
      ..alignToEnd = alignToEnd;
  }
}

class RenderMessageMetaSpacer extends RenderBox {
  RenderMessageMetaSpacer({required Size size, required bool alignToEnd})
    : _spacerSize = size,
      _alignToEnd = alignToEnd;

  Size get spacerSize => _spacerSize;
  Size _spacerSize;
  set spacerSize(Size value) {
    if (value == _spacerSize) return;
    _spacerSize = value;
    markNeedsLayout();
  }

  bool get alignToEnd => _alignToEnd;
  bool _alignToEnd;
  set alignToEnd(bool value) {
    if (value == _alignToEnd) return;
    _alignToEnd = value;
    // Only where the meta goes changes, which the layout above decides.
    parent?.markNeedsLayout();
  }

  /// The size this spacer was last laid out at, for [RenderMessageMetaLayout]
  /// to read. Only a parent may read a box's `size` during layout, and the
  /// layout that places the meta is further up than that.
  Size? get slotSize => _slotSize;
  Size? _slotSize;

  @override
  double computeMinIntrinsicWidth(double height) => _spacerSize.width;

  @override
  double computeMaxIntrinsicWidth(double height) => _spacerSize.width;

  @override
  double computeMinIntrinsicHeight(double width) => _spacerSize.height;

  @override
  double computeMaxIntrinsicHeight(double width) => _spacerSize.height;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.constrain(_spacerSize);

  @override
  void performLayout() {
    final laidOut = constraints.constrain(_spacerSize);
    size = laidOut;
    _slotSize = Size.copy(laidOut);
  }
}

/// Lays a [MessageMeta] on the last line of what ends a bubble.
///
/// The content is laid out as if the meta were not there. Then the last
/// [MessageMetaAnchor] or [MessageMetaSpacer] in it decides where the meta
/// goes:
///
/// * after text, at the far edge of the bubble on the text's last line, if
///   that line leaves room for it within the widest the bubble may be —
///   the bubble grows to fit if it has to, which is what keeps "ok" one
///   line tall; otherwise on a line of its own just below, at the same edge;
/// * over a spacer, on the spacer's line, which the spacer has already made
///   room on;
/// * with neither (a video note), on a line of its own below everything.
class MessageMetaLayout extends MultiChildRenderObjectWidget {
  MessageMetaLayout({super.key, required Widget content, required Widget meta})
    : super(children: [content, meta]);

  @override
  RenderMessageMetaLayout createRenderObject(BuildContext context) =>
      RenderMessageMetaLayout(textDirection: Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMessageMetaLayout renderObject,
  ) {
    renderObject.textDirection = Directionality.of(context);
  }
}

class _MetaLayoutParentData extends ContainerBoxParentData<RenderBox> {}

class RenderMessageMetaLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MetaLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MetaLayoutParentData> {
  RenderMessageMetaLayout({required TextDirection textDirection})
    : _textDirection = textDirection;

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _content => firstChild!;
  RenderBox get _meta => lastChild!;

  bool get _isLtr => _textDirection == TextDirection.ltr;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MetaLayoutParentData) {
      child.parentData = _MetaLayoutParentData();
    }
  }

  /// The last anchor or spacer in the content, in paint order — the one at
  /// the bubble's foot.
  RenderBox? _findHost() {
    RenderBox? found;
    void visit(RenderObject child) {
      if (child is RenderMessageMetaSpacer ||
          child is RenderMessageMetaAnchor) {
        found = child as RenderBox;
        return;
      }
      child.visitChildren(visit);
    }

    visit(_content);
    return found;
  }

  // Intrinsics and dry layout cannot ask a paragraph where its last line
  // ends, so they answer for the roomiest case: the meta on a line of its
  // own. Nothing sizes a bubble by them; they only have to be safe.

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _content.getMinIntrinsicWidth(height),
    _meta.getMinIntrinsicWidth(double.infinity),
  );

  @override
  double computeMaxIntrinsicWidth(double height) => math.max(
    _content.getMaxIntrinsicWidth(height),
    _meta.getMaxIntrinsicWidth(double.infinity),
  );

  @override
  double computeMinIntrinsicHeight(double width) =>
      _content.getMinIntrinsicHeight(width) +
      _meta.getMinIntrinsicHeight(double.infinity);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _content.getMaxIntrinsicHeight(width) +
      _meta.getMaxIntrinsicHeight(double.infinity);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final content = _content.getDryLayout(constraints);
    final meta = _meta.getDryLayout(
      BoxConstraints(maxWidth: constraints.maxWidth),
    );
    return constraints.constrain(
      Size(math.max(content.width, meta.width), content.height + meta.height),
    );
  }

  @override
  void performLayout() {
    final content = _content;
    final meta = _meta;

    content.layout(constraints, parentUsesSize: true);
    meta.layout(
      BoxConstraints(maxWidth: constraints.maxWidth),
      parentUsesSize: true,
    );

    final contentSize = content.size;
    final metaSize = meta.size;

    final host = _findHost();
    final placement = switch (host) {
      final RenderMessageMetaAnchor anchor => _afterText(
        anchor,
        contentSize,
        metaSize,
      ),
      final RenderMessageMetaSpacer spacer => _overSpacer(
        spacer,
        contentSize,
        metaSize,
      ),
      _ => null,
    };

    final (width, height, metaTop, metaStart) =
        placement ??
        (
          math.max(contentSize.width, metaSize.width),
          contentSize.height + metaSize.height,
          contentSize.height,
          null,
        );

    final contentData = content.parentData! as _MetaLayoutParentData;
    final metaData = meta.parentData! as _MetaLayoutParentData;

    // Content keeps to the start edge; whatever the bubble grew by opens up
    // at the end, which is where the meta is.
    contentData.offset = Offset(_isLtr ? 0 : width - contentSize.width, 0);
    metaData.offset = Offset(
      metaStart ?? (_isLtr ? width - metaSize.width : 0),
      metaTop,
    );
    size = constraints.constrain(Size(width, height));
  }

  /// Width, height, the meta's top, and its start where it is not the end
  /// edge — for a meta that follows [anchor]'s last line.
  (double, double, double, double?)? _afterText(
    RenderMessageMetaAnchor anchor,
    Size content,
    Size meta,
  ) {
    final paragraph = anchor.paragraph;
    if (paragraph == null || !paragraph.hasSize) return null;

    final end = TextPosition(offset: paragraph.text.toPlainText().length);
    final caret = paragraph.getOffsetForCaret(end, Rect.zero);
    final lineHeight = paragraph.getFullHeightForCaret(end);

    final toContent = paragraph.getTransformTo(_content);
    final lineEnd = MatrixUtils.transformPoint(toContent, caret);
    final lineBottom = MatrixUtils.transformPoint(
      toContent,
      caret + Offset(0, lineHeight),
    ).dy;

    // How far the last line reaches from the start edge, and how far it
    // would reach with the meta after it.
    final reach = _isLtr ? lineEnd.dx : content.width - lineEnd.dx;
    final withMeta = reach + ChatLayout.metaGap + meta.width;

    if (withMeta <= constraints.maxWidth) {
      return (
        math.max(content.width, withMeta),
        math.max(content.height, lineBottom),
        lineBottom - meta.height,
        null,
      );
    }

    return (
      math.max(content.width, meta.width),
      math.max(content.height, lineBottom + meta.height),
      lineBottom,
      null,
    );
  }

  /// The same, for a meta laid over [spacer], which has already made room.
  (double, double, double, double?)? _overSpacer(
    RenderMessageMetaSpacer spacer,
    Size content,
    Size meta,
  ) {
    final slotSize = spacer.slotSize;
    if (slotSize == null) return null;

    final slot = MatrixUtils.transformRect(
      spacer.getTransformTo(_content),
      Offset.zero & slotSize,
    );

    final double? start;
    if (spacer.alignToEnd) {
      start = null;
    } else {
      // The gap leads the spacer, so the row sits at its trailing end.
      start = _isLtr ? slot.right - meta.width : slot.left;
    }

    return (content.width, content.height, slot.bottom - meta.height, start);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
