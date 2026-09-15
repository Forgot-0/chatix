import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/voice_waveform.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/voice_playback_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/voice_waveform_bars.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// A voice message in a bubble: who said it, what it looks like, how long it
/// is, and whether it has been heard.
///
/// Owns no player of its own. The audio lives in [voicePlaybackProvider], one
/// for the whole app, which is what lets playback carry on after this widget
/// scrolls away or the chat is left — and what stops two bubbles talking over
/// each other.
class VoicePlayer extends ConsumerWidget {
  const VoicePlayer({
    super.key,
    required this.attachment,
    required this.messageId,
    required this.foreground,
    required this.accent,
    this.author,
    this.authorId,
    this.isMine = false,
  });

  final AttachmentEntity attachment;
  final String messageId;

  /// The bubble's text colour, which everything here is drawn against.
  final Color foreground;

  /// What the played part of the waveform is filled with.
  final Color accent;

  final ChatProfileEntity? author;
  final int? authorId;

  /// Outgoing messages show no "heard" mark: whether the other side has
  /// listened is not something the API reports — `AttachmentDTO` has no
  /// per-listener state and read receipts are per message (api-docs §5.5).
  /// The mark here is this device's own memory of what it has played.
  final bool isMine;

  static const double _waveformWidth = 128;
  static const double _waveformHeight = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final playback = ref.watch(voicePlaybackProvider);
    final isCurrent = playback.isCurrent(attachment.id);
    final isPlaying = playback.isPlayingNow(attachment.id);
    final failed = isCurrent && playback.failed;

    // Recorded here, or a stable stand-in for somebody else's recording.
    final waveform =
        ref.watch(voiceLocalStoreProvider).readWaveform(attachment.id) ??
        VoiceWaveform.placeholder(attachment.id);

    final total = _total(playback, isCurrent);
    final shown = isCurrent && playback.position > Duration.zero
        ? playback.position
        : total;

    final progress = isCurrent ? playback.progress : 0.0;
    final heard = playback.hasBeenHeard(attachment.id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatAvatar.profile(
            author,
            userId: authorId,
            size: ChatAvatarSize.xs,
          ),
          const SizedBox(width: AppSpacing.x2),
          _PlayButton(
            isPlaying: isPlaying,
            isLoading: isCurrent && playback.isLoading,
            failed: failed,
            foreground: foreground,
            accent: accent,
            label: isPlaying ? l10n.voicePause : l10n.voicePlay,
            // A failed fetch is worth another try rather than a dead
            // button: the link it was after is regenerated on demand.
            onPressed: () => _toggle(ref),
          ),
          const SizedBox(width: AppSpacing.x2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: _waveformWidth,
                height: _waveformHeight,
                child: VoiceWaveformBars(
                  bars: waveform.bars,
                  progress: progress,
                  playedColor: accent,
                  remainingColor: foreground.withValues(alpha: 0.35),
                  semanticsLabel: l10n.voiceMessage,
                  // Scrubbing only makes sense once there is something
                  // loaded to scrub through.
                  onSeek: isCurrent
                      ? (fraction) => unawaited(
                          ref
                              .read(voicePlaybackProvider.notifier)
                              .seekFraction(attachment.id, fraction),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    failed ? l10n.voiceUnavailable : formatVoiceDuration(shown),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: foreground.withValues(alpha: 0.75),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  // The unheard dot, on incoming messages only, and only
                  // until it has been played through.
                  if (!isMine && !heard) ...[
                    const SizedBox(width: 6),
                    Semantics(
                      label: l10n.voiceNotListened,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          // The speed control belongs to the message being played, not to
          // every bubble in the chat.
          if (isCurrent) ...[
            const SizedBox(width: AppSpacing.x1),
            _SpeedChip(
              speed: playback.speed,
              foreground: foreground,
              onTap: () => unawaited(
                ref.read(voicePlaybackProvider.notifier).cycleSpeed(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Duration _total(VoicePlaybackState playback, bool isCurrent) {
    if (isCurrent && playback.duration > Duration.zero) {
      return playback.duration;
    }

    final seconds = attachment.durationSeconds;
    return seconds != null && seconds > 0
        ? Duration(seconds: seconds)
        : Duration.zero;
  }

  void _toggle(WidgetRef ref) {
    final track = VoiceTrack(
      chatId: attachment.chatId,
      messageId: messageId,
      attachment: attachment,
    );

    unawaited(
      ref
          .read(voicePlaybackProvider.notifier)
          .toggle(track, upNext: _queue(ref)),
    );
  }

  /// Every voice message in this chat, oldest first.
  ///
  /// Read at the moment play is pressed rather than watched: it decides
  /// where playback goes when this one ends, and by then the feed may have
  /// grown — but a bubble that rebuilds whenever any message arrives is a
  /// feed that rebuilds every bubble.
  List<VoiceTrack> _queue(WidgetRef ref) {
    final messages = ref
        .read(chatDetailProvider(attachment.chatId))
        .value
        ?.messages;

    return messages == null ? const [] : voiceTracksIn(messages);
  }
}

/// `m:ss`, the way a voice message is always written.
String formatVoiceDuration(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.isPlaying,
    required this.isLoading,
    required this.failed,
    required this.foreground,
    required this.accent,
    required this.label,
    required this.onPressed,
  });

  final bool isPlaying;
  final bool isLoading;
  final bool failed;
  final Color foreground;
  final Color accent;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onPressed,
          radius: 22,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 36,
            height: 36,
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    ),
                  )
                : AnimatedSwitcher(
                    duration: AppMotion.fast,
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      failed
                          ? Icons.error_outline_rounded
                          : (isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                      key: ValueKey<int>(
                        failed ? 2 : (isPlaying ? 1 : 0),
                      ),
                      size: 30,
                      color: foreground,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// `1x` / `1.5x` / `2x`, cycled by tapping.
class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.speed,
    required this.foreground,
    required this.onTap,
  });

  final VoiceSpeed speed;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      label: l10n.voiceSpeedLabel(speed.label),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(
              speed.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
