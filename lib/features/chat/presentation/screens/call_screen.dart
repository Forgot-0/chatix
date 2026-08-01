import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/providers/call_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';

/// The LiveKit call room for one chat (api-docs §6.6).
///
/// Joining is an explicit tap rather than something [initState] does, matching
/// `CallController`: the endpoint allows 10 joins per 5 minutes and joining
/// opens the microphone, so a rebuild must never trigger it.
///
/// Leaving happens on `dispose` too — the room lives in an autoDispose provider
/// keyed by chat id, so popping this route always ends the call.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callProvider(widget.chatId));
    final detail = ref.watch(chatDetailProvider(widget.chatId)).value;
    final myUserId = ref.watch(authProvider).value?.id;

    // `call:mute_member` is owner/admin only (§9.1). Resolved from the last
    // data we hold — UX only, the server enforces it regardless.
    final canMuteOthers = hasChatPermission(
      detail?.chat,
      detail?.me,
      ChatPermissions.callMuteMember,
    );

    final state = callState.value ?? const CallState();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(detail?.chat?.name ?? 'Call'),
            if (state.token != null)
              Text(
                'Room ${state.token!.slug}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (state.failure != null)
              _CallBanner(message: state.failure!.message),
            Expanded(
              child: switch (state.stage) {
                CallStage.idle => _JoinPrompt(
                  isBusy: false,
                  onJoin: () =>
                      ref.read(callProvider(widget.chatId).notifier).join(),
                ),
                CallStage.connecting => const _JoinPrompt(
                  isBusy: true,
                  onJoin: null,
                ),
                CallStage.disconnected => _CallEnded(
                  onRejoin: () =>
                      ref.read(callProvider(widget.chatId).notifier).join(),
                ),
                CallStage.connected => _ParticipantGrid(
                  participants: state.participants,
                  myUserId: myUserId,
                  canMuteOthers: canMuteOthers,
                  onMute: (userId, muted) => _muteParticipant(userId, muted),
                ),
              },
            ),
            if (state.isConnected)
              _CallControls(
                isMicrophoneEnabled: state.isMicrophoneEnabled,
                isCameraEnabled: state.isCameraEnabled,
                onToggleMicrophone: () => ref
                    .read(callProvider(widget.chatId).notifier)
                    .toggleMicrophone(),
                onToggleCamera: () => ref
                    .read(callProvider(widget.chatId).notifier)
                    .toggleCamera(),
                onHangUp: _hangUp,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _hangUp() async {
    await ref.read(callProvider(widget.chatId).notifier).leave();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _muteParticipant(int userId, bool muted) async {
    final failure = await ref
        .read(callProvider(widget.chatId).notifier)
        .muteParticipant(userId, muted: muted);
    if (!mounted || failure == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failure.message)));
  }
}

class _JoinPrompt extends StatelessWidget {
  const _JoinPrompt({required this.isBusy, required this.onJoin});

  final bool isBusy;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.call, size: 64, color: Colors.white54),
          const SizedBox(height: 24),
          if (isBusy)
            const Column(
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 12),
                Text('Connecting…', style: TextStyle(color: Colors.white70)),
              ],
            )
          else
            FilledButton.icon(
              onPressed: onJoin,
              icon: const Icon(Icons.call),
              label: const Text('Join call'),
            ),
        ],
      ),
    );
  }
}

class _CallEnded extends StatelessWidget {
  const _CallEnded({required this.onRejoin});

  final VoidCallback onRejoin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.call_end, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          const Text('Call ended', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onRejoin,
            icon: const Icon(Icons.refresh),
            label: const Text('Rejoin'),
          ),
        ],
      ),
    );
  }
}

class _ParticipantGrid extends StatelessWidget {
  const _ParticipantGrid({
    required this.participants,
    required this.myUserId,
    required this.canMuteOthers,
    required this.onMute,
  });

  final List<CallParticipant> participants;
  final int? myUserId;
  final bool canMuteOthers;
  final void Function(int userId, bool muted) onMute;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for participants…',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: participants.length == 1 ? 1 : 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 3 / 4,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        return _ParticipantTile(
          participant: participant,
          // Muting yourself is the local mic button, not a moderation call.
          canMute:
              canMuteOthers &&
              !participant.isLocal &&
              participant.userId != null &&
              participant.userId != myUserId,
          onMute: (muted) => onMute(participant.userId!, muted),
        );
      },
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.participant,
    required this.canMute,
    required this.onMute,
  });

  final CallParticipant participant;
  final bool canMute;
  final void Function(bool muted) onMute;

  @override
  Widget build(BuildContext context) {
    final label = participant.name ?? 'User ${participant.identity}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          // A speaking ring is the cheapest way to tell who is talking in an
          // audio-only call, where every tile is otherwise identical.
          color: participant.isSpeaking
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (participant.videoTrack != null)
              VideoTrackRenderer(participant.videoTrack!)
            else
              Center(
                child: CircleAvatar(
                  radius: 32,
                  child: Text(
                    label.isEmpty ? '?' : label.characters.first.toUpperCase(),
                  ),
                ),
              ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Row(
                children: [
                  Icon(
                    participant.isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
                    size: 16,
                    color: participant.isMicrophoneEnabled
                        ? Colors.white
                        : Colors.redAccent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      participant.isLocal ? '$label (you)' : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (canMute)
                    IconButton(
                      tooltip: participant.isMicrophoneEnabled
                          ? 'Mute for everyone'
                          : 'Unmute for everyone',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        participant.isMicrophoneEnabled
                            ? Icons.volume_off
                            : Icons.volume_up,
                        size: 16,
                        color: Colors.white,
                      ),
                      onPressed: () => onMute(participant.isMicrophoneEnabled),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallControls extends StatelessWidget {
  const _CallControls({
    required this.isMicrophoneEnabled,
    required this.isCameraEnabled,
    required this.onToggleMicrophone,
    required this.onToggleCamera,
    required this.onHangUp,
  });

  final bool isMicrophoneEnabled;
  final bool isCameraEnabled;
  final VoidCallback onToggleMicrophone;
  final VoidCallback onToggleCamera;
  final VoidCallback onHangUp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
            label: isMicrophoneEnabled ? 'Mute' : 'Unmute',
            onPressed: onToggleMicrophone,
          ),
          _ControlButton(
            icon: isCameraEnabled ? Icons.videocam : Icons.videocam_off,
            label: isCameraEnabled ? 'Stop video' : 'Start video',
            onPressed: onToggleCamera,
          ),
          _ControlButton(
            icon: Icons.call_end,
            label: 'Leave',
            background: Colors.redAccent,
            onPressed: onHangUp,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.background,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: background ?? const Color(0xFF2C2C2E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _CallBanner extends StatelessWidget {
  const _CallBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.red.withValues(alpha: 0.15),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
