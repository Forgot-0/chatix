import 'package:flutter/widgets.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/utils/media_box_size.dart';

/// The size of the feed's viewport, published to every row inside it.
///
/// Bubbles are sized against the feed, not against the window: in a
/// two-pane layout the feed is only part of the window, and a bubble that
/// measured the window would be sized for a conversation three times wider
/// than the one it is in. The feed measures itself once and every bubble,
/// every message still going out and the copy the context menu lifts read
/// the same two numbers from here — which is what makes them the same size.
class ChatFeedMetrics extends InheritedWidget {
  const ChatFeedMetrics({
    super.key,
    required this.width,
    required this.height,
    required super.child,
  });

  /// The width rows are laid out in — the feed's column, which on a very
  /// wide pane is narrower than the pane (see [ChatLayout.columnWidthFor]).
  final double width;

  /// The height of the feed's viewport.
  final double height;

  /// What a bubble assumes when it is drawn outside any feed — a preview,
  /// a sheet, a bare test harness: a phone-sized conversation.
  static const ChatFeedMetrics _fallback = ChatFeedMetrics(
    width: 390,
    height: 640,
    child: SizedBox.shrink(),
  );

  static ChatFeedMetrics of(BuildContext context) =>
      maybeOf(context) ?? _fallback;

  static ChatFeedMetrics? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChatFeedMetrics>();

  /// The widest a text bubble may be.
  double get bubbleMaxWidth => ChatLayout.bubbleMaxWidthFor(width);

  /// The widest a photo, a video or an album may be.
  double get mediaMaxWidth => ChatLayout.mediaMaxWidthFor(width);

  /// The tallest a photo, a video or an album may be.
  double get mediaMaxHeight => ChatLayout.mediaMaxHeightFor(height);

  /// The box for media of [ratios], no wider than [available] when the row
  /// has less room than the feed would give it — a checkbox in selection
  /// mode, an avatar gutter.
  Size mediaSizeFor(List<double?> ratios, {double? available}) =>
      MediaBoxSize.forMedia(
        ratios,
        maxWidth: available == null || available >= mediaMaxWidth
            ? mediaMaxWidth
            : available,
        maxHeight: mediaMaxHeight,
      );

  /// The same numbers, republished below [child] — for a copy of a bubble
  /// drawn somewhere this feed is not an ancestor, like the context menu's
  /// route.
  Widget wrap(Widget child) =>
      ChatFeedMetrics(width: width, height: height, child: child);

  @override
  bool updateShouldNotify(ChatFeedMetrics oldWidget) =>
      width != oldWidget.width || height != oldWidget.height;
}

/// Holds its child to the conversation's column: the whole width on
/// anything up to [ChatLayout.columnFrom], a centred [ChatLayout.columnMaxWidth]
/// beyond it.
///
/// For the bars under the feed — the composer and what stacks on it — so
/// that what is typed lines up with the messages it lands among. Measures
/// the space it is given, never the window.
class ChatColumn extends StatelessWidget {
  const ChatColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = ChatLayout.columnWidthFor(constraints.maxWidth);
        if (width >= constraints.maxWidth) return child;

        return Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: SizedBox(width: width, child: child),
        );
      },
    );
  }
}
