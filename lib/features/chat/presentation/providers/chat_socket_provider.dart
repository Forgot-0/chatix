import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/feature_flags/feature_flag_providers.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/core/websocket/socket_protocol_log.dart';
import 'package:chatix/core/websocket/socket_token_source.dart';
import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:chatix/features/chat/data/datasources/chat_socket_cursor_store.dart';

/// The flag that turns protocol recording on.
///
/// Off by default and meant to be flipped per-account from the outside, so a
/// session can be captured from someone who is not running a debug build.
const String kWsProtocolLogFlag = 'enable_ws_protocol_log';

/// Resolves the refresher only when a token is actually wanted.
///
/// The refresher sits on the HTTP stack, and the HTTP stack needs a cookie
/// jar that only `main()` can build. Reading it lazily keeps the socket
/// constructible in a widget test that never connects.
class _LazySocketTokenSource implements SocketTokenSource {
  const _LazySocketTokenSource(this._ref);

  final Ref _ref;

  @override
  Future<String?> token({bool forceRefresh = false}) =>
      _ref.read(accessTokenRefresherProvider).token(forceRefresh: forceRefresh);
}

final chatSocketServiceProvider = Provider<ChatSocketService>((ref) {
  final service = ChatSocketService(
    secureStorage: ref.watch(secureStorageServiceProvider),
    cursorStore: ChatCacheSocketCursorStore(
      ref.watch(chatLocalDataSourceProvider),
    ),
    tokenSource: _LazySocketTokenSource(ref),
    protocolLog: ref.watch(socketProtocolLogProvider),
  );

  ref.onDispose(service.dispose);

  return service;
});

/// Keeps the socket in step with the session and with the app's own
/// lifecycle: connected while somebody is signed in and looking, quiet while
/// they are not.
final chatSocketLifecycleProvider = Provider<void>((ref) {
  final service = ref.watch(chatSocketServiceProvider);
  final auth = ref.watch(authProvider);

  final isAuthenticated = auth.hasValue && auth.value != null;

  if (isAuthenticated) {
    service.connect();
  } else {
    service.disconnect();
  }

  void onTokenInvalid() {
    if (!service.isTokenInvalid.value) return;
    Logger.warning('ChatSocket: token rejected (1008) — re-validating session');
    ref.invalidate(authProvider);
  }

  service.isTokenInvalid.addListener(onTokenInvalid);
  ref.onDispose(() => service.isTokenInvalid.removeListener(onTokenInvalid));

  _watchAppLifecycle(ref, service);
  _watchProtocolLogFlag(ref);
}, dependencies: [authProvider, chatSocketServiceProvider]);

/// Drops the chat subscriptions while the app is in the background and puts
/// them back — with their cursors — when it returns.
///
/// `inactive` is deliberately not one of the states that pauses: it is what
/// the platform reports for a notification shade being pulled down or an app
/// switcher being opened, and unsubscribing for two seconds because somebody
/// glanced at a notification would cost a `resume` round trip for nothing.
void _watchAppLifecycle(Ref ref, ChatSocketService service) {
  final listener = AppLifecycleListener(
    onStateChange: (state) {
      switch (state) {
        case AppLifecycleState.resumed:
          service.resumeFromBackground();

        case AppLifecycleState.hidden:
        case AppLifecycleState.paused:
        case AppLifecycleState.detached:
          service.pauseForBackground();

        case AppLifecycleState.inactive:
          break;
      }
    },
  );

  ref.onDispose(listener.dispose);
}

/// Turns protocol recording on and off as the flag changes.
void _watchProtocolLogFlag(Ref ref) {
  final flags = ref.watch(featureFlagServiceProvider);
  final log = ref.watch(socketProtocolLogProvider);

  void sync() {
    final enabled = flags.getBool(kWsProtocolLogFlag, defaultValue: false);
    if (enabled == log.enabled) return;

    log.enabled = enabled;
    if (!enabled) log.clear();
    Logger.info('ChatSocket: protocol log ${enabled ? "on" : "off"}');
  }

  sync();
  flags.addListener(sync);
  ref.onDispose(() => flags.removeListener(sync));
}

final chatSocketStatusProvider = StreamProvider<ChatSocketStatus>((ref) {
  final service = ref.watch(chatSocketServiceProvider);
  return service.statusStream;
}, dependencies: [chatSocketServiceProvider]);

/// The connection state, answered even before the stream has said anything.
///
/// [chatSocketStatusProvider] only starts producing on the next change, which
/// on a screen opened mid-session is never — so the service's own current
/// state is the answer until then. Having the two folded together here means
/// a widget watches one thing, and a test overrides one thing.
final chatSocketStateProvider = Provider<ChatSocketStatus>((ref) {
  return ref.watch(chatSocketStatusProvider).value ??
      ref.read(chatSocketServiceProvider).status;
}, dependencies: [chatSocketStatusProvider, chatSocketServiceProvider]);

final chatSocketEventsProvider = StreamProvider<WSEvent>((ref) {
  return ref.watch(chatSocketServiceProvider).events;
}, dependencies: [chatSocketServiceProvider]);

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
      state = {...state, ...event.tokens};
    });

    ref.onDispose(() => _subscription?.cancel());

    return const {};
  }

  bool isReady(String token) => state.contains(token);

  bool areReady(Iterable<String> tokens) => tokens.every(state.contains);

  void release(Iterable<String> tokens) {
    if (tokens.isEmpty) return;
    state = {...state}..removeAll(tokens);
  }
}
