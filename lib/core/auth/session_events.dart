import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A one-way "the session is gone" bus between the HTTP layer and the auth
/// layer.
///
/// ### The problem it solves
///
/// `AuthInterceptor` is the only place that *knows* a session has ended: it
/// is the thing that tried the refresh (api-docs §3.4) and got back
/// `NOT_FOUND_OR_INACTIVE_SESSION` / `INVALID_TOKEN` / `EXPIRED_TOKEN`, or
/// found a `403 INVALID_TOKEN` it must not retry. Up to now it reacted by
/// deleting the stored access token and letting the original error propagate
/// — which left the app in a state where storage says "signed out" but
/// `AuthController` still holds a `UserEntity`, the shell still shows four
/// tabs, and the user keeps clicking on screens that will 401 forever. The
/// only way out was for each screen to notice its own 401 and navigate, which
/// is (a) per-screen work that will be forgotten somewhere and (b) wrong from
/// any code path with no `BuildContext` (a background poll, a WebSocket
/// reconnect, a use case triggered from a notification tap).
///
/// ### Why a bus and not a direct call
///
/// The interceptor cannot simply call `AuthController` because the dependency
/// graph runs the other way and would close a cycle:
///
/// ```
///   dioProvider → AuthInterceptor          (needs to notify auth)
///   authProvider → use cases → repository → apiClient → dioProvider
/// ```
///
/// Riverpod would throw on the circular dependency, and even if it didn't,
/// building the auth stack in order to build the HTTP client that the auth
/// stack is built on is not something to be clever about. So the signal is a
/// leaf: it depends on nothing, the interceptor *writes* to it, and
/// `AuthController` *reads* it. Both sides can be tested in isolation by
/// pushing an event through it.
///
/// ### Broadcast, not replay
///
/// Deliberately no "last event" buffer. A session expiry is only actionable
/// while the app is running; a late subscriber that receives a signal from
/// ten minutes ago would sign out a user who has since logged back in.
class SessionExpiredSignal {
  SessionExpiredSignal();

  final StreamController<SessionExpiredReason> _controller =
      StreamController<SessionExpiredReason>.broadcast();

  /// Fires whenever the HTTP layer establishes that the session is
  /// unrecoverable. May fire more than once (several requests can fail
  /// together before anyone reacts) — listeners must be idempotent.
  Stream<SessionExpiredReason> get stream => _controller.stream;

  /// Called by [AuthInterceptor] after it has cleared the stored token.
  void notify(SessionExpiredReason reason) {
    if (_controller.isClosed) return;
    _controller.add(reason);
  }

  void dispose() {
    unawaited(_controller.close());
  }
}

/// Why the session ended — carried so the sign-in screen (and the logs) can
/// tell "your session expired, sign in again" apart from a deliberate logout.
enum SessionExpiredReason {
  /// The refresh cookie was rejected or the session row is gone/inactive
  /// (`NOT_FOUND_OR_INACTIVE_SESSION`, `INVALID_TOKEN`, `EXPIRED_TOKEN` on
  /// `POST /auth/refresh/`, api-docs §3.4).
  refreshFailed,

  /// A `403 INVALID_TOKEN` on an ordinary request: api-docs §2.3 says the
  /// token is structurally unusable, so a refresh is not attempted.
  invalidToken,
}

/// App-wide instance. Overridable in tests to drive the expiry path without
/// an HTTP layer.
final sessionExpiredSignalProvider = Provider<SessionExpiredSignal>((ref) {
  final signal = SessionExpiredSignal();
  ref.onDispose(signal.dispose);
  return signal;
});
