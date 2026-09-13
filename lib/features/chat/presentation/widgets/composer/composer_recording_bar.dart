import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/features/chat/presentation/providers/voice_recorder_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/voice_player.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What stands in the text box while a voice message is being recorded.
///
/// The waveform, the clock, and what the thumb can still do about it — the
/// two gestures (slide to cancel, slide up to lock) are only discoverable if
/// something says so while they are available.
class VoiceRecordingBar extends ConsumerWidget {
  const VoiceRecordingBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceRecordProvider);
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    if (!state.isRecording) return const SizedBox.shrink();

    return Row(
      children: [
        RecordingWaveform(
          amplitude: state.amplitude,
          color: state.willCancel ? chatix.danger : chatix.danger,
        ),
        const SizedBox(width: 10),
        Text(
          _format(state.elapsed),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            state.willCancel
                ? l10n.voiceReleaseToCancel
                : (state.stage == VoiceRecordStage.locked
                      ? l10n.voiceRecordingLocked
                      : l10n.voiceSlideToCancel),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: state.willCancel
                  ? chatix.danger
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (state.remaining.inSeconds <= 30)
          Text(
            '-${_format(state.remaining)}',
            style: theme.textTheme.labelSmall?.copyWith(color: chatix.danger),
          ),
      ],
    );
  }

  static String _format(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
