import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/utils/album_layout.dart';

/// The box a photo, a video or an album is drawn in inside the feed.
///
/// One rule for every shape: the picture is fitted inside the bounds with
/// its proportions kept, and only when that would leave it thinner than the
/// minimums is it cropped instead — cover, the way the tile already paints
/// it — so a panorama becomes a wide strip rather than a hairline and a
/// screenshot a tall card rather than a needle. The box never leaves the
/// bounds either way.
///
/// Pure, so the sizes a bubble will take can be tested without a widget —
/// and so the feed, the bubble on its way out and the copy the context menu
/// lifts all land on the same numbers.
abstract final class MediaBoxSize {
  /// Width ÷ height assumed for a picture the server has not measured yet.
  ///
  /// Square: whatever the real shape turns out to be, a square is the
  /// smallest jump to it.
  static const double unknownRatio = 1;

  /// Fits a picture of [ratio] (width ÷ height) inside [maxWidth] ×
  /// [maxHeight], keeping its proportions until either side would fall
  /// under [minWidth] or [minHeight].
  ///
  /// A null, zero or non-finite ratio is drawn as [unknownRatio].
  static Size fit({
    required double? ratio,
    required double maxWidth,
    required double maxHeight,
    double minWidth = ChatLayout.mediaMinWidth,
    double minHeight = ChatLayout.mediaMinHeight,
  }) {
    final shape = ratio == null || !ratio.isFinite || ratio <= 0
        ? unknownRatio
        : ratio;

    // The minimums give way to the maximums: in a feed narrower than the
    // minimum width the picture still has to fit.
    final floorWidth = math.min(minWidth, maxWidth);
    final floorHeight = math.min(minHeight, maxHeight);

    var width = maxWidth;
    var height = width / shape;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * shape;
    }

    // Past the minimums the proportions stop being kept: the side that ran
    // short is held at the minimum, the other one stays where fitting put
    // it, and the picture is cropped to the difference.
    return Size(math.max(width, floorWidth), math.max(height, floorHeight));
  }

  /// The box for everything a message shows as one picture: a lone photo or
  /// video at its own shape, several of them as the album [AlbumLayout]
  /// arranges, scaled as a whole.
  ///
  /// [ratios] are width ÷ height per item, in message order, null where an
  /// item is not measured yet. Empty gives [Size.zero].
  static Size forMedia(
    List<double?> ratios, {
    required double maxWidth,
    required double maxHeight,
    double minWidth = ChatLayout.mediaMinWidth,
    double minHeight = ChatLayout.mediaMinHeight,
  }) {
    if (ratios.isEmpty) return Size.zero;

    return fit(
      // A lone picture is sized by its own shape. The layout's single-photo
      // ratio is clamped for hosts with no height to fit into; here the
      // height bound does that job, and does it per feed.
      ratio: ratios.length == 1
          ? ratios.single
          : AlbumLayout.of(ratios).aspectRatio,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      minWidth: minWidth,
      minHeight: minHeight,
    );
  }
}
