import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which chats this device is currently in a call with.
///
/// A flat, app-wide fact rather than something read out of `callProvider`,
/// which is a family and therefore only answerable per chat. Anything that
/// has to get out of the way of a call — voice playback, most of all —
/// cannot know which chat's call to ask about, only whether there is one.
///
/// Filled by `CallController` as it connects and leaves. There is nothing
/// from the server to fill it with: `call_started`/`call_ended` are declared
/// in `WSEventType` but never published (api-docs §5.6), so a call somebody
/// else starts is not visible here until this device joins it.
class ActiveCalls extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void joined(String chatId) {
    if (state.contains(chatId)) return;
    state = {...state, chatId};
  }

  void left(String chatId) {
    if (!state.contains(chatId)) return;
    state = {...state}..remove(chatId);
  }
}

final activeCallsProvider = NotifierProvider<ActiveCalls, Set<String>>(
  ActiveCalls.new,
);

/// Whether a call is going on at all.
final isCallActiveProvider = Provider<bool>(
  (ref) => ref.watch(activeCallsProvider).isNotEmpty,
);
