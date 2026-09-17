import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart'
    show VideoTrackRenderer, VideoViewFit;

import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/presentation/providers/call_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/call_quality_indicator.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// One person in the call.
///
/// Video when they are sending it, their avatar when they are not, and a
/// speaking ring whose thickness follows the audio level so a quiet room and
/// a loud one look different. The moderator's mute button is drawn only when
/// the caller passes [onMute] — the `call:mute_member` check lives on the
/// screen, which is the only thing that knows the chat membership.
class CallParticipantTile extends StatelessWidget {
  const CallParticipantTile({
    super.key,
    required this.participant,
    this.profile,
    this.isPinned = false,
    this.compact = false,
    this.onTap,
    this.onMute,
  });

  final CallParticipant participant;

  /// The chat member behind [CallParticipant.userId], when the roster knows
  /// them — LiveKit only carries an identity and a display name.
  final ChatProfileEntity? profile;

  final bool isPinned;

  /// Filmstrip sizing: no name row, smaller avatar, tighter corners.
  final bool compact;

  final VoidCallback? onTap;

  /// Server-side mute. Absent when the viewer may not moderate.
  final void Function(bool muted)? onMute;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final name = _displayName(l10n);

    // 0…1 is the whole range LiveKit reports, but ordinary speech sits near
    // the bottom of it, so the ring is driven by a square root: the
    // difference between quiet and loud speech is visible instead of being
    // squeezed into the first tenth of the scale.
    final level = participant.isSpeaking
        ? math.sqrt(participant.audioLevel.clamp(0.0, 1.0))
        : 0.0;
    final radius = compact ? 12.0 : 18.0;

    final video = participant.videoTrack;

    return Semantics(
      label: name,
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: participant.isSpeaking
                  ? scheme.primary
                  : (isPinned ? scheme.outlineVariant : Colors.transparent),
              width: participant.isSpeaking ? 1.5 + 2.5 * level : 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (video != null)
                  VideoTrackRenderer(video, fit: VideoViewFit.cover)
                else
                  _AvatarBackdrop(
                    profile: profile,
                    participant: participant,
                    name: name,
                    compact: compact,
                  ),
                if (isPinned && !compact)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _Chip(
                      child: Icon(
                        Icons.push_pin,
                        size: 14,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: _Footer(
                    participant: participant,
                    name: name,
                    compact: compact,
                    onMute: onMute,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _displayName(AppLocalizations l10n) {
    if (participant.isLocal) return l10n.callYou;
    final fromRoster = profile?.bestName;
    if (fromRoster != null && fromRoster.isNotEmpty) return fromRoster;
    final fromRoom = participant.name;
    if (fromRoom != null && fromRoom.isNotEmpty) return fromRoom;
    return chatDisplayName(null, participant.userId);
  }
}

/// The avatar, on a wash of the person's own colour so a grid of muted
/// cameras is still telling people apart at a glance.
class _AvatarBackdrop extends StatelessWidget {
  const _AvatarBackdrop({
    required this.profile,
    required this.participant,
    required this.name,
    required this.compact,
  });

  final ChatProfileEntity? profile;
  final CallParticipant participant;
  final String name;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.surfaceContainerHigh, scheme.surfaceContainerLow],
        ),
      ),
      child: Center(
        child: profile != null
            ? ChatAvatar.profile(
                profile,
                userId: participant.userId,
                size: compact ? ChatAvatarSize.sm : ChatAvatarSize.md,
              )
            : ChatAvatar(
                userId: participant.userId,
                name: name,
                size: compact ? ChatAvatarSize.sm : ChatAvatarSize.md,
              ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.participant,
    required this.name,
    required this.compact,
    required this.onMute,
  });

  final CallParticipant participant;
  final String name;
  final bool compact;
  final void Function(bool muted)? onMute;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final mute = onMute;

    if (compact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!participant.isMicrophoneEnabled)
            _Chip(child: Icon(Icons.mic_off, size: 12, color: scheme.error))
          else
            const SizedBox.shrink(),
          CallQualityIndicator(quality: participant.quality, size: 10),
        ],
      );
    }

    return _Chip(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            participant.isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
            size: 14,
            color: participant.isMicrophoneEnabled
                ? scheme.onSurface
                : scheme.error,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: scheme.onSurface),
            ),
          ),
          const SizedBox(width: 6),
          CallQualityIndicator(quality: participant.quality),
          if (mute != null) ...[
            const SizedBox(width: 2),
            SizedBox(
              height: 28,
              width: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                tooltip: participant.isMicrophoneEnabled
                    ? l10n.callMuteForEveryone
                    : l10n.callUnmuteForEveryone,
                icon: Icon(
                  participant.isMicrophoneEnabled
                      ? Icons.volume_off_outlined
                      : Icons.volume_up_outlined,
                  size: 16,
                  color: scheme.onSurface,
                ),
                onPressed: () => mute(participant.isMicrophoneEnabled),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small translucent plate, so labels stay readable on top of video.
class _Chip extends StatelessWidget {
  const _Chip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: child,
    );
  }
}
