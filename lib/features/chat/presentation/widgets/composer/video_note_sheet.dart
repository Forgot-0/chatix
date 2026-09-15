import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/data/datasources/video_note_recorder.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/presentation/widgets/video_note_lens_view.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Recording a video note, in the shape it will be sent in.
///
/// The circle is the point: a video note is round everywhere it is ever
/// shown, so framing one in a rectangle and hoping for the best is how you
/// end up with a chin in the corner. The ring around it is the sixty seconds
/// the API allows (§5.5), running down as it records and stopping the take
/// on its own when it is spent.
class VideoNoteSheet extends ConsumerStatefulWidget {
  const VideoNoteSheet({super.key});

  /// Opens the recorder and answers with the take, or null if it was
  /// cancelled or could not start.
  static Future<VideoNoteTake?> show(BuildContext context) {
    return showModalBottomSheet<VideoNoteTake>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const VideoNoteSheet(),
    );
  }

  static const Duration limit = Duration(
    seconds: ChatAttachmentLimits.maxVideoNoteDurationSeconds,
  );

  /// How big the circle is drawn. Large enough to frame a face by, small
  /// enough that the button underneath is still reachable by thumb.
  static const double diameter = 260;

  @override
  ConsumerState<VideoNoteSheet> createState() => _VideoNoteSheetState();
}

class _VideoNoteSheetState extends ConsumerState<VideoNoteSheet> {
  VideoNoteReadiness? _readiness;

  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  bool _isFinishing = false;

  /// A take that came back with nothing usable. Kept on screen instead of
  /// closing the sheet: losing the camera because a tap was too quick is a
  /// worse answer than saying so and staying put.
  bool _discarded = false;

  /// A camera swap is in flight. There is no preview to draw while the old
  /// controller is closed and the new one is waking.
  bool _isSwitchingLens = false;

  /// Taken once and closed in [dispose]: the camera belongs to this sheet,
  /// not to whatever else happens to be listening.
  late final VideoNoteRecorder _recorder = ref.read(
    videoNoteRecorderFactoryProvider,
  )();

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  Future<void> _open() async {
    final readiness = await _recorder.prepare();
    if (!mounted) return;
    setState(() => _readiness = readiness);
  }

  void _toggle() {
    if (_isFinishing) return;
    if (_recorder.isRecording) {
      unawaited(_finish());
      return;
    }
    unawaited(_begin());
  }

  Future<void> _begin() async {
    HapticFeedback.mediumImpact();
    await _recorder.start();
    if (!mounted) return;

    setState(() {
      _elapsed = Duration.zero;
      _discarded = false;
    });

    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;

      setState(() => _elapsed += const Duration(milliseconds: 100));
      if (_elapsed >= VideoNoteSheet.limit) unawaited(_finish());
    });
  }

  Future<void> _finish() async {
    if (_isFinishing) return;
    _isFinishing = true;

    _ticker?.cancel();
    _ticker = null;
    HapticFeedback.selectionClick();

    final take = await _recorder.stop();
    if (!mounted) return;

    if (take == null) {
      setState(() {
        _isFinishing = false;
        _elapsed = Duration.zero;
        _discarded = true;
      });
      return;
    }

    Navigator.of(context).pop(take);
  }

  /// Turns the camera around, on a double tap on the circle.
  ///
  /// Guarded rather than re-entrant: opening a camera is not instant, and
  /// two taps landing during the first switch would leave two controllers
  /// racing for one sensor.
  Future<void> _switchLens() async {
    if (_isSwitchingLens || _recorder.isRecording) return;

    setState(() => _isSwitchingLens = true);
    HapticFeedback.selectionClick();

    await _recorder.switchLens();
    if (!mounted) return;
    setState(() => _isSwitchingLens = false);
  }

  Future<void> _close() async {
    _ticker?.cancel();
    _ticker = null;
    await _recorder.cancel();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final readiness = _readiness;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IconButton.filledTonal(
                tooltip: l10n.close,
                icon: const Icon(Icons.close_rounded),
                onPressed: _close,
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            if (readiness == null)
              const SizedBox(
                height: VideoNoteSheet.diameter,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (readiness != VideoNoteReadiness.ready)
              _Unavailable(readiness: readiness)
            else ...[
              if (_isSwitchingLens)
                const SizedBox(
                  height: VideoNoteSheet.diameter,
                  width: VideoNoteSheet.diameter,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                VideoNoteLensView(
                  recorder: _recorder,
                  diameter: VideoNoteSheet.diameter,
                  progress:
                      _elapsed.inMilliseconds /
                      VideoNoteSheet.limit.inMilliseconds,
                  isRecording: _recorder.isRecording,
                  onSwitchLens: _recorder.canSwitchLens ? _switchLens : null,
                ),
              const SizedBox(height: AppSpacing.x4),
              Text(
                switch ((_recorder.isRecording, _discarded)) {
                  (true, _) => _clock(_elapsed),
                  (false, true) => l10n.videoNoteDiscarded,
                  (false, false) => l10n.videoNoteTapToRecord,
                },
                style: theme.textTheme.titleMedium?.copyWith(
                  color: _recorder.isRecording || _discarded
                      ? ChatixTheme.of(context).danger
                      : theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              _Shutter(isRecording: _recorder.isRecording, onTap: _toggle),
              // Said once, quietly, and only while it is true: a double tap
              // does nothing on a phone with one camera, and nothing at all
              // once the take is running.
              if (_recorder.canSwitchLens) ...[
                const SizedBox(height: AppSpacing.x3),
                Text(
                  l10n.videoNoteDoubleTapToSwitch,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.x4),
          ],
        ),
      ),
    );
  }

  static String _clock(Duration value) {
    final seconds = value.inSeconds;
    return '0:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

/// Start, then stop and send. One button, because there is one decision.
class _Shutter extends StatelessWidget {
  const _Shutter({required this.isRecording, required this.onTap});

  final bool isRecording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      label: isRecording ? l10n.composerSendLabel : l10n.videoNoteTapToRecord,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onTap,
          radius: 44,
          customBorder: const CircleBorder(),
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isRecording ? chatix.danger : scheme.outline,
                width: 3,
              ),
            ),
            child: AnimatedContainer(
              duration: AppMotion.base,
              curve: AppMotion.curve,
              width: isRecording ? 28 : 54,
              height: isRecording ? 28 : 54,
              decoration: BoxDecoration(
                color: isRecording ? chatix.danger : scheme.primary,
                borderRadius: BorderRadius.circular(isRecording ? 6 : 27),
              ),
              child: isRecording
                  ? Icon(Icons.send_rounded, size: 16, color: scheme.onPrimary)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Why there is no camera to point at anyone.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.readiness});

  final VideoNoteReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final text = switch (readiness) {
      VideoNoteReadiness.denied => l10n.videoNoteCameraDenied,
      VideoNoteReadiness.noCamera => l10n.videoNoteNoCamera,
      VideoNoteReadiness.tooLarge => l10n.videoNoteTooLarge(
        ChatAttachmentLimits.maxVideoNoteResolutionPx,
      ),
      VideoNoteReadiness.failed ||
      VideoNoteReadiness.ready => l10n.videoNoteCameraFailed,
    };

    return SizedBox(
      height: VideoNoteSheet.diameter,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_outlined,
                size: 32,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: AppSpacing.x3),
              Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
