import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/utils/media_viewer_navigation.dart';
import 'package:chatix/features/chat/presentation/widgets/media_viewer/viewer_playback.dart';
import 'package:chatix/features/chat/presentation/widgets/message_album.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Whether the viewer offers a volume slider: on a desktop, where sound is
/// set per window with a mouse, and not on a phone, whose volume is the
/// buttons on its side.
bool get viewerHasVolumeSlider =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

/// A video's controls in the viewer's bottom bar: play and pause, where it
/// is and how long it runs, a seek bar that names the time it is being
/// dragged to, the speed, and — on a desktop — the volume.
class ViewerVideoControls extends StatelessWidget {
  const ViewerVideoControls({
    super.key,
    required this.controller,
    required this.playback,
    this.showVolume = false,
  });

  final VideoPlayerController controller;
  final ViewerPlayback playback;
  final bool showVolume;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timeStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: AppPalette.onViewerMuted,
      fontFeatures: AppTypography.tabularFigures,
    );

    return ListenableBuilder(
      listenable: Listenable.merge([controller, playback]),
      builder: (context, _) {
        final value = controller.value;
        final isPlaying = value.isPlaying;

        return Row(
          children: [
            IconButton(
              tooltip: isPlaying ? l10n.videoPause : l10n.videoPlay,
              onPressed: playback.togglePlay,
              color: AppPalette.onMediaScrim,
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
            Text(formatMediaDuration(value.position), style: timeStyle),
            Expanded(
              child: ViewerSeekBar(
                value: value,
                onSeekStart: () {
                  final wasPlaying = controller.value.isPlaying;
                  if (wasPlaying) unawaited(controller.pause());
                  return wasPlaying;
                },
                onSeekEnd: (position, {required bool resume}) async {
                  await playback.seekTo(position);
                  if (resume) await controller.play();
                },
              ),
            ),
            Text(formatMediaDuration(value.duration), style: timeStyle),
            Semantics(
              button: true,
              label: l10n.voiceSpeedLabel(playback.speed.label),
              excludeSemantics: true,
              child: TextButton(
                onPressed: playback.cycleSpeed,
                style: TextButton.styleFrom(
                  foregroundColor: AppPalette.onMediaScrim,
                  visualDensity: VisualDensity.compact,
                  // From the theme, not a bare TextStyle: that would drop
                  // the app's typeface along with everything else.
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
                child: Text(playback.speed.label),
              ),
            ),
            if (showVolume) ...[
              IconButton(
                tooltip: playback.isMuted ? l10n.videoUnmute : l10n.videoMute,
                onPressed: playback.toggleMute,
                color: AppPalette.onMediaScrim,
                icon: Icon(
                  playback.isMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                ),
              ),
              SizedBox(
                width: MediaViewerLayout.volumeSliderWidth,
                child: SliderTheme(
                  data: _sliderTheme(context),
                  child: Slider(
                    value: playback.isMuted ? 0 : playback.volume,
                    onChanged: playback.setVolume,
                    semanticFormatterCallback: (value) =>
                        '${l10n.videoVolume} ${(value * 100).round()}%',
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The seek bar, and while it is dragged a bubble over the knob naming the
/// time it would land on — the bar alone says "about a third", the bubble
/// says "1:04".
class ViewerSeekBar extends StatefulWidget {
  const ViewerSeekBar({
    super.key,
    required this.value,
    required this.onSeekStart,
    required this.onSeekEnd,
  });

  final VideoPlayerValue value;

  /// Called as a drag starts; answers whether the video was playing, so it
  /// can carry on once the drag lands.
  final bool Function() onSeekStart;

  final Future<void> Function(Duration position, {required bool resume})
  onSeekEnd;

  @override
  State<ViewerSeekBar> createState() => _ViewerSeekBarState();
}

class _ViewerSeekBarState extends State<ViewerSeekBar> {
  /// Where the knob is being dragged to, as a share of the video; null
  /// when nobody is dragging it and it follows the video.
  double? _dragging;
  bool _resume = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = widget.value;
    final duration = value.duration;

    final played = ViewerVideoRules.fractionOf(value.position, duration);
    final buffered = value.buffered.isEmpty
        ? 0.0
        : ViewerVideoRules.fractionOf(value.buffered.last.end, duration);
    final dragging = _dragging;
    final fraction = dragging ?? played;

    return Semantics(
      label: l10n.videoSeek,
      child: SizedBox(
        height: MediaViewerLayout.seekBarHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const inset = MediaViewerLayout.seekOverlayRadius;
            final knobX = inset + fraction * (constraints.maxWidth - inset * 2);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: SliderTheme(
                    data: _sliderTheme(context),
                    child: Slider(
                      value: fraction,
                      secondaryTrackValue: buffered < fraction
                          ? fraction
                          : buffered,
                      onChangeStart: (start) {
                        _resume = widget.onSeekStart();
                        setState(() => _dragging = start);
                      },
                      onChanged: (next) => setState(() => _dragging = next),
                      onChangeEnd: (end) async {
                        await widget.onSeekEnd(
                          ViewerVideoRules.positionAt(end, duration),
                          resume: _resume,
                        );
                        if (mounted) setState(() => _dragging = null);
                      },
                      semanticFormatterCallback: (share) => formatMediaDuration(
                        ViewerVideoRules.positionAt(share, duration),
                      ),
                    ),
                  ),
                ),
                if (dragging != null)
                  Positioned(
                    left: knobX,
                    bottom:
                        MediaViewerLayout.seekBarHeight -
                        MediaViewerLayout.seekBubbleGap,
                    child: FractionalTranslation(
                      translation: const Offset(-0.5, 0),
                      child: _TimeBubble(
                        text: formatMediaDuration(
                          ViewerVideoRules.positionAt(dragging, duration),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TimeBubble extends StatelessWidget {
  const _TimeBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.mediaScrim,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Padding(
        padding: ChatLayout.mediaMetaPadding,
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppPalette.onMediaScrim,
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
      ),
    );
  }
}

/// The viewer's sliders: the accent for what has played, white for the
/// knob, a faint track for the rest — legible over any frame.
SliderThemeData _sliderTheme(BuildContext context) {
  final accent = Theme.of(context).colorScheme.primary;

  return SliderTheme.of(context).copyWith(
    trackHeight: MediaViewerLayout.seekTrackHeight,
    activeTrackColor: accent,
    inactiveTrackColor: AppPalette.viewerTrack,
    secondaryActiveTrackColor: AppPalette.viewerTrackBuffered,
    thumbColor: AppPalette.onMediaScrim,
    overlayColor: AppPalette.viewerTrack,
    trackShape: const RoundedRectSliderTrackShape(),
    thumbShape: const RoundSliderThumbShape(
      enabledThumbRadius: MediaViewerLayout.seekThumbRadius,
    ),
    overlayShape: const RoundSliderOverlayShape(
      overlayRadius: MediaViewerLayout.seekOverlayRadius,
    ),
  );
}
