import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/chat/presentation/providers/call_provider.dart';

/// Which chat this device is in a call with, if any.
///
/// A flat, app-wide fact rather than something read out of the full call
/// state: anything that has to get out of the way of a call — voice playback,
/// most of all — cannot know which chat's call to ask about, only whether
/// there is one.
///
/// There is nothing from the server to fill this with beyond our own call:
/// `call_started`/`call_ended` are declared in `WSEventType` but never
/// published (api-docs §5.6), so a call somebody else starts is not visible
/// here until this device joins it.
final activeCallChatIdProvider = Provider<String?>(
  (ref) => ref.watch(
    callProvider.select((state) => state.isLive ? state.chatId : null),
  ),
);

/// Whether a call is going on at all.
final isCallActiveProvider = Provider<bool>(
  (ref) => ref.watch(activeCallChatIdProvider) != null,
);

/// Whether the full call screen is the thing the user is looking at.
///
/// Set by `CallScreen` itself as it comes and goes. The floating mini player
/// keys off it: a call is always *running*, but it only needs a window
/// following the user around when its own screen is not on top.
///
/// Kept per screen rather than as one flag. A screen may not touch a
/// provider while it is being disposed, so it says it has gone a moment
/// later — and by then a screen that replaced it in the same frame may
/// already have said it is here. A single flag would take the later word
/// and put the mini player over a call screen that is on top.
class CallScreenVisibility extends Notifier<bool> {
  final Set<Object> _screens = {};

  @override
  bool build() => false;

  /// [screen] is on top. Any object that stays the same for the screen's
  /// lifetime will do; `CallScreen` passes its own state.
  void show(Object screen) {
    if (!ref.mounted) return;
    _screens.add(screen);
    state = true;
  }

  /// [screen] has gone. Safe to call late, twice, or after the container
  /// itself has been torn down — the screen's dispose cannot know which.
  void hide(Object screen) {
    if (!ref.mounted) return;
    if (!_screens.remove(screen)) return;
    state = _screens.isNotEmpty;
  }
}

final callScreenVisibleProvider = NotifierProvider<CallScreenVisibility, bool>(
  CallScreenVisibility.new,
);

/// Whether the floating mini player should be on screen right now.
final callMiniPlayerVisibleProvider = Provider<bool>((ref) {
  final live = ref.watch(callProvider.select((state) => state.isLive));
  return live && !ref.watch(callScreenVisibleProvider);
});
