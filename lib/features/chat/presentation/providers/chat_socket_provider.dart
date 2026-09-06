import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';

final chatSocketServiceProvider = Provider<ChatSocketService>((ref) {
  final service = ChatSocketService(
    secureStorage: ref.watch(secureStorageServiceProvider),
  );

  ref.onDispose(service.dispose);

  return service;
});

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
}, dependencies: [authProvider, chatSocketServiceProvider]);

final chatSocketStatusProvider = StreamProvider<ChatSocketStatus>((ref) {
  final service = ref.watch(chatSocketServiceProvider);
  return service.statusStream;
}, dependencies: [chatSocketServiceProvider]);

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
