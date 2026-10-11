import 'package:flutter/services.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// Where the viewer is in the chat's media, and where each way of moving
/// through it lands.
///
/// Pure index arithmetic, kept out of the screen so that a swipe, an arrow
/// key, a wheel notch, a thumbnail and a deletion all agree about what "next"
/// means — and so it can be tested without pumping a page view.
class MediaViewerCursor {
  const MediaViewerCursor({required this.index, required this.length})
    : assert(length >= 0),
      assert(length == 0 || (index >= 0 && index < length));

  /// The open item, oldest-first like the strip itself.
  final int index;

  /// How many items the strip has.
  final int length;

  bool get isEmpty => length == 0;

  bool get hasPrevious => index > 0;
  bool get hasNext => index < length - 1;

  /// Where the "3" of "3 of 12" comes from.
  int get position => index + 1;

  /// One step back (`-1`) or on (`+1`), or null at that end: the strip does
  /// not wrap round, because the far end of a chat's media is not "next" to
  /// its beginning.
  int? step(int direction) {
    if (isEmpty || direction == 0) return null;

    final target = index + direction.sign;
    if (target < 0 || target >= length) return null;
    return target;
  }

  /// Straight to [target], or null when it is not in the strip or is where
  /// the viewer already is.
  int? jumpTo(int target) {
    if (target < 0 || target >= length || target == index) return null;
    return target;
  }

  /// Where the viewer lands once the items at [removed] are gone — deleting
  /// a message takes its whole album with it — as an index into what is
  /// left, or null when nothing is.
  ///
  /// The item that came after the open one if there is any, and the one
  /// before it otherwise: the strip closes up under the reader the way a
  /// deleted message closes up in the feed.
  int? afterRemoval(Set<int> removed) {
    final remaining =
        length - removed.where((i) => i >= 0 && i < length).length;
    if (remaining <= 0) return null;

    // The first surviving item at or after the open one…
    for (var i = index; i < length; i++) {
      if (!removed.contains(i)) return _shiftedIndex(i, removed);
    }
    // …or, when everything from there on went, the last one before it.
    for (var i = index - 1; i >= 0; i--) {
      if (!removed.contains(i)) return _shiftedIndex(i, removed);
    }
    return null;
  }

  int _shiftedIndex(int i, Set<int> removed) =>
      i - removed.where((r) => r < i).length;
}

/// The keys the viewer answers to on a keyboard.
abstract final class MediaViewerKeys {
  /// `-1` for the previous item, `+1` for the next, null for any other key.
  static int? stepFor(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowLeft) return -1;
    if (key == LogicalKeyboardKey.arrowRight) return 1;
    return null;
  }

  static bool closes(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.escape;
}

/// Turns mouse-wheel travel into whole pages.
///
/// A notch is reported as 100 on one platform and a touchpad as a trickle
/// of 2s on another, so travel is added up until it makes a [step]. One
/// page per gesture: after turning, the wheel is ignored for [cooldown] —
/// as long as the page takes to turn — so the tail of a hard flick does not
/// race through the next ten photos.
class WheelPager {
  WheelPager({
    this.step = MediaViewerLayout.wheelStep,
    this.cooldown = AppMotion.slow,
  });

  final double step;
  final Duration cooldown;

  double _travel = 0;
  Duration? _quietUntil;

  /// Feeds one scroll event's [delta] at [timeStamp] (the event's own, so
  /// a test can drive it without a clock). Answers `+1` or `-1` when a page
  /// should turn, null otherwise.
  int? scroll(double delta, Duration timeStamp) {
    final quietUntil = _quietUntil;
    if (quietUntil != null && timeStamp < quietUntil) {
      _travel = 0;
      return null;
    }

    _travel += delta;
    if (_travel.abs() < step) return null;

    final direction = _travel > 0 ? 1 : -1;
    _travel = 0;
    _quietUntil = timeStamp + cooldown;
    return direction;
  }
}

/// The double tap's zoom.
abstract final class ViewerZoom {
  /// The transform that magnifies by [scale] about [focal]: the point under
  /// the finger stays under the finger, and since [focal] is inside the
  /// picture, the picture still covers the screen at every edge.
  static Matrix4 about(Offset focal, double scale) =>
      Matrix4.diagonal3Values(scale, scale, 1)
        ..setTranslationRaw(focal.dx * (1 - scale), focal.dy * (1 - scale), 0);

  static bool isZoomed(Matrix4 transform) =>
      transform.getMaxScaleOnAxis() > MediaViewerLayout.zoomedFrom;
}

/// How fast a video plays. Cycled by one button, like a voice message's.
enum VideoSpeed {
  half(0.5),
  normal(1),
  fast(1.5),
  fastest(2);

  const VideoSpeed(this.rate);

  final double rate;

  VideoSpeed get next =>
      VideoSpeed.values[(index + 1) % VideoSpeed.values.length];

  /// `0.5x`, `1x`, `1.5x`, `2x` — the same spelling as a voice message's.
  String get label =>
      rate == rate.roundToDouble() ? '${rate.toInt()}x' : '${rate.toString()}x';
}

/// What the viewer does with a video beyond playing it.
abstract final class ViewerVideoRules {
  /// A video shorter than this goes round and round, the way a moment is
  /// meant to be watched; a longer one stops at its end. Only in the viewer:
  /// nothing in the feed plays by itself.
  static const Duration loopShorterThan = Duration(seconds: 15);

  static bool loops(Duration duration) =>
      duration > Duration.zero && duration < loopShorterThan;

  /// Where a drag along the seek bar lands: [fraction] of [duration],
  /// clamped to the video.
  static Duration positionAt(double fraction, Duration duration) {
    final clamped = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return Duration(microseconds: (duration.inMicroseconds * clamped).round());
  }

  /// [position] as a share of [duration], for the seek bar.
  static double fractionOf(Duration position, Duration duration) {
    if (duration <= Duration.zero) return 0;
    return (position.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
  }
}
