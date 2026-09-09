import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';

/// Who is currently typing in a chat.
///
/// **This is empty today, by design.** The gateway lists `typing_start` and
/// `typing_stop` in its event enum but publishes neither (api-docs §6.4), so
/// they reach the client — if they ever do — as [WsUnimplementedEvent]. The
/// wiring exists so the indicator lights up the day the backend starts
/// sending them; until then `TypingIndicator` is simply never built. Nothing
/// here fabricates activity.
class TypingUsersController extends Notifier<Set<int>> {
  TypingUsersController(this._chatId);

  final String _chatId;

  /// How long a `typing_start` stands on its own. Every implementation of
  /// this protocol repeats the start frame while the person keeps typing, so
  /// a missed `typing_stop` clears itself instead of pinning the indicator on
  /// forever.
  static const Duration expiry = Duration(seconds: 6);

  final Map<int, Timer> _timers = <int, Timer>{};

  @override
  Set<int> build() {
    final subscription = ref
        .watch(chatSocketServiceProvider)
        .events
        .listen(_onEvent);

    ref.onDispose(subscription.cancel);
    ref.onDispose(() {
      for (final timer in _timers.values) {
        timer.cancel();
      }
      _timers.clear();
    });

    return const <int>{};
  }

  void _onEvent(WSEvent event) {
    if (event is! WsUnimplementedEvent) return;
    if (event.chatId != _chatId) return;

    // The payload shape is unverified — there is no published frame to check
    // it against — so anything that is not an int user_id is dropped rather
    // than guessed at.
    final userId = event.payload['user_id'];
    if (userId is! int) return;

    switch (event.type) {
      case 'typing_start':
        _start(userId);
      case 'typing_stop':
        _stop(userId);
    }
  }

  void _start(int userId) {
    _timers.remove(userId)?.cancel();
    _timers[userId] = Timer(expiry, () => _stop(userId));
    if (state.contains(userId)) return;
    state = {...state, userId};
  }

  void _stop(int userId) {
    _timers.remove(userId)?.cancel();
    if (!state.contains(userId)) return;
    state = state.where((id) => id != userId).toSet();
  }
}

final typingUsersProvider =
    NotifierProvider.family<TypingUsersController, Set<int>, String>(
      TypingUsersController.new,
      isAutoDispose: true,
      dependencies: [chatSocketServiceProvider],
    );
