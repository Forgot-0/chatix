import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/providers/video_note_record_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/video_note_lens_view.dart';
import 'package:chatix/features/chat/presentation/widgets/voice_player.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The circle a video note is being recorded in, above the composer row.
///
/// Above rather than inside: what is being recorded is what will be sent, and
/// a face is not legible at the height of a text field. It takes no room at
/// all when nothing is being recorded, and grows into place when something
/// is, so the composer does not jump by the height of a camera every time a
/// thumb lands on the button.
class ComposerVideoNoteStage extends ConsumerWidget {
  const ComposerVideoNoteStage({super.key});

  /// Big enough to frame a face by, small enough to leave the conversation
  /// behind it visible.
  static const double diameter = 190;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(videoNoteRecordProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final recorder = ref.read(videoNoteRecordProvider.notifier).recorder;

    return AnimatedSize(
      duration: AppMotion.base,
      curve: AppMotion.curve,
      alignment: Alignment.bottomCenter,
      child: !state.isActive
          // Nothing at all rather than an empty box of some width: the
          // composer's own column decides how wide this is, and a stage that
          // claims a width while it has nothing to show would animate from
          // that width every time a thumb lands on the button.
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.x3,
                bottom: AppSpacing.x2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: diameter,
                    height: diameter,
                    child: switch (state.stage) {
                      // The cap closed the camera; the circle says so and
                      // waits for the two buttons beside the box.
                      VideoNoteStage.completed => _Still(
                        icon: Icons.videocam_off_rounded,
                        label: l10n.voiceLimitReached,
                      ),
                      _ when recorder == null || !state.isRecording => _Still(
                        icon: null,
                        label: l10n.videoNoteOpeningCamera,
                      ),
                      _ => VideoNoteLensView(
                        recorder: recorder,
                        diameter: diameter,
                        progress: state.progress,
                        isRecording: true,
                        onSwitchLens: state.canSwitchLens
                            ? () => unawaited(
                                ref
                                    .read(videoNoteRecordProvider.notifier)
                                    .switchLens(),
                              )
                            : null,
                      ),
                    },
                  ),
                  if (state.canSwitchLens && state.isRecording) ...[
                    const SizedBox(height: AppSpacing.x2),
                    Text(
                      l10n.videoNoteDoubleTapToSwitch,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// A circle with no camera behind it, and the reason why.
///
/// Either the moment between the thumb landing and the camera opening — a
/// camera takes a few hundred milliseconds to wake, and a black circle with
/// nothing in it reads as a failure rather than a wait — or the take the
/// sixty-second cap has already ended.
class _Still extends StatelessWidget {
  const _Still({required this.icon, required this.label});

  /// Null for a wait, which gets a spinner instead.
  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surfaceContainerHighest,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon == null)
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 26, color: ChatixTheme.of(context).danger),
          const SizedBox(height: AppSpacing.x3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x5),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What stands in the text box while a video note is being recorded: the
/// clock, and what the thumb can still do about it.
///
/// Deliberately plainer than the voice bar — there is no waveform to show,
/// because the picture is already on screen above it.
class VideoNoteRecordingBar extends ConsumerWidget {
  const VideoNoteRecordingBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(videoNoteRecordProvider);
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    if (!state.isActive) return const SizedBox.shrink();

    final stopped = state.holdsRecording;

    final hint = switch (state.stage) {
      VideoNoteStage.preparing => l10n.videoNoteOpeningCamera,
      VideoNoteStage.locked => l10n.voiceRecordingLocked,
      VideoNoteStage.completed => l10n.voiceLimitReached,
      _ => state.willCancel
          ? l10n.voiceReleaseToCancel
          : l10n.voiceSlideToCancel,
    };

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Icon(
            stopped ? Icons.videocam_off_rounded : Icons.videocam_rounded,
            size: 16,
            color: chatix.danger,
          ),
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
            child: Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: theme.textTheme.labelSmall?.copyWith(
                color: state.willCancel || stopped
                    ? chatix.danger
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: state.willCancel ? FontWeight.w700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
