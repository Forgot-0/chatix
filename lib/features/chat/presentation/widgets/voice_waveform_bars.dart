import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A voice message drawn as bars, with the part already played filled in.
///
/// One painter for both places a waveform appears: the bubble, where the
/// bars are the whole recording and [progress] is how far through it is,
/// and the composer, where they are the last few seconds off the microphone
/// and [progress] is 1 — everything heard so far is, by definition, played.
class VoiceWaveformBars extends StatelessWidget {
  const VoiceWaveformBars({
    super.key,
    required this.bars,
    required this.progress,
    required this.playedColor,
    required this.remainingColor,
    this.barWidth = 3,
    this.gap = 2,
    this.alignEnd = false,
    this.onSeek,
    this.semanticsLabel,
  });

  /// Heights in `[0, 1]`, oldest first.
  final List<double> bars;

  /// How much of it is behind the playhead, `[0, 1]`.
  final double progress;

  final Color playedColor;
  final Color remainingColor;

  final double barWidth;
  final double gap;

  /// Draws from the right edge instead of the left — what a live recording
  /// wants, where the newest bar should stay put and the old ones scroll off.
  final bool alignEnd;

  /// Where a tap landed, as a fraction of the width. Null makes the
  /// waveform a picture rather than a control.
  final void Function(double fraction)? onSeek;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final painter = CustomPaint(
      painter: _WaveformPainter(
        bars: bars,
        progress: progress.clamp(0.0, 1.0),
        playedColor: playedColor,
        remainingColor: remainingColor,
        barWidth: barWidth,
        gap: gap,
        alignEnd: alignEnd,
      ),
      size: Size.infinite,
    );

    if (onSeek == null) {
      return semanticsLabel == null
          ? painter
          : Semantics(label: semanticsLabel, child: painter);
    }

    return Semantics(
      label: semanticsLabel,
      slider: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Both, so a tap scrubs and a drag keeps scrubbing — a thumb that
        // moves a pixel while tapping is still a tap as far as intent goes.
        onTapDown: (details) => _seek(context, details.localPosition.dx),
        onHorizontalDragUpdate: (details) =>
            _seek(context, details.localPosition.dx),
        child: painter,
      ),
    );
  }

  void _seek(BuildContext context, double dx) {
    final box = context.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 0;
    if (width <= 0) return;

    onSeek!((dx / width).clamp(0.0, 1.0));
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.playedColor,
    required this.remainingColor,
    required this.barWidth,
    required this.gap,
    required this.alignEnd,
  });

  final List<double> bars;
  final double progress;
  final Color playedColor;
  final Color remainingColor;
  final double barWidth;
  final double gap;
  final bool alignEnd;

  /// The shortest a bar is drawn, so silence is a dotted line rather than a
  /// gap in the middle of the message.
  static const double _minHeight = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || size.width <= 0) return;

    final step = barWidth + gap;
    final fits = (size.width / step).floor();
    if (fits <= 0) return;

    // More bars than room: drop the oldest. Fewer: line them up against
    // whichever edge the caller asked for.
    final visible = bars.length > fits
        ? bars.sublist(bars.length - fits)
        : bars;
    final offset = alignEnd ? size.width - visible.length * step + gap : 0.0;

    final playedTo = visible.length * progress;
    final radius = Radius.circular(barWidth / 2);

    for (var i = 0; i < visible.length; i++) {
      final height = (_minHeight + (size.height - _minHeight) * visible[i])
          .clamp(_minHeight, size.height);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            offset + i * step,
            (size.height - height) / 2,
            barWidth,
            height,
          ),
          radius,
        ),
        Paint()..color = i < playedTo ? playedColor : remainingColor,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.playedColor != playedColor ||
      old.remainingColor != remainingColor ||
      old.barWidth != barWidth ||
      old.gap != gap ||
      old.alignEnd != alignEnd ||
      !listEquals(old.bars, bars);
}
