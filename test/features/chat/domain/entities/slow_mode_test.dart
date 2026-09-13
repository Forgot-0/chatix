import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/slow_mode.dart';

/// `slow_mode_seconds` throttles everyone without `slowmode:bypass`, and
/// sending too soon is `429 SLOW_MODE_LIMIT` with `detail.retry_after`
/// (api-docs §5.2, §2.6). The client runs a clock so the button can count
/// down; the server's answer is the one that settles a disagreement.
void main() {
  final now = DateTime.utc(2026, 3, 1, 12);

  const throttled = SlowMode(interval: Duration(seconds: 30));

  group('off', () {
    test('never holds anything back', () {
      expect(SlowMode.off.isActive, isFalse);
      expect(SlowMode.off.canSendAt(now), isTrue);
      expect(SlowMode.off.remainingAt(now), Duration.zero);
    });

    test('a send starts no clock', () {
      expect(SlowMode.off.afterSendAt(now), SlowMode.off);
    });
  });

  group('after a message goes out', () {
    test('the wait is the whole interval', () {
      final after = throttled.afterSendAt(now);

      expect(after.remainingAt(now), const Duration(seconds: 30));
      expect(after.canSendAt(now), isFalse);
    });

    test('it runs down with the clock', () {
      final after = throttled.afterSendAt(now);

      expect(
        after.remainingAt(now.add(const Duration(seconds: 10))),
        const Duration(seconds: 20),
      );
      expect(after.canSendAt(now.add(const Duration(seconds: 30))), isTrue);
    });

    test('and does not go negative once it is over', () {
      final after = throttled.afterSendAt(now);

      expect(
        after.remainingAt(now.add(const Duration(minutes: 5))),
        Duration.zero,
      );
    });
  });

  group('retry_after is the authority', () {
    test('it replaces a local wait that was nearly over', () {
      final optimistic = throttled.afterSendAt(now);
      final corrected = optimistic.afterRetryAfter(45, now);

      expect(corrected.remainingAt(now), const Duration(seconds: 45));
    });

    test('it can shorten one too', () {
      final corrected = throttled.afterSendAt(now).afterRetryAfter(5, now);

      expect(corrected.remainingAt(now), const Duration(seconds: 5));
    });

    test('a 429 in a chat we thought was free still holds the button', () {
      // Our copy of the chat is stale rather than the server being wrong.
      final corrected = SlowMode.off.afterRetryAfter(20, now);

      expect(corrected.isActive, isTrue);
      expect(corrected.remainingAt(now), const Duration(seconds: 20));
    });

    test('a nonsense retry_after is treated as no wait at all', () {
      expect(
        throttled.afterRetryAfter(-3, now).remainingAt(now),
        Duration.zero,
      );
    });
  });

  group('re-reading the chat', () {
    test('a longer interval does not touch a wait already running', () {
      final waiting = throttled.afterSendAt(now);
      final next = waiting.withInterval(const Duration(seconds: 60));

      expect(next.interval, const Duration(seconds: 60));
      expect(next.remainingAt(now), const Duration(seconds: 30));
    });

    test('slow mode being switched off releases the button at once', () {
      final waiting = throttled.afterSendAt(now);

      expect(waiting.withInterval(Duration.zero), SlowMode.off);
      expect(waiting.withInterval(Duration.zero).canSendAt(now), isTrue);
    });

    test('released keeps the interval but drops the wait', () {
      final released = throttled.afterSendAt(now).released();

      expect(released.interval, const Duration(seconds: 30));
      expect(released.canSendAt(now), isTrue);
    });
  });
}
