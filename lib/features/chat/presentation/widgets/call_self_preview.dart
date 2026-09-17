import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart'
    show VideoTrack, VideoTrackRenderer, VideoViewFit;

import 'package:chatix/gen/l10n/app_localizations.dart';

/// The local camera, floating over the call and draggable to any corner.
///
/// It snaps rather than staying wherever it is let go: a preview parked half
/// off the edge, or over the control bar, is worse than one that always sits
/// in a predictable place, and the snap is what makes flicking it out of the
/// way feel like a gesture instead of a drag.
class CallSelfPreview extends StatefulWidget {
  const CallSelfPreview({
    super.key,
    required this.track,
    this.width = 104,
    this.margin = const EdgeInsets.all(12),
    this.onTap,
  });

  final VideoTrack? track;

  final double width;

  /// Keeps the preview clear of the app bar and the control bar.
  final EdgeInsets margin;

  final VoidCallback? onTap;

  @override
  State<CallSelfPreview> createState() => _CallSelfPreviewState();
}

class _CallSelfPreviewState extends State<CallSelfPreview> {
  /// Which corner it snaps back to: -1/1 on each axis.
  Alignment _corner = Alignment.topRight;

  /// Where the finger has it right now, while a drag is in flight.
  Offset? _dragTopLeft;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final height = widget.width * 4 / 3;

    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Rect.fromLTRB(
          widget.margin.left,
          widget.margin.top,
          constraints.maxWidth - widget.margin.right - widget.width,
          constraints.maxHeight - widget.margin.bottom - height,
        );

        final resting = _restingPosition(area);
        final position = _dragTopLeft ?? resting;

        final preview = Semantics(
          label: l10n.callSelfPreview,
          hint: l10n.callSelfPreviewHint,
          button: widget.onTap != null,
          child: GestureDetector(
            onTap: widget.onTap,
            onPanStart: (_) => setState(() => _dragTopLeft = resting),
            onPanUpdate: (details) => setState(() {
              _dragTopLeft = _clamp(
                (_dragTopLeft ?? resting) + details.delta,
                area,
              );
            }),
            onPanEnd: (_) => setState(() {
              _corner = _nearestCorner(_dragTopLeft ?? resting, area);
              _dragTopLeft = null;
            }),
            child: _PreviewBody(
              track: widget.track,
              width: widget.width,
              height: height,
            ),
          ),
        );

        return Stack(
          children: [
            AnimatedPositioned(
              duration: _dragTopLeft == null
                  ? const Duration(milliseconds: 220)
                  : Duration.zero,
              curve: Curves.easeOutCubic,
              left: position.dx,
              top: position.dy,
              width: widget.width,
              height: height,
              child: preview,
            ),
          ],
        );
      },
    );
  }

  Offset _restingPosition(Rect area) {
    final left = _corner.x < 0 ? area.left : math.max(area.left, area.right);
    final top = _corner.y < 0 ? area.top : math.max(area.top, area.bottom);
    return Offset(left, top);
  }

  static Offset _clamp(Offset value, Rect area) => Offset(
    value.dx.clamp(area.left, math.max(area.left, area.right)),
    value.dy.clamp(area.top, math.max(area.top, area.bottom)),
  );

  static Alignment _nearestCorner(Offset position, Rect area) {
    final midX = (area.left + area.right) / 2;
    final midY = (area.top + area.bottom) / 2;
    return Alignment(position.dx < midX ? -1 : 1, position.dy < midY ? -1 : 1);
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({
    required this.track,
    required this.width,
    required this.height,
  });

  final VideoTrack? track;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final video = track;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: video == null
            ? Icon(Icons.videocam_off, color: scheme.onSurfaceVariant)
            : VideoTrackRenderer(video, fit: VideoViewFit.cover),
      ),
    );
  }
}
