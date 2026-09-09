import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/features/chat/data/datasources/voice_recorder.dart';
import 'package:chatix/features/chat/presentation/providers/voice_recorder_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/voice_player.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

class VoiceRecordButton extends ConsumerStatefulWidget {
  const VoiceRecordButton({super.key, required this.onRecorded});

  final void Function(VoiceRecording recording) onRecorded;

  @override
  ConsumerState<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends ConsumerState<VoiceRecordButton> {
  static const double _cancelAt = 90;
  static const double _lockAt = 60;

  Offset _origin = Offset.zero;

  VoiceRecordController get _controller =>
      ref.read(voiceRecordProvider.notifier);

  Future<void> _finish() async {
    final recording = await _controller.stop();
    if (recording != null) widget.onRecorded(recording);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceRecordProvider);
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    if (state.stage == VoiceRecordStage.denied) {
      return IconButton(
        tooltip: l10n.voicePermissionDenied,
        icon: Icon(Icons.mic_off_outlined, color: chatix.danger),
        onPressed: _controller.dismissDenied,
      );
    }

    if (state.stage == VoiceRecordStage.locked) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.cancel,
            icon: Icon(Icons.delete_outline, color: chatix.danger),
            onPressed: _controller.cancel,
          ),
          IconButton.filled(icon: const Icon(Icons.send), onPressed: _finish),
        ],
      );
    }

    return GestureDetector(
      onLongPressStart: (details) {
        _origin = details.globalPosition;
        _controller.start();
      },
      onLongPressMoveUpdate: (details) {
        final delta = details.globalPosition - _origin;

        if (-delta.dy > _lockAt) {
          _controller.lock();
          return;
        }
        _controller.updateDrag(willCancel: -delta.dx > _cancelAt);
      },
      onLongPressEnd: (_) {
        if (ref.read(voiceRecordProvider).stage != VoiceRecordStage.holding) {
          return;
        }
        if (ref.read(voiceRecordProvider).willCancel) {
          _controller.cancel();
          return;
        }
        _finish();
      },
      onLongPressCancel: _controller.cancel,
      child: AnimatedContainer(
        duration: ChatixTheme.duration,
        curve: ChatixTheme.curve,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: state.isRecording
              ? (state.willCancel
                    ? chatix.danger.withValues(alpha: 0.2)
                    : theme.colorScheme.primary.withValues(alpha: 0.16))
              : Colors.transparent,
        ),
        child: Icon(
          state.isRecording ? Icons.mic : Icons.mic_none_outlined,
          color: state.willCancel
              ? chatix.danger
              : (state.isRecording
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

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
