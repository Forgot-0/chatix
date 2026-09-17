import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/network/connectivity_providers.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/ui/feedback/connection_strip.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/chat/presentation/providers/active_call_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The way back from a jump into history to the live end of the chat.
class ChatBackToLatestBar extends StatelessWidget {
  const ChatBackToLatestBar({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.arrow_downward,
                size: 16,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).backToLatest,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Whether the app can reach the gateway, said as quietly as possible.
///
/// Three states and only three: connecting, waiting for a network, and
/// nothing at all. A connection that is coming back on its own is not news,
/// so it gets a hairline rather than a banner (see [ConnectionStrip]) — and
/// it does not even get that until it has been away long enough to be worth
/// mentioning, which is what [settleDelay] is for. Without it every
/// half-second blip of a reconnect flashes a strip across the top of the
/// chat, which reads as breakage rather than as recovery.
class ChatConnectionStrip extends ConsumerStatefulWidget {
  const ChatConnectionStrip({super.key});

  /// How long the socket has to be away before the strip appears.
  ///
  /// Long enough to cover a reconnect that succeeds immediately — the usual
  /// one, since the first backoff step is a second — and short enough that a
  /// real outage is described before the reader starts wondering.
  static const Duration settleDelay = Duration(milliseconds: 600);

  @override
  ConsumerState<ChatConnectionStrip> createState() =>
      _ChatConnectionStripState();
}

class _ChatConnectionStripState extends ConsumerState<ChatConnectionStrip> {
  Timer? _settle;
  bool _settled = false;

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  /// Starts, stops or leaves the countdown alone, to match the status.
  void _syncSettle({required bool connected}) {
    if (connected) {
      _settle?.cancel();
      _settle = null;
      if (_settled) {
        // Back to normal: the strip goes away on the next frame rather than
        // inside this build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _settled = false);
        });
      }
      return;
    }

    if (_settled || _settle != null) return;

    _settle = Timer(ChatConnectionStrip.settleDelay, () {
      _settle = null;
      if (mounted) setState(() => _settled = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final status = ref.watch(chatSocketStateProvider);

    final connected = status == ChatSocketStatus.ready;
    _syncSettle(connected: connected);

    // No link at all is the reader's own network, and the app cannot hurry
    // it. Anything else is the app's problem and reads as work in progress.
    final hasLink = ref.watch(hasNetworkLinkProvider);

    final waiting = !hasLink || status == ChatSocketStatus.disconnected;

    return ConnectionStrip(
      visible: !connected && _settled,
      tone: waiting
          ? ConnectionStripTone.waiting
          : ConnectionStripTone.working,
      label: waiting ? l10n.connectionWaitingForNetwork : l10n.connectionBusy,
    );
  }
}

/// The gateway refused our subscribe (`ws.error` / NOT_CHAT_MEMBER, §6.4).
/// The history already loaded stays readable, but nothing new will arrive, and
/// silently freezing is worse than saying so.
class ChatRealtimeRejectedBanner extends StatelessWidget {
  const ChatRealtimeRejectedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sync_problem_outlined,
            size: 14,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              AppLocalizations.of(context).realtimeRejected,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "You are in a call in this chat" — with a way back into it.
///
/// Only ever about *this* device's call. A call somebody else started is not
/// knowable: `call_started`/`call_joined` are declared in `WSEventType` but
/// never published, there is no REST listing of a room's occupants, and
/// LiveKit only reports participants to a client that has already joined
/// (api-docs §5.6). So this says what is true rather than guessing.
class ChatOngoingCallBanner extends ConsumerWidget {
  const ChatOngoingCallBanner({super.key, required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeChatId = ref.watch(activeCallChatIdProvider);
    if (activeChatId != chatId) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Material(
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: () => context.push(ChatCallRoute.locationOf(chatId)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.call,
                size: 16,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.callOngoingInChat,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              Text(
                l10n.callReturn,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
