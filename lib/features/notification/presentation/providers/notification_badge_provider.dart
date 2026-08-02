import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/notification/presentation/providers/notification_providers.dart';

/// How often the badge re-reads `GET /notifications/unread_count/` while the
/// app is in the foreground.
///
/// ⚠️ This is a **poll**, and the interval is a deliberate compromise, not a
/// placeholder. The backend sends no notification events over the WebSocket
/// (api-docs §7 lists none), so there is nothing to subscribe to; the only
/// alternatives are polling or a stale badge. 60 s keeps the badge roughly
/// honest at ~60 requests/hour/user — short enough that a notification
/// arriving while the user is looking at the app shows up on its own, long
/// enough not to look like a hot loop to rate limiting.
const _pollInterval = Duration(minutes: 1);

/// Unread-notification count behind the app-bar bell (api-docs §8.3).
///
/// ### Why a `Notifier<int>` and not `FutureProvider`
///
/// The badge must survive its own failures. A dropped connection or a 500
/// should leave the last known number on screen rather than replacing the
/// bell with an error state or a spinner — so the state is a plain `int`
/// (defaulting to `0`), and refresh failures are swallowed on purpose. There
/// is nothing the user can do about a failed background count, and nothing
/// worth interrupting them for.
///
/// ### When it refreshes
///
/// 1. on build (login, or first time the bell is mounted),
/// 2. every [_pollInterval] while in the foreground,
/// 3. on resume from background — the interesting one, since a push most
///    likely arrived while the app was away,
/// 4. explicitly via [refresh], called by the notifications screen after
///    marking things read and by pull-to-refresh.
///
/// The timer is paused while backgrounded: a periodic timer that keeps firing
/// in the background wakes the radio for a number nobody can see.
class NotificationBadgeController extends Notifier<int> {
  Timer? _timer;
  AppLifecycleListener? _lifecycleListener;

  /// Guards against overlapping refreshes — a slow response plus a fast
  /// timer would otherwise stack requests, and a late one could overwrite a
  /// newer count with an older one.
  bool _inFlight = false;

  @override
  int build() {
    // Rebuilds on login/logout. Polling an endpoint that 401s for a signed
    // out user is pointless, and would trigger AuthInterceptor's refresh
    // dance once a minute.
    final isAuthenticated = ref.watch(authProvider).isAuthenticated;

    ref.onDispose(_stop);

    if (!isAuthenticated) {
      _stop();
      return 0;
    }

    _start();

    // Kick off the first read without blocking `build` (this is a synchronous
    // Notifier — the count is state, not an AsyncValue).
    scheduleMicrotask(refresh);

    // Preserve the previous count across rebuilds so the badge doesn't blink
    // back to 0 and then up again on an unrelated auth-state change.
    return stateOrNull ?? 0;
  }

  void _start() {
    _timer ??= Timer.periodic(_pollInterval, (_) => refresh());
    _lifecycleListener ??= AppLifecycleListener(
      onResume: () {
        // Anything could have arrived while we were away — read once
        // immediately, then let the periodic timer take over again.
        _timer ??= Timer.periodic(_pollInterval, (_) => refresh());
        refresh();
      },
      onPause: () {
        _timer?.cancel();
        _timer = null;
      },
    );
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
  }

  /// Re-reads the count. Never throws and never surfaces a [Failure] — see
  /// the class doc for why a failed badge refresh is a non-event.
  Future<void> refresh() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final result = await ref.read(getUnreadCountUseCaseProvider).execute();
      // `ref.mounted` — the provider may have been disposed (logout, screen
      // torn down) while the request was in flight; writing `state` then
      // throws.
      if (!ref.mounted) return;
      result.match((_) {}, (count) => state = count);
    } finally {
      _inFlight = false;
    }
  }

  /// Optimistic local adjustment, for when the count is already known to have
  /// changed and a round-trip would only make the badge lag behind the list.
  ///
  /// Used by the notifications screen: it knows exactly how many items it
  /// just marked read (`markAllAsRead` even returns the number). Clamped at
  /// zero so a double-tap can't produce a negative badge.
  void decrementBy(int amount) {
    if (amount <= 0) return;
    final next = state - amount;
    state = next < 0 ? 0 : next;
  }

  /// Local reset after "mark all as read" — cheaper and steadier than
  /// waiting for a confirming round-trip.
  void clear() => state = 0;
}

final notificationBadgeProvider =
    NotifierProvider<NotificationBadgeController, int>(
      NotificationBadgeController.new,
    );
