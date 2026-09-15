import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/progress_ring.dart';
import 'package:chatix/features/chat/data/datasources/video_note_recorder.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The live camera, in the shape the note will be sent in.
///
/// The circle is the point: a video note is round everywhere it is ever
/// shown, so framing one in a rectangle and hoping for the best is how you
/// end up with a chin in the corner. The ring around it is the sixty seconds
/// the API allows (api-docs §5.5), running down as it records.
///
/// Shared by the sheet and by the composer's hold-to-record, which frame the
/// same camera at two sizes and must not drift apart while doing it.
class VideoNoteLensView extends StatelessWidget {
  const VideoNoteLensView({
    super.key,
    required this.recorder,
    required this.diameter,
    required this.progress,
    required this.isRecording,
    this.onSwitchLens,
  });

  final VideoNoteRecorder recorder;
  final double diameter;

  /// How much of the sixty seconds is spent, `[0, 1]`.
  final double progress;

  final bool isRecording;

  /// Turns the camera around. Null where there is only one camera, or while
  /// a take is open — no platform can swap the sensor under a running
  /// encoder without ending the file, so the gesture is withdrawn rather
  /// than half-kept.
  final VoidCallback? onSwitchLens;

  /// How big the flip glyph is drawn, and below which diameter it is left
  /// off entirely — on the composer's circle there is no room for it, and
  /// the double tap works whether or not anything says so.
  static const double _glyph = 28;
  static const double _glyphFitsAbove = 180;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    final canSwitch = onSwitchLens != null;

    return Semantics(
      label: isRecording ? l10n.videoNoteRecordingLabel : l10n.videoNotePreview,
      child: ExcludeSemantics(
        child: GestureDetector(
          onDoubleTap: onSwitchLens,
          child: SizedBox(
            width: diameter,
            height: diameter,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipOval(
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    // The preview is whatever shape the sensor is; the circle
                    // takes the middle of it rather than squashing it to fit.
                    // That centre square is also the whole of what the reader
                    // will ever see of this note.
                    child: FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: diameter * recorder.aspectRatio,
                        height: diameter,
                        child: recorder.buildPreview(),
                      ),
                    ),
                  ),
                ),
                ProgressRing(
                  progress: progress,
                  stroke: 4,
                  color: isRecording ? chatix.danger : scheme.outlineVariant,
                  trackColor: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
                if (canSwitch && diameter >= _glyphFitsAbove)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.x4),
                      child: Tooltip(
                        message: l10n.videoNoteDoubleTapToSwitch,
                        // Black on white rather than anything off the
                        // scheme: this sits on a camera image, not on a
                        // surface, so it has to read the same in either
                        // theme and against whatever is in frame.
                        child: Container(
                          width: _glyph,
                          height: _glyph,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.55),
                          ),
                          child: const Icon(
                            Icons.flip_camera_ios_outlined,
                            size: 17,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
