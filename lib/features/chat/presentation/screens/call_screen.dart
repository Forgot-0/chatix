import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/permissions/media_permissions.dart';
import 'package:chatix/core/providers/theme_providers.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/presentation/providers/active_call_provider.dart';
import 'package:chatix/features/chat/presentation/providers/call_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/utils/call_layout.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/features/chat/presentation/utils/chat_preview.dart'
    show formatVoiceDuration;
import 'package:chatix/features/chat/presentation/widgets/call_controls_bar.dart';
import 'package:chatix/features/chat/presentation/widgets/call_participant_grid.dart';
import 'package:chatix/features/chat/presentation/widgets/call_permission_notice.dart';
import 'package:chatix/features/chat/presentation/widgets/call_self_preview.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The full-screen call.
///
/// Note what this screen is *not*: there is no incoming call, no ringing and
/// no "the other side hung up". `call_started`/`call_ended`/`call_joined`/
/// `call_left` are declared in `WSEventType` but never published by the
/// backend, and there is no push channel for them (api-docs §5.6) — so a call
/// here is a room you join, and the UI says exactly that rather than pretending
/// to ring somebody. Leaving is a LiveKit disconnect for the same reason:
/// §5.6 has no REST endpoint for ending or leaving a call.
///
/// Walking away from this screen does not end the call. The call lives in
/// [callProvider], which is app-wide, and `CallOverlay` floats a mini player
/// over whatever the user goes to next.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  /// How long the bar stays up after the last touch.
  static const Duration _controlsLinger = Duration(seconds: 4);

  bool _controlsVisible = true;
  Timer? _hideControls;
  Timer? _elapsedTicker;

  @override
  void initState() {
    super.initState();
    // Tells the mini player to stand down while this screen is on top.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(callScreenVisibleProvider.notifier).set(visible: true);
      }
    });
    // Only the elapsed-time readout in the header needs this, so it stops
    // asking for frames the moment there is no call to time.
    _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(callProvider).isLive) setState(() {});
    });
    _restartHideTimer();
  }

  @override
  void dispose() {
    _hideControls?.cancel();
    _elapsedTicker?.cancel();
    ref.read(callScreenVisibleProvider.notifier).set(visible: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(callProvider);
    final detail = ref.watch(chatDetailProvider(widget.chatId)).value;
    final myUserId = ref.watch(authProvider).value?.id;

    final canMuteOthers = hasChatPermission(
      detail?.chat,
      detail?.me,
      ChatPermissions.callMuteMember,
    );

    // A call in some other chat must not bleed into this screen: it shows its
    // own chat's join prompt, and joining here swaps the room.
    final call = state.isFor(widget.chatId) ? state : const CallState();

    return Theme(
      // Calls read as a dark surface on every platform, and the app's own
      // dark theme keeps the accent, the spacing and the type identical to
      // the rest of ChatiX — so the screen looks equally finished whichever
      // theme the app is in, rather than turning into a white video wall.
      data: ref.watch(darkThemeProvider),
      child: Builder(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: Semantics(
              // The bar gets out of the way on its own; this is how a screen
              // reader is told that a tap anywhere brings it back.
              onTap: _revealControls,
              onTapHint: l10n.callShowControls,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: _revealControls,
                child: Column(
                  children: [
                    _Header(
                      visible: _controlsVisible || !call.isLive,
                      title: detail?.chat?.name ?? l10n.callTitle,
                      subtitle: _subtitle(call, l10n),
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                    if (call.failure != null)
                      _CallBanner(
                        message: friendlyFailureMessage(call.failure),
                        onDismiss: () =>
                            ref.read(callProvider.notifier).clearFailure(),
                      ),
                    if (call.permissionIssue != null)
                      CallPermissionBanner(
                        issue: call.permissionIssue!,
                        onOpenSettings: () => ref
                            .read(callProvider.notifier)
                            .openPermissionSettings(),
                        onDismiss: () => ref
                            .read(callProvider.notifier)
                            .dismissPermissionIssue(),
                      ),
                    Expanded(
                      child: switch (call.stage) {
                        CallStage.idle => _JoinPrompt(
                          isBusy: false,
                          onJoin: _join,
                        ),
                        CallStage.connecting => const _JoinPrompt(
                          isBusy: true,
                          onJoin: null,
                        ),
                        CallStage.disconnected => _CallEnded(onRejoin: _join),
                        CallStage.connected ||
                        CallStage.reconnecting => _CallStage(
                          call: call,
                          profiles: _profilesOf(detail?.chat),
                          myUserId: myUserId,
                          canMuteOthers: canMuteOthers,
                          onMute: _muteParticipant,
                        ),
                      },
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: call.isLive && _controlsVisible
                          ? CallControlsBar(
                              isMicrophoneEnabled: call.isMicrophoneEnabled,
                              isCameraEnabled: call.isCameraEnabled,
                              isSpeakerphoneEnabled: call.isSpeakerphoneEnabled,
                              canSwitchSpeaker: call.canSwitchSpeaker,
                              layout: call.layout,
                              onToggleMicrophone: _toggleMicrophone,
                              onToggleCamera: _toggleCamera,
                              onToggleSpeakerphone: () {
                                _restartHideTimer();
                                ref
                                    .read(callProvider.notifier)
                                    .toggleSpeakerphone();
                              },
                              onToggleLayout: () {
                                _restartHideTimer();
                                ref.read(callProvider.notifier).toggleLayout();
                              },
                              onHangUp: _hangUp,
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _subtitle(CallState call, AppLocalizations l10n) {
    if (call.isReconnecting) return l10n.callReconnecting;
    if (call.stage == CallStage.connecting) return l10n.callConnecting;
    if (!call.isLive) {
      final slug = call.token?.slug;
      return slug == null ? null : l10n.callRoomName(slug);
    }

    final people = l10n.callParticipantsCount(call.participants.length);
    final since = call.connectedAt;
    if (since == null) return people;
    final elapsed = formatVoiceDuration(
      DateTime.now().difference(since).inSeconds,
    );
    return '$people · $elapsed';
  }

  /// The chat roster, so tiles can show real names and avatars — LiveKit
  /// itself only carries an identity string and whatever display name the
  /// token was minted with.
  Map<int, ChatProfileEntity> _profilesOf(ChatEntity? chat) {
    final profiles = <int, ChatProfileEntity>{};
    if (chat == null) return profiles;

    for (final profile in chat.membersPreview) {
      profiles[profile.userId] = profile;
    }
    for (final member in chat.members ?? const <ChatMemberEntity>[]) {
      final profile = member.profile;
      if (profile != null) profiles[member.userId] = profile;
    }
    return profiles;
  }

  void _revealControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _restartHideTimer();
  }

  /// The bar gets out of the way of the video, but only once the call is
  /// actually up — hiding the join button would leave a blank screen.
  void _restartHideTimer() {
    _hideControls?.cancel();
    _hideControls = Timer(_controlsLinger, () {
      if (!mounted) return;
      if (!ref.read(callProvider).isLive) return;
      setState(() => _controlsVisible = false);
    });
  }

  Future<void> _join() async {
    _revealControls();
    // The explanation is a pre-step, and backing out of it cancels the join.
    // Refusing the *platform* prompt does not: the controller joins muted and
    // the banner says why, because listening in is still a call worth having.
    if (!await _explainThenAllow(MediaDeviceKind.microphone)) return;
    if (!mounted) return;

    await ref
        .read(callProvider.notifier)
        .join(
          widget.chatId,
          chatName: ref
              .read(chatDetailProvider(widget.chatId))
              .value
              ?.chat
              ?.name,
        );
  }

  Future<void> _toggleMicrophone() async {
    _revealControls();
    final call = ref.read(callProvider);
    if (!call.isMicrophoneEnabled &&
        !await _explainThenAllow(MediaDeviceKind.microphone)) {
      return;
    }
    if (!mounted) return;
    await ref.read(callProvider.notifier).toggleMicrophone();
  }

  Future<void> _toggleCamera() async {
    _revealControls();
    final call = ref.read(callProvider);
    if (!call.isCameraEnabled &&
        !await _explainThenAllow(MediaDeviceKind.camera)) {
      return;
    }
    if (!mounted) return;
    await ref.read(callProvider.notifier).toggleCamera();
  }

  /// Shows why the device is needed, unless it has already been granted, and
  /// reports whether the user wants to go on to the platform prompt.
  Future<bool> _explainThenAllow(MediaDeviceKind device) async {
    final status = await ref.read(mediaPermissionsProvider).check(device);
    if (status.isGranted) return true;
    if (!mounted) return false;
    return showCallPermissionRationale(context, device);
  }

  Future<void> _hangUp() async {
    await ref.read(callProvider.notifier).leave();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _muteParticipant(int userId, bool muted) async {
    final failure = await ref
        .read(callProvider.notifier)
        .muteParticipant(userId, muted: muted);
    if (!mounted || failure == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(friendlyFailureMessage(failure))));
  }
}

/// The grid, plus the floating self preview when the local camera is on and
/// there is somebody else to watch.
class _CallStage extends StatelessWidget {
  const _CallStage({
    required this.call,
    required this.profiles,
    required this.myUserId,
    required this.canMuteOthers,
    required this.onMute,
  });

  final CallState call;
  final Map<int, ChatProfileEntity> profiles;
  final int? myUserId;
  final bool canMuteOthers;
  final void Function(int userId, bool muted) onMute;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (call.participants.isEmpty) {
      return Center(
        child: Text(
          l10n.callWaitingForOthers,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final floats = shouldFloatSelfPreview(
      isCameraEnabled: call.isCameraEnabled,
      participantCount: call.participants.length,
    );
    final tiles = callGridParticipants(
      call.participants,
      selfPreviewFloats: floats,
    );

    final local = call.participants
        .where((participant) => participant.isLocal)
        .firstOrNull;

    return Consumer(
      builder: (context, ref, _) => Stack(
        children: [
          Positioned.fill(
            child: CallParticipantGrid(
              participants: tiles,
              layout: call.layout,
              profiles: profiles,
              pinnedIdentity: call.pinnedIdentity,
              onTapParticipant: (participant) => ref
                  .read(callProvider.notifier)
                  .pinParticipant(participant.identity),
              muteBuilder: (participant) {
                final userId = participant.userId;
                final allowed =
                    canMuteOthers &&
                    !participant.isLocal &&
                    userId != null &&
                    userId != myUserId;
                if (!allowed) return null;
                return (muted) => onMute(userId, muted);
              },
            ),
          ),
          if (floats)
            Positioned.fill(
              child: CallSelfPreview(
                track: local?.videoTrack,
                margin: const EdgeInsets.all(14),
                onTap: () => ref.read(callProvider.notifier).toggleLayout(),
              ),
            ),
          if (call.isReconnecting)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: _ReconnectingChip(label: l10n.callReconnecting),
              ),
            )
          else if (call.participants.length <= 1)
            // Alone in the room, the grid is a single tile of yourself, which
            // says nothing about whether the call is working. This does.
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: _ReconnectingChip(
                  label: l10n.callWaitingForOthers,
                  showsSpinner: false,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReconnectingChip extends StatelessWidget {
  const _ReconnectingChip({required this.label, this.showsSpinner = true});

  final String label;

  /// A spinner means "something is being retried"; the waiting-for-others
  /// notice is not a retry, only a statement of fact.
  final bool showsSpinner;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showsSpinner) ...[
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// The title row, which fades away with the controls so video can have the
/// whole screen.
class _Header extends StatelessWidget {
  const _Header({
    required this.visible,
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final bool visible;
  final String title;
  final String? subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                // Minimise, not hang up: the call keeps running and the mini
                // player picks it up.
                tooltip: AppLocalizations.of(context).callMinimize,
                icon: const Icon(Icons.expand_more),
                onPressed: onBack,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinPrompt extends StatelessWidget {
  const _JoinPrompt({required this.isBusy, required this.onJoin});

  final bool isBusy;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_outlined,
                size: 44,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (isBusy) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                l10n.callConnecting,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ] else ...[
              Text(
                l10n.callJoinExplanation,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onJoin,
                icon: const Icon(Icons.call),
                label: Text(l10n.callJoin),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.callNoIncomingNotice,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CallEnded extends StatelessWidget {
  const _CallEnded({required this.onRejoin});

  final VoidCallback onRejoin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.call_end, size: 56, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(l10n.callEnded, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onRejoin,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.callRejoin),
          ),
        ],
      ),
    );
  }
}

class _CallBanner extends StatelessWidget {
  const _CallBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
              ),
            ),
            IconButton(
              tooltip: l10n.callDismiss,
              onPressed: onDismiss,
              icon: Icon(Icons.close, size: 18, color: scheme.onErrorContainer),
            ),
          ],
        ),
      ),
    );
  }
}
