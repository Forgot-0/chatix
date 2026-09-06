import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionExpiredSignal {
  SessionExpiredSignal();

  final StreamController<SessionExpiredReason> _controller =
      StreamController<SessionExpiredReason>.broadcast();

  Stream<SessionExpiredReason> get stream => _controller.stream;

  void notify(SessionExpiredReason reason) {
    if (_controller.isClosed) return;
    _controller.add(reason);
  }

  void dispose() {
    unawaited(_controller.close());
  }
}

enum SessionExpiredReason {
  refreshFailed,

  invalidToken,
}

final sessionExpiredSignalProvider = Provider<SessionExpiredSignal>((ref) {
  final signal = SessionExpiredSignal();
  ref.onDispose(signal.dispose);
  return signal;
});
