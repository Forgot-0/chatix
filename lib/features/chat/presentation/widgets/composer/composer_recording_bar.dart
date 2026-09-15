import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/providers/video_note_record_provider.dart';
import 'package:chatix/features/chat/presentation/providers/voice_recorder_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_video_note_stage.dart';
import 'package:chatix/features/chat/presentation/widgets/voice_player.dart';
import 'package:chatix/features/chat/presentation/widgets/voice_waveform_bars.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Whichever recorder is running, in the text box's place.
///
/// One widget rather than a choice made by the composer: the composer has no
/// `ref` by design, and which of the two is open is a fact about the
/// recorders, not about the row they stand in.
class ComposerRecordingBar extends ConsumerWidget {
  const ComposerRecordingBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFilming = ref.watch(
      videoNoteRecordProvider.select((state) => state.isActive),
    );

    return isFilming
        ? const VideoNoteRecordingBar()
        : const VoiceRecordingBar();
  }
}

/// What stands in the text box while a voice message is being recorded.
///
/// The clock, the live waveform, and what the thumb can still do about it —
/// the two gestures (slide left to cancel, up to lock) are only discoverable
/// if something says so while they are available.
///
/// The cancel slide is drawn, not just announced: the bin travels in from the
/// right as the thumb travels left, and everything else fades out behind it,
/// so letting go is a decision already visibly made rather than a surprise.
class VoiceRecordingBar extends ConsumerWidget {
  const VoiceRecordingBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceRecordProvider);
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    if (!state.isActive) return const SizedBox.shrink();

    final slide = state.cancelProgress;

    return SizedBox(
      height: 36,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // The recording itself, sliding out of the way of the bin.
          Opacity(
            opacity: (1 - slide).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(-slide * 24, 0),
              child: _Recording(state: state),
            ),
          ),
          if (slide > 0)
            Positioned.fill(
              child: _CancelTrack(
                progress: slide,
                committed: state.willCancel,
                label: state.willCancel
                    ? l10n.voiceReleaseToCancel
                    : l10n.voiceSlideToCancel,
              ),
            ),
          // Nothing to slide any more once it is locked: the buttons beside
          // the bar take over, so the bar just says so.
          if (state.stage == VoiceRecordStage.locked && slide == 0)
            Positioned(
              right: 0,
              child: Text(
                l10n.voiceRecordingLocked,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: chatix.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The red dot, the clock, the waveform, and the hint or the countdown.
class _Recording extends StatelessWidget {
  const _Recording({required this.state});

  final VoiceRecordState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    // Past 9:30 the clock stops counting up and starts counting down: what
    // matters by then is how much room is left before the 600-second cap
    // (api-docs §5.5) ends the recording on its own.
    final warning = state.isNearLimit;
    final stopped = state.holdsRecording;

    return Row(
      children: [
        // A closed microphone does not blink: the dot stops once the cap
        // has ended the recording.
        if (stopped)
          Icon(Icons.mic_off_rounded, size: 14, color: chatix.danger)
        else
          _PulsingDot(color: chatix.danger),
        const SizedBox(width: AppSpacing.x2),
        SizedBox(
          width: 44,
          child: Text(
            formatVoiceDuration(state.elapsed),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 26,
            child: VoiceWaveformBars(
              bars: state.live,
              // Everything already spoken is behind the playhead by
              // definition, so the live bars are drawn filled.
              progress: 1,
              playedColor: warning || stopped
                  ? chatix.danger
                  : theme.colorScheme.primary,
              remainingColor: theme.colorScheme.outlineVariant,
              alignEnd: true,
              semanticsLabel: l10n.voiceRecording,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.x2),
        if (stopped)
          Flexible(
            child: Text(
              l10n.voiceLimitReached,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: chatix.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else if (warning)
          Text(
            l10n.voiceTimeLeft(formatVoiceDuration(state.remaining)),
            style: theme.textTheme.labelSmall?.copyWith(
              color: chatix.danger,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          )
        else
          Flexible(
            child: Text(
              state.stage == VoiceRecordStage.locked
                  ? l10n.voiceRecordingLocked
                  : l10n.voiceSlideToCancel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// The bin driving in from the right, and the word for what letting go does.
///
/// The lid tips further as the slide goes on and the whole thing swells the
/// moment the gesture commits, which is the same instant the haptic fires.
class _CancelTrack extends StatelessWidget {
  const _CancelTrack({
    required this.progress,
    required this.committed,
    required this.label,
  });

  final double progress;
  final bool committed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Opacity(
            opacity: progress.clamp(0.0, 1.0),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: theme.textTheme.labelSmall?.copyWith(
                color: chatix.danger,
                fontWeight: committed ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.x2),
        Transform.translate(
          // Starts a little off the right edge and arrives as the slide
          // completes, so the bin and the thumb move together.
          offset: Offset(28 * (1 - progress), 0),
          child: AnimatedScale(
            scale: committed ? 1.25 : 1,
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            child: _TrashCan(
              lidAngle: -0.5 * progress,
              color: chatix.danger,
            ),
          ),
        ),
      ],
    );
  }
}

/// A bin whose lid comes off as the gesture approaches.
class _TrashCan extends StatelessWidget {
  const _TrashCan({required this.lidAngle, required this.color});

  final double lidAngle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 24,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Icon(Icons.delete_outline_rounded, size: 22, color: color),
          Positioned(
            top: 0,
            child: Transform.rotate(
              angle: lidAngle,
              alignment: Alignment.centerRight,
              child: Container(
                width: 14,
                height: 2.5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The recording indicator: a dot that breathes, so a bar that is otherwise
/// still in a silent room still says the microphone is open.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller.drive(Tween<double>(begin: 1, end: 0.25)),
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
