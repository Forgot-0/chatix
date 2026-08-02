import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';

/// Wiring for the chat WebSocket (api-docs §7): the singleton service, its
/// session lifecycle, and the narrow streams screens actually watch.
///
/// Kept beside `chat_providers.dart` (the REST wiring) but in its own file for
/// the reason called out there: a screen doing plain history/pagination must be
/// able to depend on the REST providers **without** instantiating a live
/// connection. Merging the two would give every chat screen a socket.

// ─────────────────────────────── The singleton ───────────────────────────────

/// The one [ChatSocketService] for the whole app.
///
/// `Provider`, not a family and not `autoDispose`: the server caps a user at
/// **2 concurrent connections** and evicts the oldest with 1012 (§7.2), so a
/// second instance would fight the first for the budget. `autoDispose` would be
/// actively harmful — the socket must outlive every screen, since unread badges
/// depend on events for chats that are *not* open.
///
/// Note this only *creates* the service; it does not connect.
/// [chatSocketLifecycleProvider] owns that, so that merely reading the service
/// to send an `unsubscribe` can never open a connection as a side effect.
final chatSocketServiceProvider = Provider<ChatSocketService>((ref) {
  final service = ChatSocketService(
    secureStorage: ref.watch(secureStorageServiceProvider),
  );

  // Only fires if the root container is torn down (tests, or a full app
  // restart), but without it those cases leak a socket and its timers.
  ref.onDispose(service.dispose);

  return service;
});

/// Ties the socket's lifetime to the session: connect on sign-in, disconnect on
/// sign-out.
///
/// Watch this **once**, high in the tree (the shell/router), not per screen.
///
/// Why a provider instead of `connect()` inside the login flow: sign-in is not
/// the only way a session begins. A cold start with a stored token resolves
/// `authProvider` to a user without any login call ever running, and that must
/// bring the socket up too. Deriving from auth state covers login, cold start,
/// token-refresh recovery and logout with one rule.
final chatSocketLifecycleProvider = Provider<void>((ref) {
  final service = ref.watch(chatSocketServiceProvider);
  final auth = ref.watch(authProvider);

  // `hasValue && value != null` — not `!auth.hasError`. During a `login()` the
  // state is `AsyncLoading` with no user yet, and connecting then would race
  // the token write and close with 1008.
  final isAuthenticated = auth.hasValue && auth.value != null;

  if (isAuthenticated) {
    // Idempotent (§ ChatSocketService.connect), so the repeated calls caused by
    // unrelated `authProvider` rebuilds are harmless.
    service.connect();
  } else {
    // Clears subscriptions and cursors as well as closing the socket — they
    // belong to the user who just left.
    service.disconnect();
  }

  // A 1008 means the access token is dead. `AuthInterceptor` refreshes tokens
  // for REST calls, but a WebSocket handshake never passes through it, so
  // nothing else would notice — hence this bridge.
  //
  // Invalidating `authProvider` re-runs `AuthController.build()`, whose
  // `getCurrentUser` call *does* pass through the interceptor. That either
  // refreshes the token (→ still authenticated → this provider re-runs and
  // reconnects with the new one) or fails and resolves to `null` (→ signed
  // out). Both outcomes are correct and neither needs handling here.
  //
  // `invalidate` rather than a method on the controller because
  // `_refreshCurrentUser` is private and re-running `build()` also re-reads the
  // stored token, which is exactly what a 1008 calls into question.
  void onTokenInvalid() {
    if (!service.isTokenInvalid.value) return;
    Logger.warning('ChatSocket: token rejected (1008) — re-validating session');
    ref.invalidate(authProvider);
  }

  service.isTokenInvalid.addListener(onTokenInvalid);
  ref.onDispose(() => service.isTokenInvalid.removeListener(onTokenInvalid));
}, dependencies: [authProvider, chatSocketServiceProvider]);

// ─────────────────────────────── Derived streams ───────────────────────────────

/// Connection status for the UI indicator (§5 of the prompt).
///
/// Seeded with the service's current status so a screen opened while already
/// connected renders `ready` immediately — a broadcast stream replays nothing,
/// so without the seed there would be a frame of "no data" showing a spurious
/// spinner.
final chatSocketStatusProvider = StreamProvider<ChatSocketStatus>((ref) {
  final service = ref.watch(chatSocketServiceProvider);
  return service.statusStream;
}, dependencies: [chatSocketServiceProvider]);

/// The raw event stream, for controllers that filter it themselves.
final chatSocketEventsProvider = StreamProvider<WSEvent>((ref) {
  return ref.watch(chatSocketServiceProvider).events;
}, dependencies: [chatSocketServiceProvider]);

/// `attachment_success` tokens confirmed during this session (§7.4).
///
/// A cumulative [Set] rather than a stream of individual events, because the
/// composer's question is "is *this* token ready?", asked on every rebuild —
/// and a widget that rebuilds after the event fired would miss a one-shot
/// notification and leave its spinner up forever. A set answers the question at
/// any time, regardless of when the widget mounted.
///
/// ⚠️ Unicast to the uploading user, so tokens here are always our own (§7.4).
final confirmedAttachmentTokensProvider =
    NotifierProvider<ConfirmedAttachmentTokens, Set<String>>(
  ConfirmedAttachmentTokens.new,
  dependencies: [chatSocketServiceProvider],
);

class ConfirmedAttachmentTokens extends Notifier<Set<String>> {
  StreamSubscription<WSEvent>? _subscription;

  @override
  Set<String> build() {
    final service = ref.watch(chatSocketServiceProvider);

    _subscription = service.events.listen((event) {
      if (event is! AttachmentSuccess) return;
      // New set, not `state.addAll(...)`: mutating in place leaves the
      // identity unchanged and Riverpod would not notify listeners.
      state = {...state, ...event.tokens};
    });

    ref.onDispose(() => _subscription?.cancel());

    return const {};
  }

  /// True once the backend has finished processing [token] (§6.5 step 3).
  bool isReady(String token) => state.contains(token);

  /// True when every token in [tokens] is ready — the send button's gate for a
  /// message with attachments.
  ///
  /// An empty [tokens] is `true`: a text-only message waits for nothing.
  bool areReady(Iterable<String> tokens) => tokens.every(state.contains);

  /// Forgets [tokens] after a message is sent, so the set doesn't grow for the
  /// life of the session.
  void release(Iterable<String> tokens) {
    if (tokens.isEmpty) return;
    state = {...state}..removeAll(tokens);
  }
}
