import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// What a [ConnectionStrip] is saying.
enum ConnectionStripTone {
  /// Something is in progress and will probably finish on its own.
  working,

  /// Nothing can happen until a condition outside the app changes.
  waiting,
}

/// A hairline that says the app is not connected, without taking the screen
/// away from what it is for.
///
/// This is deliberately not a banner. A banner is for something the reader
/// has to act on, and a connection that is coming back by itself is not that
/// — it is a background fact that matters for about two seconds and then
/// stops mattering. So: one line of small text and a two-pixel rule, in the
/// muted surface rather than in an alarm colour, collapsing to nothing when
/// there is nothing to say.
///
/// The rule carries the state. A sweep travelling across it means work is
/// happening; a still rule means the app is waiting on something it cannot
/// influence. That distinction survives being glanced at, which the words
/// alone do not.
class ConnectionStrip extends StatefulWidget {
  const ConnectionStrip({
    super.key,
    required this.label,
    required this.tone,
    this.visible = true,
  });

  /// The one line of text. Kept short: this is a hairline, not a paragraph.
  final String label;

  final ConnectionStripTone tone;

  /// Whether there is anything to say at all. False collapses the strip to
  /// zero height, animated, so the content below settles rather than jumps.
  final bool visible;

  /// Height of the text row. The rule sits under it.
  static const double _rowHeight = 22;

  static const double _ruleHeight = 2;

  static const double height = _rowHeight + _ruleHeight;

  @override
  State<ConnectionStrip> createState() => _ConnectionStripState();
}

class _ConnectionStripState extends State<ConnectionStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSweep();
  }

  @override
  void didUpdateWidget(ConnectionStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSweep();
  }

  /// The sweep runs only while it means something — while the strip is up and
  /// the tone is [ConnectionStripTone.working] — and never when the reader
  /// has asked for less motion. An animation nobody can see is a wakeup a
  /// battery pays for.
  void _syncSweep() {
    final shouldRun =
        widget.visible &&
        widget.tone == ConnectionStripTone.working &&
        !MediaQuery.disableAnimationsOf(context);

    if (shouldRun && !_sweep.isAnimating) {
      _sweep.repeat();
    } else if (!shouldRun && _sweep.isAnimating) {
      _sweep
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final accent = switch (widget.tone) {
      ConnectionStripTone.working => scheme.primary,
      ConnectionStripTone.waiting => scheme.outline,
    };

    return AnimatedSize(
      duration: AppMotion.base,
      curve: AppMotion.curve,
      alignment: Alignment.topCenter,
      child: widget.visible
          // One node carrying one sentence: `container` makes it a node at
          // all, and `excludeSemantics` stops the label being read once as
          // the region and again as the text inside it.
          ? Semantics(
              container: true,
              liveRegion: true,
              excludeSemantics: true,
              label: widget.label,
              child: SizedBox(
                height: ConnectionStrip.height,
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Container(
                        alignment: Alignment.center,
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.6,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x3,
                        ),
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    _Rule(
                      animation: _sweep,
                      accent: accent,
                      track: scheme.surfaceContainerHighest,
                      sweeping: widget.tone == ConnectionStripTone.working,
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}

/// The two-pixel rule under the label.
class _Rule extends StatelessWidget {
  const _Rule({
    required this.animation,
    required this.accent,
    required this.track,
    required this.sweeping,
  });

  final Animation<double> animation;
  final Color accent;
  final Color track;
  final bool sweeping;

  @override
  Widget build(BuildContext context) {
    if (!sweeping) {
      return Container(
        height: ConnectionStrip._ruleHeight,
        width: double.infinity,
        color: accent.withValues(alpha: 0.5),
      );
    }

    return SizedBox(
      height: ConnectionStrip._ruleHeight,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) => CustomPaint(
          painter: _SweepPainter(
            progress: animation.value,
            accent: accent,
            track: track,
          ),
        ),
      ),
    );
  }
}

/// A band of accent travelling left to right along the rule.
///
/// Painted rather than assembled from a `LinearProgressIndicator` because
/// that one is three pixels of Material with its own track semantics and its
/// own idea of indeterminate; this needs to be exactly two pixels of the
/// app's own colour.
class _SweepPainter extends CustomPainter {
  const _SweepPainter({
    required this.progress,
    required this.accent,
    required this.track,
  });

  /// 0 to 1, where the head of the band is.
  final double progress;
  final Color accent;
  final Color track;

  /// How much of the width the band covers.
  static const double _bandWidth = 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = track.withValues(alpha: 0.5),
    );

    // The band starts fully off the left edge and ends fully off the right,
    // so it enters and leaves rather than appearing and vanishing.
    final band = size.width * _bandWidth;
    final travel = size.width + band;
    final head = -band + travel * progress;

    canvas.drawRect(
      Rect.fromLTWH(head, 0, band, size.height),
      Paint()
        ..shader = LinearGradient(
          colors: [
            accent.withValues(alpha: 0),
            accent,
            accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(head, 0, band, size.height)),
    );
  }

  @override
  bool shouldRepaint(_SweepPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.track != track;
}
