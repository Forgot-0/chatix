import 'package:equatable/equatable.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The span of list indices actually painted inside the viewport.
///
/// [first] is the smallest index on screen and [last] the largest. In a
/// reverse list that reads bottom-to-top: [first] is the newest row visible,
/// [last] the oldest.
class FeedVisibleRange extends Equatable {
  const FeedVisibleRange({required this.first, required this.last});

  final int first;
  final int last;

  bool contains(int index) => index >= first && index <= last;

  @override
  List<Object?> get props => [first, last];
}

/// Asks the laid-out list which of its rows the reader can see.
///
/// Two things in this screen need that answer and neither can guess it:
/// the read cursor, which may only report what was really on screen, and the
/// sticky date header, which names the day of the topmost row. Rows have
/// variable height, so there is no arithmetic that turns a scroll offset into
/// an index — the sliver has to be asked.
///
/// The cost is a walk over the built children, which is the viewport plus its
/// cache extent, not the whole list. Safe to call once per scroll frame even
/// with a thousand messages loaded.
abstract final class FeedViewportProbe {
  static FeedVisibleRange? of(BuildContext? listContext) {
    final root = listContext?.findRenderObject();
    if (root == null) return null;

    final sliver = findSliver(root);
    if (sliver == null) return null;

    return rangeOf(sliver);
  }

  /// The first multi-box sliver at or under [root]. A list's own context sits
  /// above several render objects it does not own (the gesture handler, the
  /// viewport), so the sliver is found by descent rather than by cast.
  static RenderSliverMultiBoxAdaptor? findSliver(RenderObject root) {
    if (root is RenderSliverMultiBoxAdaptor) return root;

    RenderSliverMultiBoxAdaptor? found;
    root.visitChildren((child) {
      found ??= findSliver(child);
    });
    return found;
  }

  /// The laid-out box for one list index, or null when that row is not built.
  ///
  /// What scrolling to a message needs: with the box in hand the viewport can
  /// be asked for the exact offset that reveals it, which beats guessing from
  /// row heights that vary with every attachment.
  static RenderBox? childAt(BuildContext? listContext, int index) {
    final root = listContext?.findRenderObject();
    if (root == null) return null;

    final sliver = findSliver(root);
    if (sliver == null || sliver.geometry == null) return null;

    for (
      RenderBox? child = sliver.firstChild;
      child != null;
      child = sliver.childAfter(child)
    ) {
      final parentData = child.parentData;
      if (parentData is! SliverMultiBoxAdaptorParentData) continue;
      if (parentData.index == index) return child;
    }
    return null;
  }

  static FeedVisibleRange? rangeOf(RenderSliverMultiBoxAdaptor sliver) {
    // Null geometry means the sliver has never been laid out, and reading its
    // constraints then throws rather than returning something stale.
    if (sliver.geometry == null) return null;

    final constraints = sliver.constraints;
    final start = constraints.scrollOffset;
    final end = start + constraints.remainingPaintExtent;
    final isVertical = constraints.axis == Axis.vertical;

    int? first;
    int? last;

    for (
      RenderBox? child = sliver.firstChild;
      child != null;
      child = sliver.childAfter(child)
    ) {
      final parentData = child.parentData;
      if (parentData is! SliverMultiBoxAdaptorParentData) continue;

      final offset = parentData.layoutOffset;
      final index = parentData.index;
      if (offset == null || index == null || !child.hasSize) continue;

      final extent = isVertical ? child.size.height : child.size.width;

      // Rows kept alive off-screen or sitting in the cache extent are built
      // but not seen, and reporting them as read would be a lie.
      if (offset + extent <= start || offset >= end) continue;

      if (first == null || index < first) first = index;
      if (last == null || index > last) last = index;
    }

    if (first == null || last == null) return null;
    return FeedVisibleRange(first: first, last: last);
  }
}
