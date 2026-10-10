import 'dart:collection';

/// Keeps a client under a server's "N requests per window" limit.
///
/// Counts the requests it is told about in the last [window]; asked how
/// long to wait, it answers zero while there is room and otherwise the time
/// until the oldest one ages out. Writers that can wait (a draft) ask first;
/// writers that cannot (a tap on "pin") just report what they sent, so the
/// ones that can wait leave them room.
class SlidingWindowRateLimiter {
  SlidingWindowRateLimiter({required this.capacity, required this.window})
    : assert(capacity > 0);

  final int capacity;
  final Duration window;

  final Queue<DateTime> _sent = Queue<DateTime>();

  /// Set by a `429`: the server's count and ours disagree, and the server's
  /// is the one that counts.
  DateTime? _blockedUntil;

  /// How long to wait before one more request, keeping [reserve] slots of
  /// the window free for writers that will not wait.
  Duration delayFor(DateTime now, {int reserve = 0}) {
    _forgetBefore(now);

    final blocked = _blockedUntil;
    if (blocked != null && blocked.isAfter(now)) return blocked.difference(now);

    final allowed = capacity - reserve;
    if (allowed <= 0) return window;
    if (_sent.length < allowed) return Duration.zero;

    // The request that has to age out before there is room again.
    final gate = _sent.elementAt(_sent.length - allowed);
    final wait = gate.add(window).difference(now);
    return wait.isNegative ? Duration.zero : wait;
  }

  void record(DateTime now) {
    _forgetBefore(now);
    _sent.addLast(now);
  }

  /// The server said no: nothing more until a whole window has passed.
  void blockFor(DateTime now, [Duration? duration]) {
    _blockedUntil = now.add(duration ?? window);
  }

  /// Requests counted in the window ending at [now].
  int sentIn(DateTime now) {
    _forgetBefore(now);
    return _sent.length;
  }

  void _forgetBefore(DateTime now) {
    final horizon = now.subtract(window);
    while (_sent.isNotEmpty && !_sent.first.isAfter(horizon)) {
      _sent.removeFirst();
    }
  }
}
