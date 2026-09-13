import 'package:equatable/equatable.dart';

/// How long this reader has to wait between messages in this chat.
///
/// `chat.slow_mode_seconds` throttles everyone without `slowmode:bypass`
/// (api-docs §5.2, §8.1); sending too soon comes back `429 SLOW_MODE_LIMIT`
/// with `detail.retry_after`. The client runs its own clock so the button can
/// count down instead of failing, but the server's `retry_after` is the
/// authority whenever the two disagree — its clock is the one that decides.
class SlowMode extends Equatable {
  const SlowMode({required this.interval, this.sendAllowedAt});

  /// No throttle: either the chat has none or this reader may bypass it.
  static const SlowMode off = SlowMode(interval: Duration.zero);

  /// From `chat.slow_mode_seconds`, zero when it does not apply.
  final Duration interval;

  /// The earliest moment the next message may go out, or null when nothing
  /// is holding it back.
  final DateTime? sendAllowedAt;

  bool get isActive => interval > Duration.zero;

  /// What is left on the clock, floored at zero.
  Duration remainingAt(DateTime now) {
    final until = sendAllowedAt;
    if (until == null) return Duration.zero;

    final left = until.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool isWaitingAt(DateTime now) => remainingAt(now) > Duration.zero;

  /// The wait as whole seconds, rounded up.
  ///
  /// Truncating would show "29" the instant a thirty-second wait starts, and
  /// then sit on "0" for a whole second before letting go — a countdown that
  /// is wrong at both ends.
  int secondsLeftAt(DateTime now) =>
      (remainingAt(now).inMilliseconds / 1000).ceil();

  bool canSendAt(DateTime now) => !isWaitingAt(now);

  /// The interval, re-read from the chat, keeping any wait already running.
  ///
  /// A chat whose slow mode is switched off releases the composer at once;
  /// one that turns it on does not retroactively hold a message back.
  SlowMode withInterval(Duration next) {
    if (next <= Duration.zero) return off;
    return SlowMode(interval: next, sendAllowedAt: sendAllowedAt);
  }

  /// Starts the local clock after a message went out.
  SlowMode afterSendAt(DateTime now) {
    if (!isActive) return this;
    return SlowMode(interval: interval, sendAllowedAt: now.add(interval));
  }

  /// Takes the server's word for it.
  ///
  /// `retry_after` arrives in seconds on the 429 and replaces whatever the
  /// local clock believed — including extending a wait we thought was over,
  /// which is exactly the case the local clock gets wrong.
  SlowMode afterRetryAfter(int seconds, DateTime now) {
    final wait = Duration(seconds: seconds < 0 ? 0 : seconds);

    return SlowMode(
      // A 429 in a chat we thought had no throttle means our copy of the chat
      // is stale; the wait is real either way, so keep it.
      interval: isActive ? interval : wait,
      sendAllowedAt: now.add(wait),
    );
  }

  /// Clears the wait — what leaving the chat, or sending nothing after all,
  /// should not do, but a settings change that turns slow mode off should.
  SlowMode released() => SlowMode(interval: interval);

  @override
  List<Object?> get props => [interval, sendAllowedAt];
}
