import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/router/app_router.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/features/chat/presentation/providers/active_call_provider.dart';
import 'package:chatix/features/chat/presentation/providers/call_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_preview.dart'
    show formatVoiceDuration;
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Keeps the call reachable from everywhere in the app.
///
/// The call itself lives in [callProvider], which is app-wide and outlives
/// any screen — walking out of the call screen has never ended a call. This
/// only puts a window back on it: a floating pill that returns to the call
/// screen on tap, shown whenever a call is live and its own screen is not.
///
/// Mounted above the router in `MyApp`, so it survives every navigation.
class CallOverlay extends ConsumerWidget {
  const CallOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(callMiniPlayerVisibleProvider);

    return Stack(
      textDirection: Directionality.of(context),
      children: [
        child,
        if (visible) const Positioned.fill(child: CallMiniPlayer()),
      ],
    );
  }
}

/// The floating pill: who the call is with, how long it has been going, mute
/// and hang up, and a tap anywhere else to go back to it.
///
/// Draggable, and snaps to the nearest corner when released — it has to be
/// possible to move it off whatever it is covering, but a pill left at an
/// arbitrary offset drifts over the app bar or the composer.
class CallMiniPlayer extends ConsumerStatefulWidget {
  const CallMiniPlayer({super.key});

  @override
  ConsumerState<CallMiniPlayer> createState() => _CallMiniPlayerState();
}

class _CallMiniPlayerState extends ConsumerState<CallMiniPlayer> {
  static const double _width = 214;
  static const double _height = 60;

  Alignment _corner = Alignment.bottomRight;
  Offset? _dragTopLeft;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Only the seconds readout needs this, so it runs at exactly the rate
    // that readout changes.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(callProvider);
    if (!state.isLive) return const SizedBox.shrink();

    final padding = MediaQuery.paddingOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Rect.fromLTRB(
          12,
          padding.top + 12,
          constraints.maxWidth - 12 - _width,
          constraints.maxHeight - padding.bottom - 12 - _height,
        );

        final resting = _restingPosition(area);
        final position = _dragTopLeft ?? resting;

        return Stack(
          children: [
            AnimatedPositioned(
              duration: _dragTopLeft == null
                  ? const Duration(milliseconds: 220)
                  : Duration.zero,
              curve: Curves.easeOutCubic,
              left: position.dx,
              top: position.dy,
              width: _width,
              height: _height,
              child: GestureDetector(
                onPanStart: (_) => setState(() => _dragTopLeft = resting),
                onPanUpdate: (details) => setState(() {
                  _dragTopLeft = _clamp(
                    (_dragTopLeft ?? resting) + details.delta,
                    area,
                  );
                }),
                onPanEnd: (_) => setState(() {
                  _corner = _nearestCorner(_dragTopLeft ?? resting, area);
                  _dragTopLeft = null;
                }),
                child: _Pill(
                  state: state,
                  onReturn: _returnToCall,
                  onToggleMicrophone: () =>
                      ref.read(callProvider.notifier).toggleMicrophone(),
                  onHangUp: () => ref.read(callProvider.notifier).leave(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _returnToCall() {
    final chatId = ref.read(callProvider).chatId;
    if (chatId == null) return;
    // Through the router rather than a Navigator: this widget sits above the
    // router's own navigator and has no route of its own to push onto.
    ref.read(routerProvider).push(ChatCallRoute.locationOf(chatId));
  }

  Offset _restingPosition(Rect area) {
    final left = _corner.x < 0 ? area.left : math.max(area.left, area.right);
    final top = _corner.y < 0 ? area.top : math.max(area.top, area.bottom);
    return Offset(left, top);
  }

  static Offset _clamp(Offset value, Rect area) => Offset(
    value.dx.clamp(area.left, math.max(area.left, area.right)),
    value.dy.clamp(area.top, math.max(area.top, area.bottom)),
  );

  static Alignment _nearestCorner(Offset position, Rect area) {
    final midX = (area.left + area.right) / 2;
    final midY = (area.top + area.bottom) / 2;
    return Alignment(position.dx < midX ? -1 : 1, position.dy < midY ? -1 : 1);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.state,
    required this.onReturn,
    required this.onToggleMicrophone,
    required this.onHangUp,
  });

  final CallState state;
  final VoidCallback onReturn;
  final VoidCallback onToggleMicrophone;
  final VoidCallback onHangUp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final title = state.chatName?.trim().isNotEmpty == true
        ? state.chatName!.trim()
        : l10n.callTitle;

    final subtitle = state.isReconnecting
        ? l10n.callReconnecting
        : _elapsedLabel(state.connectedAt, l10n);

    return Semantics(
      label: l10n.callMiniPlayerLabel(title),
      button: true,
      child: Material(
        color: scheme.primaryContainer,
        elevation: 6,
        borderRadius: BorderRadius.circular(30),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onReturn,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  state.isReconnecting ? Icons.sync_problem : Icons.call,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: state.isMicrophoneEnabled
                      ? l10n.callMicrophoneMute
                      : l10n.callMicrophoneUnmute,
                  onPressed: onToggleMicrophone,
                  icon: Icon(
                    state.isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
                    size: 18,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.callLeave,
                  onPressed: onHangUp,
                  icon: Icon(Icons.call_end, size: 18, color: scheme.error),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _elapsedLabel(DateTime? since, AppLocalizations l10n) {
    if (since == null) return l10n.callConnecting;
    final seconds = DateTime.now().difference(since).inSeconds;
    return formatVoiceDuration(seconds);
  }
}
